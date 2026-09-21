#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/state/WorkspacePlacementController.hpp>
#include <hyprland/src/animation/WorkspaceAnimationController.hpp>
#include <stdexcept>
#include <hyprland/src/state/MonitorState.hpp>
extern "C" {
#include <lua.h>
}

static CFunctionHook* workspaceHook = nullptr;
static bool enabled = true;
using ChangeWorkspace = Config::Actions::ActionResult (*)(PHLWORKSPACE);

// Intercept explicit workspace requests, not monitor or window focus. This also
// covers IPC, relative selectors and bindings installed before the Lua plugin.
static Config::Actions::ActionResult requestWorkspace(PHLWORKSPACE workspace) {
    const auto original = reinterpret_cast<ChangeWorkspace>(workspaceHook->m_original);
    if (!enabled) return original(workspace);
    const auto here = Desktop::focusState()->monitor();
    const auto there = workspace ? workspace->m_monitor.lock() : nullptr;
    if (!workspace || workspace->m_isSpecialWorkspace || !here || !there || here == there)
        return original(workspace);
    if (there->m_activeWorkspace != workspace || !here->m_activeWorkspace) {
        State::workspacePlacementController()->moveWorkspaceToMonitor(workspace, here, true);
        return original(workspace);
    }

    const auto outgoing = here->m_activeWorkspace;
    // Retain in-flight offsets, so reversing a swap doesn't restart at the edge.
    const auto incomingOffset = workspace->m_renderOffset->value();
    const auto outgoingOffset = outgoing->m_renderOffset->value();
    const auto displacement = there->m_position - here->m_position;
    State::workspacePlacementController()->swapActiveWorkspaces(here, there);
    // Both workspaces enter their destination monitor. Initialize the configured
    // fade as well as its damage callbacks before restoring spatial slide vectors.
    Animation::Workspace::startAnimation(workspace, Animation::Workspace::ANIMATION_TYPE_IN);
    Animation::Workspace::startAnimation(outgoing, Animation::Workspace::ANIMATION_TYPE_IN);
    // Native workspace rendering includes tiled, floating and fullscreen windows.
    // The vector comes from logical monitor positions (including negative and
    // vertical offsets), rather than workspace number or an assumed left/right.
    workspace->m_renderOffset->setValueAndWarp(incomingOffset + displacement);
    outgoing->m_renderOffset->setValueAndWarp(outgoingOffset - displacement);
    *workspace->m_renderOffset = Vector2D{0, 0};
    *outgoing->m_renderOffset = Vector2D{0, 0};
    return {};
}

static int setEnabled(lua_State* L) {
    enabled = lua_toboolean(L, 1);
    return 0;
}

// Read-only diagnostics used by the isolated integration test.
static int inspect(lua_State* L) {
    lua_newtable(L);
    for (const auto& monitor : State::monitorState()->monitors()) {
        const auto ws = monitor->m_activeWorkspace;
        if (!ws) continue;
        lua_newtable(L);
        lua_pushnumber(L, ws->m_alpha->value()); lua_setfield(L, -2, "alpha");
        lua_pushnumber(L, ws->m_alpha->goal()); lua_setfield(L, -2, "goal_alpha");
        lua_pushinteger(L, ws->m_id); lua_setfield(L, -2, "workspace");
        lua_pushnumber(L, ws->m_renderOffset->value().x); lua_setfield(L, -2, "x");
        lua_pushnumber(L, ws->m_renderOffset->value().y); lua_setfield(L, -2, "y");
        lua_pushnumber(L, ws->m_renderOffset->goal().x); lua_setfield(L, -2, "goal_x");
        lua_pushnumber(L, ws->m_renderOffset->goal().y); lua_setfield(L, -2, "goal_y");
        lua_setfield(L, -2, monitor->m_name.c_str());
    }
    return 1;
}

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (HyprlandAPI::getHyprlandVersion(handle).hash != GIT_COMMIT_HASH)
        throw std::runtime_error("Hyprworld shared workspaces: rebuild against the running Hyprland version");
    const auto source = static_cast<ChangeWorkspace>(&Config::Actions::changeWorkspace);
    workspaceHook = HyprlandAPI::createFunctionHook(handle, reinterpret_cast<void*>(source), reinterpret_cast<void*>(&requestWorkspace));
    if (!workspaceHook || !workspaceHook->hook())
        throw std::runtime_error("Hyprworld shared workspaces: could not hook workspace requests");
    HyprlandAPI::addLuaFunction(handle, "hyprworld_shared", "inspect", inspect);
    HyprlandAPI::addLuaFunction(handle, "hyprworld_shared", "set_enabled", setEnabled);
    return {"hyprworld-shared-workspaces", "Shared workspaces with spatial monitor swaps", "Hyprworld", "1.0.0"};
}
APICALL EXPORT void PLUGIN_EXIT() {
    if (workspaceHook) workspaceHook->unhook();
    workspaceHook = nullptr;
}
