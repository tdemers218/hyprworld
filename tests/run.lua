local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)/[^/]+$") or "tests"
local root = tests_dir:match("^(.*)/tests$") or "."
local core = assert(loadfile(root .. "/layout/core.lua"))()
local config = assert(loadfile(root .. "/layout/config.lua"))()
local passed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        io.stderr:write("FAIL: " .. name .. "\n" .. tostring(err) .. "\n")
        os.exit(1)
    end
    passed = passed + 1
    print("ok - " .. name)
end

local function equal(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function fresh(ids, active)
    local state = core.new_state()
    core.sync(state, ids, active, config)
    return state
end

test("first window starts at origin", function()
    local state = fresh({ "A" }, "A")
    equal(core.position_of(state, "A").col, 0)
    equal(core.position_of(state, "A").row, 0)
end)

test("new windows extend to the right", function()
    local state = fresh({ "A", "B", "C" }, "A")
    equal(core.position_of(state, "B").col, 1)
    equal(core.position_of(state, "C").col, 2)
end)

test("moving down creates a second row", function()
    local state = fresh({ "A", "B" }, "B")
    assert(core.move(state, "down"))
    equal(core.position_of(state, "B").col, 1)
    equal(core.position_of(state, "B").row, 1)
    equal(state.camera.row, 1)
end)

test("moving into an occupied cell groups windows", function()
    local state = fresh({ "A", "B" }, "B")
    assert(core.move(state, "left"))
    equal(core.position_of(state, "B").col, 0)
    equal(core.position_of(state, "A").col, 0)
    equal(#core.members(state, "A"), 2)
end)

test("focus prefers a window aligned on the requested axis", function()
    local state = fresh({ "A", "B", "C" }, "A")
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    equal(core.focus(state, "right"), "B")
end)

test("focus moves vertically", function()
    local state = fresh({ "A", "B" }, "B")
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    equal(core.focus(state, "down"), "B")
end)

test("width and height presets are independent", function()
    local state = fresh({ "A" }, "A")
    core.resize_width(state, config, 1)
    core.resize_height(state, config, -1)
    local width_step, height_step = core.size_steps_of(state, "A")
    equal(width_step, math.min(config.default_width_step + 1, #config.width_steps))
    equal(height_step, math.max(config.default_height_step - 1, 1))
end)

test("resize clamps at preset boundaries", function()
    local state = fresh({ "A" }, "A")
    for _ = 1, 10 do core.resize_width(state, config, -1) end
    local width_step = core.size_steps_of(state, "A")
    equal(width_step, 1)
    for _ = 1, 10 do core.resize_width(state, config, 1) end
    width_step = core.size_steps_of(state, "A")
    equal(width_step, #config.width_steps)
end)

test("maximum cell leaves horizontal and vertical peeks", function()
    local state = fresh({ "A", "B" }, "A")
    state.width_step_by_id.A = #config.width_steps
    state.height_step_by_id.A = #config.height_steps
    state.width_step_by_id.B = #config.width_steps
    state.height_step_by_id.B = #config.height_steps
    state.focused_id = "B"
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    local placements = core.placements(state, { x = 0, y = 0, w = 1000, h = 800 }, config)
    equal(placements.A.x, 48)
    equal(placements.A.y, 48)
    equal(placements.A.w, 904)
    equal(placements.A.h, 704)
    equal(placements.B.y, 764)
end)

test("smaller presets keep neighboring rows visible", function()
    local state = fresh({ "A", "B" }, "A")
    state.focused_id = "B"
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    local placements = core.placements(state, { x = 0, y = 0, w = 1000, h = 800 }, config)
    assert(placements.B.y < 800, "the next row should peek into the viewport")
    assert(placements.B.y > placements.A.y, "the next row should remain below the focused row")
end)

test("camera follows focus in both dimensions", function()
    local state = fresh({ "A", "B" }, "B")
    core.move(state, "down")
    equal(state.camera.col, 1)
    equal(state.camera.row, 1)
end)

test("manual camera pan survives ordinary synchronization", function()
    local state = fresh({ "A" }, "A")
    core.pan(state, "down")
    core.sync(state, { "A" }, "A", config)
    equal(state.camera.row, 1)
end)

test("zoom scales every tile and restores its original geometry", function()
    local state = fresh({ "A", "B" }, "A")
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    local area = { x = 0, y = 0, w = 1000, h = 800 }
    local before = core.placements(state, area, config)
    assert(core.zoom(state, config, 1))
    local zoomed = core.placements(state, area, config)
    assert(zoomed.A.w > before.A.w and zoomed.A.h > before.A.h, "zoom in must grow every tile")
    assert(zoomed.B.w > before.B.w and zoomed.B.h > before.B.h, "zoom must apply to neighboring tiles")
    assert(core.zoom(state, config, -1))
    local restored = core.placements(state, area, config)
    equal(restored.A.w, before.A.w)
    equal(restored.A.h, before.A.h)
    equal(restored.B.y, before.B.y)
end)

test("maximum zoom preserves outer margins on a wide monitor", function()
    local state = fresh({ "A" }, "A")
    state.zoom_step = #config.zoom_steps
    local area = { x = 0, y = 0, w = 2560, h = 1440 }
    local placement = core.placements(state, area, config).A
    assert(placement.x >= config.max_zoom_margin)
    assert(placement.y >= config.max_zoom_margin)
    assert(placement.x + placement.w <= area.w - config.max_zoom_margin)
    assert(placement.y + placement.h <= area.h - config.max_zoom_margin)
end)

test("directional growth anchors the opposite edge", function()
    local state = fresh({ "A", "B" }, "A")
    state.focused_id = "B"
    core.move(state, "down")
    core.move(state, "left")
    state.width_step_by_id.A = #config.width_steps
    state.focused_id = "B"
    core.resize_width(state, config, -1)
    assert(core.resize_direction(state, config, "right"))
    local placements = core.placements(state, { x = 0, y = 0, w = 1000, h = 800 }, config)
    assert(state.align_x_by_id.B == -1, "right growth must anchor the left edge")
    assert(placements.B.x < 100, "left-aligned tile should use the left side of its cell")
end)

test("directional resize clamps without rejecting repeated commands", function()
    local state = fresh({ "A" }, "A")
    for _ = 1, 10 do assert(core.resize_direction(state, config, "right")) end
    local width = core.size_steps_of(state, "A")
    equal(width, #config.width_steps)
    for _ = 1, 10 do assert(core.resize_direction(state, config, "left")) end
    width = core.size_steps_of(state, "A")
    equal(width, 1)
end)

test("maximum tile toggles back to the default size", function()
    local state = fresh({ "A" }, "A")
    core.resize_direction(state, config, "right")
    assert(core.toggle_maximize(state, config))
    local max_width, max_height = core.size_steps_of(state, "A")
    equal(max_width, #config.width_steps)
    equal(max_height, #config.height_steps)
    assert(core.toggle_maximize(state, config))
    local restored_width, restored_height = core.size_steps_of(state, "A")
    equal(restored_width, config.default_width_step)
    equal(restored_height, config.default_height_step)
    equal(state.align_x_by_id.A, 0)
end)

test("closed windows are removed without disturbing survivors", function()
    local state = fresh({ "A", "B", "C" }, "B")
    local original = core.position_of(state, "C").col
    core.sync(state, { "A", "C" }, "C", config)
    assert(not core.has_id(state, "B"))
    equal(core.position_of(state, "C").col, original)
end)

print(string.format("hyprworld: %d tests passed", passed))
