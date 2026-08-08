extends Control
## App shell: Typewriter main view + Settings tab.

@onready var tabs: TabContainer = %Tabs


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	tabs.set_tab_title(0, "Typewriter")
	tabs.set_tab_title(1, "Settings")
	var settings := tabs.get_node_or_null("Settings")
	if settings and settings.has_signal("request_rebuild_assets"):
		settings.request_rebuild_assets.connect(_rebuild)
	var machine := tabs.get_node_or_null("Typewriter")
	if machine and machine.has_method("_rebuild_assets"):
		pass


func _rebuild() -> void:
	var machine := tabs.get_node_or_null("Typewriter")
	if machine and machine.has_method("_rebuild_assets"):
		await machine._rebuild_assets()
		if machine.has_method("_build_keyboard"):
			machine._build_keyboard()
		if machine.has_method("_apply_settings"):
			machine._apply_settings()
