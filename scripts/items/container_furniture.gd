extends Node2D

@export var container_component_path: NodePath = NodePath("SolidArea/ContainerComponent")


func save_state() -> Dictionary:
var container: ContainerComponent = _container_component()
if container == null:
return {}

return {
"container_state": container.save_state(),
}


func load_state(data: Dictionary) -> void:
var container: ContainerComponent = _container_component()
if container == null:
return

var state_variant: Variant = data.get("container_state", {})
if not (state_variant is Dictionary):
return

container.load_state(state_variant as Dictionary)


func _container_component() -> ContainerComponent:
var node: Node = get_node_or_null(container_component_path)
if node is ContainerComponent:
return node as ContainerComponent
return null
