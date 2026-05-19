extends Node

enum ThemeMode {
	LIGHT,
	DARK
}

var current_mode: ThemeMode = ThemeMode.DARK

var light_theme: Theme = preload(
	"res://resources/ui/light_theme.tres"
)

var dark_theme: Theme = preload(
	"res://resources/ui/dark_theme.tres"
)
signal theme_changed(mode: ThemeMode)

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	apply_theme(current_mode)

func _on_node_added(node: Node) -> void:
	if node is Control:
		_apply_to_node_recursive(node)

func _apply_to_node_recursive(node: Node) -> void:
	if node is Control:
		node.theme = get_current_theme()

	for c in node.get_children():
		_apply_to_node_recursive(c)

func get_current_theme() -> Theme:
	return dark_theme if current_mode == ThemeMode.DARK else light_theme

func toggle_theme(button_pressed: bool) -> void:

	if button_pressed:
		apply_theme(ThemeMode.LIGHT)
	else:
		apply_theme(ThemeMode.DARK)

func apply_theme(mode: ThemeMode) -> void:

	current_mode = mode

	match mode:

		ThemeMode.LIGHT:
			get_tree().root.theme = light_theme

		ThemeMode.DARK:
			get_tree().root.theme = dark_theme
	theme_changed.emit(mode)
