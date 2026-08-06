@tool
extends EditorPlugin
## Registers minit.gd as the `Minit` autoload.
##
## project.godot already declares the autoload so headless exports work without
## the editor ever enabling this plugin — so both hooks are guarded and are
## no-ops when the setting is already in place.

const AUTOLOAD_NAME := "Minit"
const AUTOLOAD_PATH := "res://addons/minit/minit.gd"


func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	# Only withdraw the autoload if it is ours to withdraw.
	var setting := ProjectSettings.get_setting("autoload/" + AUTOLOAD_NAME, "")
	if String(setting).ends_with(AUTOLOAD_PATH):
		remove_autoload_singleton(AUTOLOAD_NAME)
