.PHONY: test check native

native:
	bash native/build.sh

test:
	lua tests/checkpoint.lua
	lua tests/preferences_safety.lua
	lua tests/plugin_failure.lua
	node tests/minimap.cjs
	node tests/preview_recovery.cjs
	HYPRWORLD_TEST_PREVIEW_EVENTS=1 lua tests/with-preferences.lua tests/hyprland_adapter.lua | node tests/preview_stream.cjs
	python3 -m unittest discover -s tests -p 'test_*.py'
	lua tests/bootstrap.lua
	lua tests/arrangements.lua
	python3 tests/startup.py
	node tests/search.cjs
	lua tests/touchpad.lua
	node tests/workspace_model.cjs
	node tests/settings.cjs
	lua tests/run.lua
	lua tests/groups.lua
	lua tests/compaction_delay.lua
	lua tests/gestures.lua
	python3 tests/shortcuts.py
	lua tests/with-preferences.lua tests/hyprland_adapter.lua
	lua tests/rapid_focus.lua
	lua tests/omarchy_integration.lua
	lua tests/workspaces.lua
	bash tests/installer.sh

check: test
	luac -p layout/*.lua integration/*.lua tests/*.lua
	bash -n install.sh uninstall.sh tests/installer.sh
	python3 -m json.tool manifest.json >/dev/null
	test -f Service.qml
	@if command -v omarchy >/dev/null 2>&1; then omarchy plugin validate .; fi
