extends Node3D

var controller: Node
var velocity: Vector3 = Vector3.ZERO
var damage: float = 24.0
var blast_radius: float = 0.0
var projectile_kind: StringName = &"infantry"
var source: Node
var age: float = 0.0
var max_age: float = 8.0
var gravity: float = 1.2
var _previous_position: Vector3 = Vector3.ZERO

func launch(
	chapter_controller: Node,
	start: Vector3,
	direction: Vector3,
	speed: float,
	impact_damage: float,
	radius: float,
	kind: StringName,
	firing_source: Node = null
) -> void:
	controller = chapter_controller
	global_position = start
	velocity = direction.normalized() * speed
	damage = impact_damage
	blast_radius = radius
	projectile_kind = kind
	source = firing_source
	_previous_position = start
	_add_visual()

func _add_visual() -> void:
	var shell_scene: PackedScene = load("res://assets/props/artillery_shell.glb") as PackedScene
	if shell_scene != null:
		var shell: Node3D = shell_scene.instantiate() as Node3D
		shell.scale = Vector3.ONE * 0.16
		shell.rotation_degrees.x = 90.0
		add_child(shell)
	else:
		var mesh_instance := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.09
		mesh.height = 0.18
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("#d59c3b")
		material.emission_enabled = true
		material.emission = Color("#9a4e19")
		material.emission_energy_multiplier = 0.65
		mesh_instance.material_override = material
		add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller):
		queue_free()
		return
	age += delta
	if age >= max_age:
		controller.call("explode_at", global_position, damage, blast_radius, source, projectile_kind)
		queue_free()
		return
	velocity.y -= gravity * delta
	var next_position: Vector3 = global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(_previous_position, next_position)
	if is_instance_valid(source) and source is CollisionObject3D:
		query.exclude = [(source as CollisionObject3D).get_rid()]
	query.collision_mask = 1
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node and collider.has_method("receive_projectile"):
			collider.call("receive_projectile", damage, projectile_kind, source)
		controller.call("explode_at", hit.get("position", next_position), damage, blast_radius, source, projectile_kind)
		queue_free()
		return
	_previous_position = next_position
	global_position = next_position
	if velocity.length_squared() > 0.1:
		look_at(global_position + velocity.normalized(), Vector3.UP)
