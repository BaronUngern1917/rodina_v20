extends Node

const HITBOX_SCRIPT: Script = preload("res://scripts/Chapter2Hitbox.gd")
const TRUCK_SPEED := 15.5
const INITIAL_GAP := 58.0
const LOSE_GAP := 9.0
const WIN_GAP := 104.0
const TANK_BASE_CLOSING_RATE := 1.45
const TRACK_CONDITION_RECOVERY_RATE := 15.0

var game: Node3D
var player: CharacterBody3D
var truck: StaticBody3D
var truck_visual: Node3D
var world_root: Node3D
var tank: Node3D
var tank_visual: Node3D
var turret: Node3D
var plane_nodes: Array[Node3D] = []
var plane_animations: Array[AnimationPlayer] = []
var route_controls: Array[Vector3] = []
var route_points: Array[Vector3] = []
var route_cumulative: PackedFloat32Array = PackedFloat32Array()
var ground_material: ShaderMaterial
var route_length := 0.0
var truck_distance := 0.0
var current_truck_speed := TRUCK_SPEED
var chase_distance := INITIAL_GAP
var current_tank_forward_speed := TRUCK_SPEED + TANK_BASE_CLOSING_RATE
var elapsed := 0.0
var battle_idle_time := 0.0
var battle_ambience_timer := 4.0
var track_condition := 0.0
var hull_slow_timer := 0.0
var suspension_offset := 0.0
var suspension_velocity := 0.0
var bump_cooldown := 0.0
var landing_impact_cooldown := 0.0
var tank_suspension_offset := 0.0
var tank_suspension_velocity := 0.0
var tank_bump_cooldown := 0.0
var tank_fire_timer := 5.0
var flyby_timer := 7.0
var stuka_siren_cooldown := 1.0
var music_player: AudioStreamPlayer
var truck_engine: AudioStreamPlayer3D
var tank_tracks: AudioStreamPlayer3D
var truck_impact: AudioStreamPlayer3D
var hull_impact: AudioStreamPlayer3D
var track_impact: AudioStreamPlayer3D
var plane_audio: AudioStreamPlayer3D
var stuka_siren: AudioStreamPlayer3D
var tank_cannon: AudioStreamPlayer3D
var battle_machinegun: AudioStreamPlayer3D
var battle_rifle: AudioStreamPlayer3D
var chase_label: Label
var gap_bar: ProgressBar
var outcome_layer: Control
var outcome_label: Label
var player_base_yaw := 0.0
var player_base_pitch := 0.0
var active := false
var cutscene_active := false
var test_scenario := ""
var test_shot_timer := 0.0
var test_speed := 1.0
var result := ""
var hit_effects: Array[MeshInstance3D] = []
var intro_frames: Array[Texture2D] = []
var intro_frame_index := 0
var intro_frame_timer := 0.0
var intro_card: TextureRect
var intro_audio: AudioStreamPlayer

func begin(game_node: Node3D, test_mode: String = "") -> void:
	game = game_node
	player = game.get_node("Player") as CharacterBody3D
	truck = game.get_node_or_null("ZIS5") as StaticBody3D
	if truck == null:
		push_error("Chapter 2 requires the existing Chapter 1 ZiS-5 instance named ZIS5.")
		return
	truck_visual = truck.get_node_or_null("ZIS5Visual") as Node3D
	test_scenario = test_mode
	world_root = Node3D.new()
	world_root.name = "Chapter2World"
	game.add_child(world_root)
	_hide_chapter_one_set()
	_build_environment()
	_build_route()
	_build_terrain()
	_build_road()
	_build_battlefield()
	_build_tank()
	_build_planes()
	_build_audio()
	_build_hud()
	if test_scenario == "none" or test_scenario == "hull" or test_scenario == "tracks":
		test_speed = 2.8
	else:
		test_speed = 1.0
	_play_intro_then_chase(test_scenario != "")

func _hide_chapter_one_set() -> void:
	for child in game.get_children():
		if child == player or child == truck or child == world_root or child is CanvasLayer or child is WorldEnvironment or child is DirectionalLight3D:
			continue
		if child is Node3D:
			(child as Node3D).visible = false
			_disable_collision_tree(child)
	truck.collision_layer = 0
	truck.collision_mask = 0
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED

func _disable_collision_tree(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_collision_tree(child)

func _build_environment() -> void:
	var environment_node := game.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null:
		return
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#70818a")
	sky_material.sky_horizon_color = Color("#c0beb3")
	sky_material.ground_bottom_color = Color("#383c39")
	sky_material.ground_horizon_color = Color("#838177")
	sky_material.sun_angle_max = 20.0
	sky_material.sun_curve = 0.16
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_energy_multiplier = 0.88
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#949689")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#92938a")
	environment.fog_density = 0.00072
	environment_node.environment = environment
	var scene_world := game.get_viewport().world_3d
	if scene_world:
		scene_world.environment = environment
	if player and player.camera:
		player.camera.environment = environment
	var sun := game.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
		sun.light_color = Color("#f3f0e6")
		sun.light_energy = 0.82
		sun.shadow_enabled = true

func _build_route() -> void:
	route_controls.clear()
	# Uneven Lissajous control points make a broad, lopsided figure eight.
	# Localized warps disguise its geometry while retaining one closed drive line.
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		var x := 84.0 * sin(angle) + 14.0 * sin(3.0 * angle + 0.25) + 5.0 * cos(5.0 * angle)
		var z := 63.0 * sin(2.0 * angle) + 11.0 * cos(3.0 * angle + 0.4) + 5.0 * sin(7.0 * angle)
		if i in [3, 4, 11, 12, 17, 18]:
			x += 6.0 * sin(angle * 2.0)
			z += 5.0 * cos(angle * 3.0)
		route_controls.append(Vector3(x, 0.0, z))
	route_points.clear()
	for i in range(route_controls.size()):
		var p0: Vector3 = route_controls[(i - 1 + route_controls.size()) % route_controls.size()]
		var p1: Vector3 = route_controls[i]
		var p2: Vector3 = route_controls[(i + 1) % route_controls.size()]
		var p3: Vector3 = route_controls[(i + 2) % route_controls.size()]
		for sample in range(8):
			var t := float(sample) / 8.0
			var point := _catmull(p0, p1, p2, p3, t)
			point.y = _route_height(point, float(i) + t)
			route_points.append(point)
	route_cumulative.resize(route_points.size() + 1)
	route_cumulative[0] = 0.0
	for i in range(route_points.size()):
		route_length += route_points[i].distance_to(route_points[(i + 1) % route_points.size()])
		route_cumulative[i + 1] = route_length

func _catmull(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3)

func _terrain_height(x: float, z: float) -> float:
	var broad := 2.0 * sin(x / 37.0 + z / 71.0) + 1.4 * cos(z / 29.0 - x / 58.0)
	var rolling := 0.75 * sin((x + z) / 13.5) * cos((x - z) / 17.0)
	var ravine := -2.2 * exp(-pow((x - 2.0) / 15.0, 2.0)) * exp(-pow((z + 8.0) / 49.0, 2.0))
	return broad + rolling + ravine

func _route_height(point: Vector3, sample_index: float) -> float:
	var t := sample_index / 24.0 * TAU
	# Keep the drive line close to the terrain surface; truck suspension and
	# the terrain mesh provide the rough-road motion without a floating ribbon.
	var ridge := 0.22 * sin(t * 2.7 + 0.4) + 0.12 * sin(t * 5.1)
	return _terrain_height(point.x, point.z) + ridge + 0.28

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions := 108
	var extent := 190.0
	var step := extent * 2.0 / float(divisions)
	for iz in range(divisions):
		for ix in range(divisions):
			var x0 := -extent + float(ix) * step
			var x1 := x0 + step
			var z0 := -extent + float(iz) * step
			var z1 := z0 + step
			var a := Vector3(x0, _terrain_height(x0, z0), z0)
			var b := Vector3(x0, _terrain_height(x0, z1), z1)
			var c := Vector3(x1, _terrain_height(x1, z1), z1)
			var d := Vector3(x1, _terrain_height(x1, z0), z0)
			for v in [a, b, c, a, c, d]:
				st.set_color(_ground_tint(v.x, v.z))
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit() as ArrayMesh
	var ground_shader := Shader.new()
	ground_shader.code = "shader_type spatial;\nrender_mode cull_disabled;\n" + \
		"uniform sampler2D ground_texture : source_color, repeat_enable, filter_linear_mipmap;\n" + \
		"uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap;\n" + \
		"uniform vec3 color_tint = vec3(1.0);\n" + \
		"uniform bool road_blend = false;\n" + \
		"varying vec3 world_position;\n" + \
		"varying vec3 terrain_tint;\n" + \
		"void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; terrain_tint = COLOR.rgb; }\n" + \
		"void fragment() {\n" + \
		"  vec2 uv = fract(world_position.xz / 30.0) * vec2(0.62, 0.66) + vec2(0.09, 0.15);\n" + \
		"  vec3 dirt = texture(ground_texture, uv).rgb;\n" + \
		"  float patch = 0.90 + 0.10 * sin(world_position.x * 0.08 + world_position.z * 0.03) * cos(world_position.z * 0.06);\n" + \
		"  if (road_blend) {\n" + \
		"    float edge_noise = 0.035 * sin(world_position.x * 0.43 + world_position.z * 0.17) + 0.028 * cos(world_position.z * 0.51 - world_position.x * 0.12);\n" + \
		"    float shoulder = smoothstep(0.60 + edge_noise, 0.96 + edge_noise, abs(UV.x));\n" + \
		"    float ruts = exp(-pow((abs(UV.x) - 0.42) / 0.075, 2.0)) * (1.0 - shoulder);\n" + \
		"    vec2 gravel_uv = fract(world_position.xz * 0.12 + vec2(0.17, 0.31)) * 0.90 + vec2(0.05);\n" + \
		"    vec3 gravel = texture(road_texture, gravel_uv).rgb;\n" + \
		"    vec3 road_dirt = mix(dirt * vec3(0.72, 0.65, 0.55), gravel * vec3(0.82, 0.82, 0.76), 0.68) * (1.0 - ruts * 0.06);\n" + \
		"    vec3 shoulder_dirt = dirt * vec3(1.00, 0.93, 0.81);\n" + \
		"    ALBEDO = mix(road_dirt, shoulder_dirt, shoulder) * patch;\n" + \
		"  } else { ALBEDO = dirt * patch * color_tint * terrain_tint; }\n" + \
		"  ROUGHNESS = 1.0;\n" + \
		"}\n"
	ground_material = ShaderMaterial.new()
	ground_material.shader = ground_shader
	ground_material.set_shader_parameter("ground_texture", load("res://assets/props/low_poly_dirt_ground_0.jpg"))
	ground_material.set_shader_parameter("color_tint", Vector3(1.08, 1.0, 0.88))
	mesh.surface_set_material(0, ground_material)
	var terrain := StaticBody3D.new()
	terrain.name = "RollingBattlefieldTerrain"
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	terrain.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	terrain.add_child(collision)
	world_root.add_child(terrain)

func _ground_tint(x: float, z: float) -> Color:
	var broad_noise := 0.5 + 0.5 * sin(x * 0.16 + z * 0.11) * cos(z * 0.13 - x * 0.08)
	var fine_noise := 0.5 + 0.5 * sin(x * 1.73 + z * 0.91) * cos(z * 1.47 - x * 1.21)
	var noise := broad_noise * 0.72 + fine_noise * 0.28
	return Color(0.88 + noise * 0.13, 0.84 + noise * 0.12, 0.74 + noise * 0.1)

func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 3.9
	for i in range(route_points.size()):
		var p0: Vector3 = route_points[i]
		var p1: Vector3 = route_points[(i + 1) % route_points.size()]
		var previous_point: Vector3 = route_points[(i - 1 + route_points.size()) % route_points.size()]
		var following_point: Vector3 = route_points[(i + 2) % route_points.size()]
		var tangent0 := (p1 - previous_point).normalized()
		var tangent1 := (following_point - p0).normalized()
		var side0 := Vector3(-tangent0.z, 0.0, tangent0.x).normalized() * width
		var side1 := Vector3(-tangent1.z, 0.0, tangent1.x).normalized() * width
		var l0 := _road_edge_vertex(p0 - side0, p0.y + 0.045, -1.0)
		var c0 := p0 + Vector3.UP * 0.045
		var r0 := _road_edge_vertex(p0 + side0, p0.y + 0.045, 1.0)
		var l1 := _road_edge_vertex(p1 - side1, p1.y + 0.045, -1.0)
		var c1 := p1 + Vector3.UP * 0.045
		var r1 := _road_edge_vertex(p1 + side1, p1.y + 0.045, 1.0)
		var edge_vertices: Array[Vector3] = [l0, c0, c1, l0, c1, l1, c0, r0, r1, c0, r1, c1]
		var lateral_uvs: Array[Vector2] = [Vector2(-1.0, 0.0), Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
		for vertex_index in range(edge_vertices.size()):
			st.set_uv(lateral_uvs[vertex_index])
			st.add_vertex(edge_vertices[vertex_index])
	st.generate_normals()
	var mesh := st.commit() as ArrayMesh
	var road_material := ground_material.duplicate() as ShaderMaterial
	road_material.set_shader_parameter("road_blend", true)
	road_material.set_shader_parameter("road_texture", load("res://assets/props/gravel_road_2_0.jpg"))
	mesh.surface_set_material(0, road_material)
	var road_body := StaticBody3D.new()
	road_body.name = "RuttedFigureEightTrack"
	var road_visual := MeshInstance3D.new()
	road_visual.mesh = mesh
	road_body.add_child(road_visual)
	var collider := CollisionShape3D.new()
	collider.shape = mesh.create_trimesh_shape()
	road_body.add_child(collider)
	world_root.add_child(road_body)
	# Extract a few individual stones so the imported sample grid does not create
	# artificial rows beside the road.
	var rock_scene := load("res://assets/props/stylised_rocks_asset_pack.glb") as PackedScene
	if rock_scene:
		_scatter_roadside_rocks(rock_scene)

func _road_edge_vertex(point: Vector3, center_height: float, lateral: float) -> Vector3:
	var outer_height: float = _terrain_height(point.x, point.z) + 0.055
	var road_weight := 1.0 - pow(absf(lateral), 1.4)
	point.y = lerpf(outer_height, center_height, road_weight)
	return point

func _scatter_roadside_rocks(rock_scene: PackedScene) -> void:
	var source := rock_scene.instantiate() as Node3D
	if source == null:
		return
	world_root.add_child(source)
	var candidates: Array[MeshInstance3D] = []
	var pending: Array[Node] = [source]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			var mesh_name := String(mesh_node.name)
			var is_natural_rock := mesh_name.ends_with("_M_Mossy_Rock_0") or mesh_name.ends_with("_M_Plain_Rock_0")
			if is_natural_rock and mesh_node.mesh:
				var world_bounds: AABB = mesh_node.global_transform * mesh_node.get_aabb()
				var largest_extent := maxf(world_bounds.size.x, maxf(world_bounds.size.y, world_bounds.size.z))
				if largest_extent <= 3.2 and largest_extent >= 0.3:
					candidates.append(mesh_node)
		for child in node.get_children():
			pending.append(child)
	if candidates.is_empty():
		source.queue_free()
		return
	var rock_count := mini(76, candidates.size())
	for i in range(rock_count):
		var mesh_node: MeshInstance3D = candidates[(i * 7 + 3) % candidates.size()]
		var distance := route_length * (float(i) + 0.31) / float(rock_count)
		var sample := _route_at(distance)
		var tangent := _tangent_at(distance)
		var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		var side_sign := 1.0 if i % 2 == 0 else -1.0
		var offset := side * (6.5 + float((i * 11) % 10)) * side_sign
		var target := sample + offset
		var variation := 0.42 + float((i * 5) % 7) * 0.045
		var yaw := float(i * 37 % 360) * PI / 180.0
		mesh_node.reparent(world_root, true)
		mesh_node.name = "RoadsideStone_%02d" % i
		var original_scale := mesh_node.global_transform.basis.get_scale().x
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * original_scale * variation)
		var transformed_bounds: AABB = Transform3D(basis, Vector3.ZERO) * mesh_node.get_aabb()
		mesh_node.global_transform = Transform3D(basis, Vector3(
			target.x - transformed_bounds.position.x - transformed_bounds.size.x * 0.5,
			_terrain_height(target.x, target.z) - transformed_bounds.position.y,
			target.z - transformed_bounds.position.z - transformed_bounds.size.z * 0.5
		))
	source.queue_free()

func _build_battlefield() -> void:
	var pine_scene := load("res://assets/props/pine_tree.glb") as PackedScene
	var trench_scene := load("res://assets/props/trench_set.glb") as PackedScene
	var bunker_scene := load("res://assets/props/bunker_o323a-160_z.glb") as PackedScene
	var barn_scene := load("res://assets/props/old_wooden_barn.glb") as PackedScene
	var house_scene := load("res://assets/props/french_house_ww2.glb") as PackedScene
	var barrier_scene := load("res://assets/props/metal_barrier_tank_17_mb.glb") as PackedScene
	var crash_plane := load("res://assets/props/airplane_crash.glb") as PackedScene
	var mill_scene := load("res://assets/props/mill.glb") as PackedScene
	var tank_wreck_scenes: Array[PackedScene] = [
		load("res://assets/props/kv_sd_crash.glb") as PackedScene,
		load("res://assets/props/-28_sd_crash.glb") as PackedScene,
		load("res://assets/props/-26_sd_crash.glb") as PackedScene,
		load("res://assets/props/kv_sd_crash.glb") as PackedScene,
		load("res://assets/props/-28_sd_crash.glb") as PackedScene,
		load("res://assets/props/kv_sd_crash.glb") as PackedScene
	]
	var crates_scene := load("res://assets/props/assets_pack_free_survivalpostapo.glb") as PackedScene
	var soviet_scene := load("res://assets/props/ww2_soviet_uniform.glb") as PackedScene
	var german_scene := load("res://assets/props/ww2_german_wehrmacht_soldier.glb") as PackedScene
	_scatter_roadside_grass()
	_scatter_battlefield_forest(pine_scene)
	for i in range(52):
		var distance := route_length * (float(i) + 0.38) / 52.0
		var p := _route_at(distance)
		var tangent := _tangent_at(distance)
		var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		var set_side_sign: float = 1.0 if i % 2 == 0 else -1.0
		# Military set pieces occupy clearings beside the road, never the track.
		var set_side: Vector3 = side * set_side_sign
		var set_offset_distance := 26.0 + float(i % 4) * 1.7
		var set_position := _find_route_clear_position(p, set_side, tangent, set_offset_distance, 18.0)
		var set_offset: Vector3 = set_position - p
		var yaw := atan2(tangent.x, tangent.z)
		if i in [2, 21] and trench_scene:
			var trench_piece := "Plane015_End section_0" if i == 2 else "Plane015_End section_0"
			_spawn_trench_piece(trench_scene, set_position, yaw, trench_piece, 0.78, "TrenchPosition")
			var trench_soldier_scene: PackedScene = soviet_scene if i == 2 else german_scene
			_spawn_cover_and_soldiers(set_position + tangent * 1.5, trench_soldier_scene, -set_offset.normalized(), true)
			_spawn_cover_and_soldiers(set_position - tangent * 1.5, trench_soldier_scene, -set_offset.normalized(), true)
		elif i in [6, 30] and bunker_scene:
			_spawn_model(bunker_scene, set_position, Vector3.ONE * 0.31, yaw + 0.3, "BunkerPosition")
			var bunker_soldier_scene: PackedScene = german_scene if i == 6 else soviet_scene
			var bunker_front: Vector3 = set_position - set_offset.normalized() * 5.5
			_spawn_cover_and_soldiers(bunker_front + tangent * 1.35, bunker_soldier_scene, -set_offset.normalized(), false)
			_spawn_cover_and_soldiers(bunker_front - tangent * 1.35, bunker_soldier_scene, -set_offset.normalized(), true)
		elif i in [10, 25] and barn_scene:
			_spawn_model(barn_scene, set_position, Vector3.ONE * 0.7, yaw + 0.4, "BurnedBarn")
			if house_scene:
				_spawn_model(house_scene, set_position + side * 16.0, Vector3.ONE * 0.64, yaw - 0.5, "RuinedVillageHouse")
		elif i == 18 and crash_plane:
			_spawn_model(crash_plane, set_position, Vector3.ONE * 0.7, yaw + 1.4, "CrashedAircraft")
		elif i in [12, 33, 39, 42, 44, 49]:
			var wreck_index: int = [12, 33, 39, 42, 44, 49].find(i)
			var wreck_scene: PackedScene = tank_wreck_scenes[wreck_index]
			if wreck_scene:
				var wreck_scale: float = [0.68, 0.75, 0.68, 0.70, 0.71, 0.72][wreck_index]
				_spawn_model(wreck_scene, set_position, Vector3.ONE * wreck_scale, yaw + 0.8 + float(wreck_index) * 0.32, "AbandonedTankWreck_%02d" % wreck_index)
		elif i % 4 == 1 and barrier_scene:
			_spawn_model(barrier_scene, set_position, Vector3.ONE * 0.68, yaw, "TankObstaclePosition")
		elif crates_scene and i % 7 == 0:
			_spawn_supply_group(crates_scene, set_position, yaw)
	# A low wooded ravine and distant, noninteractive village roofs hide the figure-eight.
	var house := load("res://assets/props/french_house_ww2.glb") as PackedScene
	if house:
		_spawn_model(house, Vector3(139.0, _terrain_height(139.0, -104.0), -104.0), Vector3.ONE * 0.55, -0.45, "FarVillageHouse")
		_spawn_model(house, Vector3(-145.0, _terrain_height(-145.0, 120.0), 120.0), Vector3.ONE * 0.52, 0.6, "FarVillageHouse")
	if mill_scene:
		var mill_distance := route_length * 0.71
		var mill_route_point := _route_at(mill_distance)
		var mill_tangent := _tangent_at(mill_distance)
		var mill_side := Vector3(-mill_tangent.z, 0.0, mill_tangent.x).normalized()
		var mill_position := _find_route_clear_position(mill_route_point, mill_side, mill_tangent, 53.0, 22.0)
		mill_position.y = _terrain_height(mill_position.x, mill_position.z)
		var mill := _spawn_model(mill_scene, mill_position, Vector3.ONE * 0.18, atan2(mill_tangent.x, mill_tangent.z) + 0.55, "BattlefieldWindmill")
		var mill_player := _find_animation_player(mill)
		if mill_player and mill_player.has_animation("Take 001"):
			mill_player.get_animation("Take 001").loop_mode = Animation.LOOP_LINEAR
			mill_player.play("Take 001")

func _scatter_battlefield_forest(pine_scene: PackedScene) -> void:
	if pine_scene == null:
		return
	var forest_piece_index := 0
	var landmark_distances: Array[float] = []
	for landmark_index in [2, 6, 10, 18, 21, 25, 30, 33, 39, 44, 49]:
		landmark_distances.append(route_length * (float(landmark_index) + 0.38) / 52.0)
	var mill_distance := route_length * 0.71
	var stations := 165
	for i in range(stations):
		var distance := route_length * (float(i) + 0.5) / float(stations)
		var point := _route_at(distance)
		var tangent := _tangent_at(distance)
		var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		for side_sign in [-1.0, 1.0]:
			var variation: int = posmod(i * 17 + int(side_sign * 5.0), 9)
			var offset := 10.5 + float(variation) * 0.58
			var clear_for_landmark := false
			if side_sign > 0.0 and _route_distance_gap(distance, mill_distance) < 24.0:
				clear_for_landmark = true
			for landmark_index in [2, 6, 10, 18, 21, 25, 30, 33, 39, 44, 49]:
				var landmark_side_sign: float = 1.0 if int(landmark_index) % 2 == 0 else -1.0
				var landmark_distance: float = route_length * (float(landmark_index) + 0.38) / 52.0
				if side_sign == landmark_side_sign and _route_distance_gap(distance, landmark_distance) < 12.0:
					clear_for_landmark = true
			if clear_for_landmark:
				offset = 34.0 + float(variation % 5) * 1.8
			var position: Vector3 = point + side * side_sign * offset
			var tree_scale := 0.016 + float(posmod(i * 7 + variation, 5)) * 0.0013
			if _route_clearance(position) >= 8.5:
				_spawn_model(pine_scene, position, Vector3.ONE * (tree_scale + 0.0015), float(posmod(i * 47 + variation * 23, 360)) * PI / 180.0, "PineForest_%03d" % forest_piece_index)
				forest_piece_index += 1
			if not clear_for_landmark and i % 3 == 0:
				var cluster_shift := float((i % 3) - 1) * 4.2
				var undergrowth_position: Vector3 = point + tangent * cluster_shift + side * side_sign * (offset + 3.8)
				var undergrowth_scale := 0.0105 + float((i + variation) % 4) * 0.0012
				if _route_clearance(undergrowth_position) >= 8.0:
					_spawn_model(pine_scene, undergrowth_position, Vector3.ONE * undergrowth_scale, float(posmod(i * 29 + variation * 31, 360)) * PI / 180.0, "PineUnderstory_%03d" % forest_piece_index)
					forest_piece_index += 1
			if not clear_for_landmark and i % 4 == 2:
				var outer_shift := float((i % 4) - 1) * 5.0
				var outer_position: Vector3 = point + tangent * outer_shift + side * side_sign * (31.0 + float(variation % 4) * 2.2)
				var outer_scale := 0.014 + float((i + variation) % 4) * 0.0015
				if _route_clearance(outer_position) >= 8.0:
					_spawn_model(pine_scene, outer_position, Vector3.ONE * outer_scale, float(posmod(i * 61 + variation * 11, 360)) * PI / 180.0, "PineOuterForest_%03d" % forest_piece_index)
					forest_piece_index += 1

func _find_route_clear_position(route_point: Vector3, outward: Vector3, tangent: Vector3, initial_offset: float, required_clearance: float) -> Vector3:
	var along_shifts: Array[float] = [0.0, 8.0, -8.0, 16.0, -16.0]
	var outward_steps: Array[float] = [0.0, 8.0, 16.0, 24.0, 32.0, 42.0]
	for along_shift in along_shifts:
		for outward_step in outward_steps:
			var candidate: Vector3 = route_point + outward * (initial_offset + outward_step) + tangent * along_shift
			if _route_clearance(candidate) >= required_clearance:
				return candidate
	return route_point + outward * (initial_offset + outward_steps.back())

func _route_clearance(position: Vector3) -> float:
	var minimum_distance := INF
	for index in range(0, route_points.size(), 3):
		var route_point: Vector3 = route_points[index]
		minimum_distance = minf(minimum_distance, Vector2(position.x - route_point.x, position.z - route_point.z).length())
	return minimum_distance

func _route_distance_gap(first: float, second: float) -> float:
	var direct_gap := absf(first - second)
	return minf(direct_gap, route_length - direct_gap)

func _scatter_roadside_grass() -> void:
	var grass_scene := load("res://assets/props/grass.glb") as PackedScene
	if grass_scene == null:
		return
	for i in range(112):
		var grass_distance := route_length * (float(i) + 0.27) / 112.0
		var grass_point := _route_at(grass_distance)
		var grass_tangent := _tangent_at(grass_distance)
		var grass_side := Vector3(-grass_tangent.z, 0.0, grass_tangent.x).normalized()
		for side_sign in [-1.0, 1.0]:
			var variation: int = posmod(i * 7 + int(side_sign * 3.0), 7)
			var grass_offset := 5.7 + float(variation) * 0.62
			var grass_scale := 0.42 + float(posmod(i * 3 + variation, 7)) * 0.04
			var along_shift := float(posmod(i * 11 + variation * 3, 7) - 3) * 0.55
			var grass_pos: Vector3 = grass_point + grass_side * side_sign * grass_offset + grass_tangent * along_shift
			_spawn_model(grass_scene, grass_pos, Vector3.ONE * grass_scale, float((i * 47 + int(side_sign * 19.0)) % 360) * PI / 180.0, "RoadsideGrass")

func _spawn_trench_piece(scene: PackedScene, pos: Vector3, yaw: float, mesh_name: String, scale_factor: float, instance_name: String) -> void:
	var source := scene.instantiate() as Node3D
	if source == null:
		return
	world_root.add_child(source)
	var source_mesh := source.find_child(mesh_name, true, false) as MeshInstance3D
	if source_mesh == null:
		push_warning("Chapter 2 trench mesh not found: " + mesh_name)
		source.queue_free()
		return
	var source_basis: Basis = source_mesh.global_transform.basis
	var section_basis: Basis = Basis(Vector3.UP, yaw) * source_basis.orthonormalized().scaled(source_basis.get_scale() * scale_factor)
	var section := source_mesh.duplicate() as MeshInstance3D
	section.name = instance_name
	world_root.add_child(section)
	var local_bounds: AABB = section.get_aabb()
	var bounds_at_origin: AABB = Transform3D(section_basis, Vector3.ZERO) * local_bounds
	var ground_y: float = _terrain_height(pos.x, pos.z)
	var center: Vector3 = bounds_at_origin.get_center()
	var origin := Vector3(pos.x - center.x, ground_y - bounds_at_origin.position.y, pos.z - center.z)
	section.global_transform = Transform3D(section_basis, origin)
	source.queue_free()

func _spawn_cover_and_soldiers(pos: Vector3, soldier_scene: PackedScene, face_direction: Vector3, crouch: bool) -> void:
	if soldier_scene == null:
		return
	var soldier := soldier_scene.instantiate() as Node3D
	if soldier == null:
		return
	soldier.name = "CombatantInCover"
	soldier.add_to_group("chapter2_battle_soldier")
	soldier.scale = Vector3.ONE * 0.82
	var inward := face_direction.normalized()
	var tangent := Vector3(-inward.z, 0.0, inward.x)
	var soldier_offset := -inward * (0.85 if crouch else 0.45) + tangent * (1.85 if crouch else 0.0)
	var soldier_x: float = pos.x + soldier_offset.x
	var soldier_z: float = pos.z + soldier_offset.z
	var facing_yaw := atan2(inward.x, inward.z)
	soldier.rotation.y = facing_yaw
	soldier.set_meta("combat_base_yaw", facing_yaw)
	soldier.set_meta("combat_phase", float(world_root.get_child_count()) * 0.73)
	world_root.add_child(soldier)
	var local_bounds: AABB = game.call("get_visual_local_bounds", soldier)
	var basis: Basis = soldier.transform.basis
	var local_center: Vector3 = basis * local_bounds.get_center()
	var bottom_offset := INF
	for x in [local_bounds.position.x, local_bounds.end.x]:
		for y in [local_bounds.position.y, local_bounds.end.y]:
			for z in [local_bounds.position.z, local_bounds.end.z]:
				bottom_offset = minf(bottom_offset, (basis * Vector3(x, y, z)).y)
	var ground_y: float = _terrain_height(soldier_x, soldier_z)
	soldier.position = Vector3(soldier_x - local_center.x, ground_y - bottom_offset, soldier_z - local_center.z)
	soldier.set_meta("combat_base_y", soldier.position.y)
	var skeleton := soldier.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		if crouch:
			_pose_combatant_skeleton(skeleton)
		var is_soviet: bool = soldier_scene.resource_path.to_lower().contains("soviet")
		_attach_combatant_weapon(skeleton, is_soviet)
	else:
		_attach_static_combatant_weapon(soldier, inward, soldier_scene.resource_path.to_lower().contains("soviet"))

func _pose_combatant_skeleton(skeleton: Skeleton3D) -> void:
	var poses: Array[Dictionary] = [
		{"bone": "upperarm_l_09", "rotation": Vector3(0.0, 0.0, 0.80)},
		{"bone": "upperarm_r_030", "rotation": Vector3(0.0, 0.0, -1.25)},
		{"bone": "lowerarm_l_011", "rotation": Vector3(0.0, 0.0, 1.20)},
		{"bone": "lowerarm_r_032", "rotation": Vector3(0.0, 0.0, -1.30)},
		{"bone": "spine_01_03", "rotation": Vector3(0.04, 0.0, 0.0)},
		{"bone": "spine_02_04", "rotation": Vector3(0.03, 0.0, 0.0)}
	]
	for pose in poses:
		var bone_index: int = skeleton.find_bone(String(pose["bone"]))
		if bone_index >= 0:
			skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(pose["rotation"]))
	var spine_index: int = skeleton.find_bone("spine_01_03")
	if spine_index >= 0:
		skeleton.set_meta("combat_spine_index", spine_index)
		skeleton.set_meta("combat_spine_base", skeleton.get_bone_pose_rotation(spine_index))

func _attach_combatant_weapon(skeleton: Skeleton3D, is_soviet: bool) -> void:
	var weapon_scene: PackedScene = load("res://assets/weapons/ppsh-41.glb") as PackedScene if is_soviet else load("res://assets/props/ww2_german_mp40.glb") as PackedScene
	if weapon_scene == null:
		return
	var hand_bone := "hand_r_034" if is_soviet else "hand_r"
	var hand_index: int = skeleton.find_bone(hand_bone)
	if hand_index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandWeaponAttachment"
	attachment.bone_name = hand_bone
	skeleton.add_child(attachment)
	var weapon := weapon_scene.instantiate() as Node3D
	if weapon == null:
		return
	weapon.name = "CombatRifle"
	attachment.add_child(weapon)
	if is_soviet:
		# The soldier's imported skeleton is scaled to centimeters; compensate for
		# that parent scale so the attached PPSh stays close to its real size.
		weapon.scale = Vector3.ONE * 0.17
		weapon.rotation = Vector3(0.0, -PI * 0.5, -PI * 0.5)
		weapon.position = Vector3(0.0, 0.015, -0.035)
	else:
		weapon.scale = Vector3.ONE * 0.48
		weapon.rotation = Vector3(0.0, PI, 0.0)
		weapon.position = Vector3(0.0, 0.015, -0.02)

func _attach_static_combatant_weapon(soldier: Node3D, face_direction: Vector3, is_soviet: bool) -> void:
	var path := "res://assets/weapons/ppsh-41.glb" if is_soviet else "res://assets/props/ww2_german_mp40.glb"
	var weapon_scene := load(path) as PackedScene
	if weapon_scene == null:
		return
	var weapon := weapon_scene.instantiate() as Node3D
	if weapon == null:
		return
	weapon.name = "CombatRifle"
	world_root.add_child(weapon)
	if is_soviet:
		weapon.scale = Vector3.ONE * 0.0017
		weapon.rotation = Vector3(0.0, -PI * 0.5, -PI * 0.5)
	else:
		weapon.scale = Vector3.ONE * 0.48
		weapon.rotation.y = atan2(face_direction.x, face_direction.z) + PI * 0.5
	var lateral := Vector3(-face_direction.z, 0.0, face_direction.x) * 0.22
	var ground_y: float = _terrain_height(soldier.global_position.x, soldier.global_position.z)
	var weapon_center := Vector3(soldier.global_position.x, ground_y + 1.05, soldier.global_position.z) + face_direction.normalized() * 0.24 + lateral
	weapon.global_position = weapon_center

func _animate_battle_soldiers(delta: float) -> void:
	battle_idle_time += delta
	if world_root == null:
		return
	for soldier_node in get_tree().get_nodes_in_group("chapter2_battle_soldier"):
		var soldier := soldier_node as Node3D
		if soldier == null:
			continue
		var phase: float = float(soldier.get_meta("combat_phase", 0.0))
		soldier.rotation.y = float(soldier.get_meta("combat_base_yaw", soldier.rotation.y)) + sin(battle_idle_time * 0.48 + phase) * 0.025
		var skeleton := soldier.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton and skeleton.has_meta("combat_spine_index"):
			var spine_index: int = int(skeleton.get_meta("combat_spine_index"))
			var base_rotation: Quaternion = skeleton.get_meta("combat_spine_base")
			var breathing := Quaternion.from_euler(Vector3(sin(battle_idle_time * 1.7 + phase) * 0.018, 0.0, 0.0))
			skeleton.set_bone_pose_rotation(spine_index, base_rotation * breathing)

func _spawn_supply_group(scene: PackedScene, pos: Vector3, yaw: float) -> void:
	var source := scene.instantiate() as Node3D
	if source == null:
		return
	world_root.add_child(source)
	var entries: Array[Dictionary] = [
		{"source": "Cube_057", "name": "FieldCrate", "offset": Vector3(-1.1, 0.0, 0.0), "scale": 1.0},
		{"source": "Cube_075", "name": "TallSupplyCrate", "offset": Vector3(0.6, 0.0, 0.4), "scale": 0.9},
		{"source": "palisada_002", "name": "StoredTimber", "offset": Vector3(1.15, 0.0, 1.3), "scale": 0.55}
	]
	for entry in entries:
		var source_name: String = entry["source"]
		var part := source.find_child(source_name, true, false) as Node3D
		if part == null:
			continue
		part.reparent(world_root, true)
		part.name = String(entry["name"])
		part.scale = Vector3.ONE * float(entry["scale"])
		part.rotation.y += yaw
		var local_bounds: AABB = game.call("get_visual_local_bounds", part)
		var basis := part.transform.basis
		var local_center := local_bounds.get_center()
		var center_offset := basis * local_center
		var bottom_offset := INF
		for x in [local_bounds.position.x, local_bounds.end.x]:
			for y in [local_bounds.position.y, local_bounds.end.y]:
				for z in [local_bounds.position.z, local_bounds.end.z]:
					bottom_offset = minf(bottom_offset, (basis * Vector3(x, y, z)).y)
		var object_offset: Vector3 = entry["offset"]
		var local_offset: Vector3 = basis * object_offset
		var target: Vector3 = pos + local_offset
		part.position = Vector3(target.x - center_offset.x, _terrain_height(target.x, target.z) - bottom_offset, target.z - center_offset.z)
	source.queue_free()

func _spawn_model(scene: PackedScene, pos: Vector3, model_scale: Vector3, yaw: float, label: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	holder.rotation.y = yaw
	var model := scene.instantiate() as Node3D
	model.scale = model_scale
	holder.add_child(model)
	world_root.add_child(holder)
	var local_bounds: AABB = game.call("get_visual_local_bounds", model)
	var transformed_basis: Basis = holder.global_transform.basis * model.transform.basis
	var visual_center: Vector3 = transformed_basis * local_bounds.get_center()
	var visual_bottom := INF
	for x in [local_bounds.position.x, local_bounds.end.x]:
		for y in [local_bounds.position.y, local_bounds.end.y]:
			for z in [local_bounds.position.z, local_bounds.end.z]:
				visual_bottom = minf(visual_bottom, (transformed_basis * Vector3(x, y, z)).y)
	var ground_y: float = _terrain_height(pos.x, pos.z)
	holder.position = Vector3(pos.x - visual_center.x, ground_y - visual_bottom, pos.z - visual_center.z)
	return holder

func _build_tank() -> void:
	tank = Node3D.new()
	tank.name = "SingleActivePzIII"
	world_root.add_child(tank)
	var visual_pack := load("res://assets/vehicles/panzer_3_ausf_j_tank_model.glb") as PackedScene
	if visual_pack:
		tank_visual = visual_pack.instantiate() as Node3D
		tank_visual.name = "PzIIIVisual"
		# This asset is authored in centimeters and imports at 100x unit scale.
		# Normalize it to roughly 5.7 m long so the player can see and hit it.
		# The imported Pz III faces local -X. Turn its nose onto the route's
		# forward direction; the tank root follows the route tangent in _update_chase.
		tank_visual.rotation.y = -PI * 0.5
		tank_visual.scale = Vector3.ONE * 0.01
		tank.add_child(tank_visual)
		turret = _find_named_node(tank_visual, ["turret", "turm", "turret_base"])
	_add_hitbox("HullHitbox", "hull", Vector3(0.0, 1.35, 0.0), Vector3(1.7, 1.35, 3.45))
	_add_hitbox("LeftTrackHitbox", "track", Vector3(-1.27, 0.56, 0.0), Vector3(0.58, 0.9, 4.6))
	_add_hitbox("RightTrackHitbox", "track", Vector3(1.27, 0.56, 0.0), Vector3(0.58, 0.9, 4.6))

func _find_named_node(root: Node, hints: Array[String]) -> Node3D:
	for child in root.get_children():
		if child is Node3D:
			var name_lower := String(child.name).to_lower()
			for hint in hints:
				if hint in name_lower:
					return child as Node3D
			var nested := _find_named_node(child, hints)
			if nested:
				return nested
	return null

func _add_hitbox(label: String, kind: String, center: Vector3, dimensions: Vector3) -> void:
	var area := Area3D.new()
	area.name = label
	area.collision_layer = 4
	area.collision_mask = 0
	area.set_script(HITBOX_SCRIPT)
	area.set("controller", self)
	area.set("zone_kind", kind)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	area.position = center
	area.add_child(collider)
	tank.add_child(area)

func _build_planes() -> void:
	var plane_paths := [
		"res://assets/vehicles/aviation/messerschmitt_bf_110.glb",
		"res://assets/vehicles/aviation/junkers_ju_87_stuka.glb",
		"res://assets/vehicles/aviation/dornier_do_335_pfeil.glb"
	]
	for i in range(plane_paths.size()):
		var pack := load(plane_paths[i]) as PackedScene
		if pack == null:
			continue
		var plane := Node3D.new()
		plane.name = "AmbientAircraft_%d" % i
		var model := pack.instantiate() as Node3D
		model.scale = Vector3.ONE * 0.82
		plane.add_child(model)
		world_root.add_child(plane)
		plane_nodes.append(plane)
		var animation_player := _find_animation_player(model)
		plane_animations.append(animation_player)
		if i == 1 and animation_player and animation_player.has_animation("Take 01"):
			var stuka_animation := animation_player.get_animation("Take 01")
			stuka_animation.loop_mode = Animation.LOOP_LINEAR
			animation_player.speed_scale = 18.0
			animation_player.play("Take 01")

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _build_audio() -> void:
	truck_engine = _loop_3d(truck, "ZiS5Engine", "res://assets/audio/engine_zis_5.mp3", -8.0, 150.0, 18.0)
	if truck_engine == null:
		truck_engine = _loop_3d(truck, "ZiS5Drive", "res://assets/audio/zis_5_drive.mp3", -8.0, 150.0, 18.0)
	tank_tracks = _loop_3d(tank, "PzIIITreads", "res://assets/audio/tracks_rattle_slow_01.mp3", -8.0, 210.0, 24.0)
	truck_impact = _one_shot_3d(truck, "TruckSuspension", "res://assets/audio/loud-metallic-thud.mp3", -4.0, 100.0, 12.0)
	hull_impact = _one_shot_3d(tank, "HullImpact", "res://assets/audio/bullet_hits_the_tank.mp3", -4.0, 140.0, 18.0)
	track_impact = _one_shot_3d(tank, "TrackImpact", "res://assets/audio/metallicheskiy-stuk-silnyiy.mp3", -3.0, 140.0, 18.0)
	plane_audio = _one_shot_3d(world_root, "AircraftFlyby", "res://assets/audio/the-sound-of-a-flying-fighter.mp3", -3.5, 340.0, 42.0)
	stuka_siren = _one_shot_3d(world_root, "Ju87Siren", "res://assets/audio/stuka-airplane.mp3", -7.0, 280.0, 34.0)
	tank_cannon = _one_shot_3d(tank, "PzIIICannon", "res://assets/audio/z_uko_ye-effekty-vystrel-tanka.mp3", -5.0, 190.0, 22.0)
	battle_machinegun = _one_shot_3d(world_root, "DistantBattleMachinegun", "res://assets/audio/sound_of_machinegun.mp3", -17.0, 250.0, 13.0)
	battle_rifle = _one_shot_3d(world_root, "DistantBattleRifle", "res://assets/audio/single-shot-bursts-at-the-shooting-range.mp3", -19.0, 210.0, 10.0)
	music_player = AudioStreamPlayer.new()
	music_player.name = "Chapter2ChaseMusic"
	var music: AudioStream
	var music_path := "res://assets/audio/music_for_chapter_2_chase.mp3"
	if ResourceLoader.exists(music_path):
		music = load(music_path) as AudioStream
	if music:
		if music is AudioStreamMP3:
			(music as AudioStreamMP3).loop = true
		music_player.stream = music
		music_player.volume_db = -12.0
		game.add_child(music_player)
	else:
		push_warning("Chapter 2 chase music is missing: %s" % music_path)

func _loop_3d(parent: Node, label: String, path: String, volume: float, max_distance: float, unit_size: float) -> AudioStreamPlayer3D:
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var audio := AudioStreamPlayer3D.new()
	audio.name = label
	audio.stream = stream
	audio.volume_db = volume
	audio.max_distance = max_distance
	audio.unit_size = unit_size
	audio.max_polyphony = 1
	parent.add_child(audio)
	return audio

func _one_shot_3d(parent: Node, label: String, path: String, volume: float, max_distance: float, unit_size: float) -> AudioStreamPlayer3D:
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	var audio := AudioStreamPlayer3D.new()
	audio.name = label
	audio.stream = stream
	audio.volume_db = volume
	audio.max_distance = max_distance
	audio.unit_size = unit_size
	audio.max_polyphony = 4
	parent.add_child(audio)
	return audio

func _build_hud() -> void:
	var canvas := game.get_node_or_null("UI") as CanvasLayer
	if canvas == null:
		return
	chase_label = Label.new()
	chase_label.name = "Chapter2ChaseStatus"
	chase_label.position = Vector2(28, 102)
	chase_label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(chase_label)
	gap_bar = ProgressBar.new()
	gap_bar.name = "TankDistance"
	gap_bar.position = Vector2(28, 138)
	gap_bar.size = Vector2(280, 18)
	gap_bar.min_value = LOSE_GAP
	gap_bar.max_value = WIN_GAP
	gap_bar.value = chase_distance
	gap_bar.show_percentage = false
	canvas.add_child(gap_bar)
	var hint := Label.new()
	hint.name = "Chapter2CombatHint"
	hint.text = "ОТСТРЕЛИВАЙСЯ • СЛЕДИ ЗА ОТРЫВОМ"
	hint.position = Vector2(28, 164)
	hint.add_theme_font_size_override("font_size", 16)
	canvas.add_child(hint)
	if game.ammo_label:
		game.ammo_label.position = Vector2(1030.0, 196.0)
	outcome_layer = Control.new()
	outcome_layer.name = "Chapter2ResultOverlay"
	outcome_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome_layer.visible = false
	canvas.add_child(outcome_layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome_layer.add_child(black)
	outcome_label = Label.new()
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	outcome_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome_label.add_theme_font_size_override("font_size", 64)
	outcome_layer.add_child(outcome_label)
	intro_card = TextureRect.new()
	intro_card.name = "TruckBoardingCutscene"
	intro_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	intro_card.visible = false
	canvas.add_child(intro_card)

func _read_cutscene_frames() -> void:
	intro_frames.clear()
	var folder := "res://assets/cutscenes/chapter_01/dmitry_gets_into_truck_frames"
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		var lower_name := file_name.to_lower()
		if not lower_name.ends_with(".png") and not lower_name.ends_with(".jpg") and not lower_name.ends_with(".jpeg"):
			continue
		var frame := ResourceLoader.load(folder + "/" + file_name) as Texture2D
		if frame:
			intro_frames.append(frame)

func _play_intro_then_chase(skip_intro: bool) -> void:
	game.state = "transition"
	cutscene_active = true
	_read_cutscene_frames()
	var intro_audio_stream: AudioStream
	if ResourceLoader.exists("res://assets/cutscenes/chapter_01/dmitry_gets_into_truck_audio.wav"):
		intro_audio_stream = load("res://assets/cutscenes/chapter_01/dmitry_gets_into_truck_audio.wav") as AudioStream
	if intro_audio_stream:
		intro_audio = AudioStreamPlayer.new()
		intro_audio.name = "DmitryBoardingCutsceneAudio"
		intro_audio.stream = intro_audio_stream
		intro_audio.volume_db = -4.0
		game.add_child(intro_audio)
	if skip_intro or intro_frames.is_empty():
		cutscene_active = false
		_begin_chase()
		return
	if intro_card:
		intro_card.visible = true
		intro_card.texture = intro_frames[0]
	intro_frame_index = 0
	intro_frame_timer = 0.0
	if intro_audio:
		intro_audio.play()

func _process(delta: float) -> void:
	_animate_battle_soldiers(delta)
	if cutscene_active:
		if intro_frames.size() > 0:
			intro_frame_timer += delta
			var target_index := mini(intro_frames.size() - 1, int(intro_frame_timer * 12.0))
			if target_index != intro_frame_index:
				intro_frame_index = target_index
				if intro_card:
					intro_card.texture = intro_frames[intro_frame_index]
			if intro_frame_timer >= float(intro_frames.size()) / 12.0:
				if intro_card:
					intro_card.visible = false
				if intro_audio and intro_audio.playing:
					intro_audio.stop()
				cutscene_active = false
				_begin_chase()
		return
	if not active:
		return
	var sim_delta := delta * test_speed
	elapsed += sim_delta
	var curve_load := absf(_turn_at(truck_distance))
	var throttle_wave := 0.035 * sin(elapsed * 0.48) + 0.018 * sin(elapsed * 0.91 + 0.7)
	var corner_braking := minf(0.09, curve_load * 0.32)
	current_truck_speed = TRUCK_SPEED * (1.0 + throttle_wave - corner_braking)
	truck_distance += current_truck_speed * sim_delta
	if test_scenario != "":
		_run_test_scenario(sim_delta)
	_update_chase(sim_delta)
	_update_planes(sim_delta)
	_update_audio_and_effects(sim_delta)
	_update_hud()
	if chase_distance <= LOSE_GAP:
		_finish(false)
	elif chase_distance >= WIN_GAP:
		_finish(true)

func _begin_chase() -> void:
	if truck == null:
		return
	truck_distance = 0.0
	chase_distance = INITIAL_GAP
	current_tank_forward_speed = TRUCK_SPEED + TANK_BASE_CLOSING_RATE
	track_condition = 0.0
	hull_slow_timer = 0.0
	var truck_sample := _route_at(truck_distance)
	truck.global_position = truck_sample
	truck.rotation = Vector3.ZERO
	player.position = truck_sample + Vector3.UP * 2.4 - _tangent_at(truck_distance) * 3.15
	player.pitch = 0.0
	player.head.rotation = Vector3.ZERO
	var player_target := _route_at(truck_distance - chase_distance) + Vector3.UP * 1.35
	var camera_position: Vector3 = player.position + Vector3.UP * (player.head.position.y + player.camera.position.y)
	var initial_aim: Vector3 = (player_target - camera_position).normalized()
	player.rotation.y = atan2(-initial_aim.x, -initial_aim.z)
	player.pitch = asin(clampf(initial_aim.y, -0.98, 0.98))
	player.head.rotation.x = player.pitch
	player_base_yaw = player.rotation.y
	player_base_pitch = player.pitch
	player.velocity = Vector3.ZERO
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.collision_layer = 0
	player.collision_mask = 0
	if not player.can_shoot:
		player.give_ppsh()
	var definition := load("res://resources/weapons/ppsh_definition.tres") as WeaponDefinition
	if definition:
		player.weapon_ammo[definition.weapon_id] = definition.magazine_capacity
		player.weapon_reserve_ammo[definition.weapon_id] = 700
		player.equip_weapon(definition)
	player.visible = true
	game.menu_open = false
	game.state = "chase"
	game.objective.text = "ГЛАВА 2  |  Уходи от Pz III"
	game.message.text = "ОТСТРЕЛИВАЙСЯ. НЕ ДАЙ ТАНКУ ПРИБЛИЗИТЬСЯ."
	game.message_time = 6.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if truck_engine:
		truck_engine.play()
	if tank_tracks:
		tank_tracks.play()
	if music_player and music_player.stream:
		music_player.play()
	tank_fire_timer = 7.0
	flyby_timer = 4.0
	stuka_siren_cooldown = 0.6
	active = true

func _run_test_scenario(delta: float) -> void:
	if test_scenario == "none":
		return
	if test_scenario == "hull" and elapsed > 34.0:
		return
	test_shot_timer -= delta
	var interval := 0.17 if test_scenario == "tracks" else 0.30
	if test_shot_timer <= 0.0:
		test_shot_timer = interval
		register_hit("track" if test_scenario == "tracks" else "hull", Vector3.ZERO)

func _update_chase(delta: float) -> void:
	var pos := _route_at(truck_distance)
	var tangent := _tangent_at(truck_distance)
	var lateral_accel := sin(elapsed * 0.86) * 0.68
	var rough_patch := _roughness_at(truck_distance)
	bump_cooldown = maxf(0.0, bump_cooldown - delta)
	landing_impact_cooldown = maxf(0.0, landing_impact_cooldown - delta)
	if rough_patch > 0.72 and bump_cooldown <= 0.0:
		suspension_velocity += 4.4 * rough_patch
		bump_cooldown = 5.4
		if truck_impact:
			_play_one_shot(truck_impact)
	var previous_suspension_offset := suspension_offset
	suspension_velocity -= suspension_velocity * 2.3 * delta
	suspension_velocity -= 7.2 * suspension_offset * delta
	suspension_offset += suspension_velocity * delta
	suspension_offset = clampf(suspension_offset, -0.42, 1.15)
	if previous_suspension_offset > 0.22 and suspension_offset <= 0.22 and suspension_velocity < -0.8 and landing_impact_cooldown <= 0.0:
		if truck_impact:
			_play_one_shot(truck_impact)
		landing_impact_cooldown = 1.0
	var bob := 0.09 * sin(truck_distance * 0.42) + 0.05 * sin(truck_distance * 0.81 + 0.8)
	truck.global_position = pos + Vector3.UP * (suspension_offset + bob)
	var yaw := atan2(-tangent.x, -tangent.z)
	var turn := _turn_at(truck_distance)
	var roll := clampf(-turn * 0.14 + lateral_accel * 0.055, -0.20, 0.20)
	var pitch := clampf(-suspension_velocity * 0.055 + 0.022 * sin(elapsed * 1.7), -0.16, 0.16)
	truck.rotation = Vector3(pitch, yaw, roll)
	if truck_visual:
		truck_visual.position.y = 0.04 * sin(elapsed * 8.0)
		truck_visual.rotation_degrees.x = sin(elapsed * 5.6) * 1.0
		truck_visual.rotation_degrees.z = sin(elapsed * 4.1) * 1.4
	if tank:
		# Tracks take a short-lived speed penalty. The Pz's forward speed eases
		# back up after fire stops, so it never permanently falls behind.
		hull_slow_timer = maxf(0.0, hull_slow_timer - delta)
		track_condition = maxf(0.0, track_condition - delta * TRACK_CONDITION_RECOVERY_RATE)
		var track_braking := track_condition * 0.034
		var hull_braking := 0.55 if hull_slow_timer > 0.0 else 0.0
		var target_tank_speed := current_truck_speed + TANK_BASE_CLOSING_RATE - track_braking - hull_braking
		target_tank_speed = clampf(target_tank_speed, TRUCK_SPEED * 0.68, TRUCK_SPEED + TANK_BASE_CLOSING_RATE)
		current_tank_forward_speed = move_toward(current_tank_forward_speed, target_tank_speed, 4.5 * delta)
		chase_distance = clampf(chase_distance + (current_truck_speed - current_tank_forward_speed) * delta, LOSE_GAP, WIN_GAP)
		var yaw_offset := wrapf(player.rotation.y - player_base_yaw, -PI, PI)
		var pitch_offset: float = player.pitch - player_base_pitch
		var tank_progress := truck_distance - chase_distance
		var tank_position := _route_at(tank_progress)
		var tank_tangent := (_route_at(tank_progress + current_tank_forward_speed * 0.12) - _route_at(tank_progress)).normalized()
		var tank_roughness := _roughness_at(tank_progress)
		tank_bump_cooldown = maxf(0.0, tank_bump_cooldown - delta)
		if tank_roughness > 0.72 and tank_bump_cooldown <= 0.0:
			tank_suspension_velocity += 2.5 * tank_roughness
			tank_bump_cooldown = 5.4
		tank_suspension_velocity -= tank_suspension_velocity * 2.5 * delta
		tank_suspension_velocity -= 8.0 * tank_suspension_offset * delta
		tank_suspension_offset = clampf(tank_suspension_offset + tank_suspension_velocity * delta, -0.28, 0.85)
		var tank_bump := tank_suspension_offset + 0.08 * sin(elapsed * 6.5 + 1.0) + maxf(0.0, sin(tank_progress * 0.12 + 0.7)) * 0.10
		tank.global_position = tank_position + Vector3.UP * tank_bump
		tank.rotation = Vector3(-tank_suspension_velocity * 0.028 + 0.012 * sin(elapsed * 3.0), atan2(-tank_tangent.x, -tank_tangent.z), 0.025 * sin(elapsed * 4.0))
		if turret:
			turret.rotation.y = sin(elapsed * 0.28) * 0.05
		var player_target_position := truck.global_position + Vector3.UP * 2.4 - tangent * 3.15
		player.global_position = player_target_position
		# Follow the Pz III through bends and across the loop crossing while
		# keeping mouse look as an offset, so the target stays in the playable view.
		var camera_position: Vector3 = player.global_position + Vector3.UP * (player.head.position.y + player.camera.position.y)
		var target_vector := tank_position + Vector3.UP * 1.2 - camera_position
		var horizontal_distance := Vector2(target_vector.x, target_vector.z).length()
		var new_base_yaw := atan2(-target_vector.x, -target_vector.z)
		var new_base_pitch := atan2(target_vector.y, horizontal_distance)
		player.rotation.y = new_base_yaw + yaw_offset
		player_base_yaw = new_base_yaw
		player.pitch = clampf(new_base_pitch + pitch_offset, -1.45, 1.45)
		player_base_pitch = new_base_pitch
		player.head.rotation.x = player.pitch + player.recoil_offset
		# Independent turret fire and distant air traffic provide atmosphere only.
		tank_fire_timer -= delta
		if tank_fire_timer <= 0.0:
			tank_fire_timer = randf_range(8.0, 12.0)
			_play_one_shot(tank_cannon)
		battle_ambience_timer -= delta
		if battle_ambience_timer <= 0.0:
			battle_ambience_timer = randf_range(8.0, 14.0)
			var ambience_distance := truck_distance + randf_range(-135.0, 135.0)
			var ambience_route := _route_at(ambience_distance)
			var ambience_tangent := _tangent_at(ambience_distance)
			var ambience_side := Vector3(-ambience_tangent.z, 0.0, ambience_tangent.x).normalized()
			var ambience_position := ambience_route + ambience_side * randf_range(-52.0, 52.0) + Vector3.UP * 0.8
			var ambience_player: AudioStreamPlayer3D = battle_machinegun if randi() % 2 == 0 else battle_rifle
			if ambience_player:
				ambience_player.global_position = ambience_position
				_play_one_shot(ambience_player)

func _update_planes(delta: float) -> void:
	flyby_timer -= delta
	stuka_siren_cooldown = maxf(0.0, stuka_siren_cooldown - delta)
	var phase_rates: Array[float] = [0.19, 0.24, 0.21]
	var phase_offsets: Array[float] = [2.2, 0.0, 4.15]
	var forward_reaches: Array[float] = [145.0, 92.0, 122.0]
	var side_reaches: Array[float] = [62.0, 14.0, 76.0]
	for i in range(plane_nodes.size()):
		var phase := elapsed * phase_rates[i] + phase_offsets[i]
		var route_progress := truck_distance + forward_reaches[i] * cos(phase)
		var route_tangent := _tangent_at(route_progress)
		var route_side := Vector3(-route_tangent.z, 0.0, route_tangent.x).normalized()
		var position := _route_at(route_progress) + route_side * side_reaches[i] * sin(phase)
		var height_above_ground := 17.0 + 8.0 * absf(cos(phase)) if i == 1 else 49.0 + 13.0 * sin(phase * 1.35 + float(i))
		position.y = _terrain_height(position.x, position.z) + height_above_ground
		var next_phase := phase + phase_rates[i] * 0.12
		var next_progress := truck_distance + current_truck_speed * 0.12 + forward_reaches[i] * cos(next_phase)
		var next_tangent := _tangent_at(next_progress)
		var next_side := Vector3(-next_tangent.z, 0.0, next_tangent.x).normalized()
		var next_position := _route_at(next_progress) + next_side * side_reaches[i] * sin(next_phase)
		var next_height_above_ground := 17.0 + 8.0 * absf(cos(next_phase)) if i == 1 else 49.0 + 13.0 * sin(next_phase * 1.35 + float(i))
		next_position.y = _terrain_height(next_position.x, next_position.z) + next_height_above_ground
		var flight_direction := (next_position - position).normalized()
		plane_nodes[i].global_position = position
		plane_nodes[i].look_at(position + flight_direction, Vector3.UP)
		var bank_angle := sin(phase * 1.8 + float(i)) * (0.48 if i == 1 else 0.28)
		plane_nodes[i].rotate_object_local(Vector3.FORWARD, bank_angle)
		if i == 1 and stuka_siren and stuka_siren_cooldown <= 0.0:
			var player_distance := plane_nodes[i].global_position.distance_to(player.global_position)
			if player_distance < 62.0:
				stuka_siren.global_position = plane_nodes[i].global_position
				stuka_siren.volume_db = lerpf(-11.0, -5.0, clampf(inverse_lerp(62.0, 20.0, player_distance), 0.0, 1.0))
				_play_one_shot(stuka_siren)
				stuka_siren_cooldown = 23.0
	if flyby_timer <= 0.0 and not plane_nodes.is_empty():
		flyby_timer = randf_range(10.0, 15.0)
		var flyby_index := 0
		var closest_distance := INF
		for i in range(plane_nodes.size()):
			var distance_to_player := plane_nodes[i].global_position.distance_to(player.global_position)
			if distance_to_player < closest_distance:
				closest_distance = distance_to_player
				flyby_index = i
		if plane_audio and not plane_audio.playing:
			plane_audio.global_position = plane_nodes[flyby_index].global_position
			plane_audio.volume_db = lerpf(-10.0, -2.5, clampf(inverse_lerp(210.0, 30.0, closest_distance), 0.0, 1.0))
			plane_audio.play()

func _update_audio_and_effects(delta: float) -> void:
	if truck_engine:
		var throttle_pitch: float = current_truck_speed / TRUCK_SPEED
		var engine_load := minf(0.18, absf(suspension_velocity) * 0.04 + absf(_turn_at(truck_distance)) * 0.16)
		truck_engine.pitch_scale = 0.84 + throttle_pitch * 0.16 + engine_load
	if tank_tracks:
		tank_tracks.pitch_scale = clampf(current_tank_forward_speed / (TRUCK_SPEED + TANK_BASE_CLOSING_RATE), 0.70, 1.0)
		tank_tracks.volume_db = lerpf(-8.0, -12.0, clampf(track_condition / 100.0, 0.0, 1.0))
	if music_player:
		var danger: float = clampf(inverse_lerp(WIN_GAP, LOSE_GAP, chase_distance), 0.0, 1.0)
		music_player.volume_db = lerpf(-12.0, -6.0, danger)
	for effect in hit_effects:
		if is_instance_valid(effect):
			effect.scale *= 1.0 + delta * 2.8
			var material := effect.material_override as StandardMaterial3D
			if material:
				material.albedo_color.a = maxf(0.0, material.albedo_color.a - delta * 2.4)
			if material == null or material.albedo_color.a <= 0.0:
				effect.queue_free()
	hit_effects = hit_effects.filter(func(effect): return is_instance_valid(effect))

func _update_hud() -> void:
	if chase_label:
		chase_label.text = "ОТРЫВ ОТ Pz III: %d м" % roundi(chase_distance)
	if gap_bar:
		gap_bar.value = chase_distance
	if game and game.ammo_label and player.current_weapon_definition:
		game.ammo_label.text = "ППШ  %02d / %02d" % [player.ammo, player.reserve_ammo]

func register_hit(kind: String, hit_position: Vector3) -> void:
	if not active:
		return
	if kind == "track":
		track_condition = minf(100.0, track_condition + 25.0)
		if track_impact:
			_play_one_shot(track_impact)
		_spawn_hit_spark(hit_position, true)
	else:
		hull_slow_timer = maxf(hull_slow_timer, 1.5)
		if hull_impact:
			_play_one_shot(hull_impact)
		_spawn_hit_spark(hit_position, false)

func _spawn_hit_spark(at: Vector3, track_hit: bool) -> void:
	var spark := MeshInstance3D.new()
	spark.name = "TrackSparks" if track_hit else "HullImpactDust"
	var mesh := SphereMesh.new()
	mesh.radius = 0.12 if track_hit else 0.09
	mesh.height = mesh.radius * 2.0
	spark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.58, 0.19, 0.95) if track_hit else Color(0.7, 0.64, 0.48, 0.85)
	material.emission_enabled = track_hit
	material.emission = Color(1.0, 0.3, 0.07)
	material.emission_energy_multiplier = 2.0
	spark.material_override = material
	world_root.add_child(spark)
	spark.global_position = at if at != Vector3.ZERO else tank.global_position + Vector3.UP
	hit_effects.append(spark)

func _play_one_shot(audio: AudioStreamPlayer3D) -> void:
	if audio == null or audio.stream == null:
		return
	if audio.playing:
		audio.stop()
	audio.play()

func _route_at(distance: float) -> Vector3:
	if route_points.is_empty() or route_length <= 0.0:
		return Vector3.ZERO
	var wrapped := fposmod(distance, route_length)
	var lo := 0
	var hi := route_points.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if route_cumulative[mid + 1] < wrapped:
			lo = mid + 1
		else:
			hi = mid
	var index := mini(lo, route_points.size() - 1)
	var segment_len := maxf(0.001, route_cumulative[index + 1] - route_cumulative[index])
	var weight := (wrapped - route_cumulative[index]) / segment_len
	return route_points[index].lerp(route_points[(index + 1) % route_points.size()], weight)

func _tangent_at(distance: float) -> Vector3:
	return (_route_at(distance + 1.5) - _route_at(distance - 1.5)).normalized()

func _roughness_at(distance: float) -> float:
	var value := 0.5 + 0.5 * sin(distance * 0.078) * cos(distance * 0.051)
	for landmark in [92.0, 244.0, 471.0, 686.0, 924.0, 1172.0]:
		value = maxf(value, exp(-pow((fposmod(distance, route_length) - landmark) / 4.2, 2.0)))
	return value

func _turn_at(distance: float) -> float:
	var before := _tangent_at(distance - 2.0)
	var after := _tangent_at(distance + 2.0)
	return wrapf(atan2(after.x, -after.z) - atan2(before.x, -before.z), -PI, PI)

func _finish(won: bool) -> void:
	if not active:
		return
	active = false
	result = "victory" if won else "defeat"
	if test_scenario != "":
		print("CHAPTER2_TEST_RESULT scenario=%s result=%s gap=%.1f track_condition=%.1f" % [test_scenario, result, chase_distance, track_condition])
	game.state = "chase_%s" % result
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if truck_engine:
		truck_engine.stop()
	if tank_tracks:
		tank_tracks.stop()
	if plane_audio:
		plane_audio.stop()
	if stuka_siren:
		stuka_siren.stop()
	if music_player:
		music_player.stop()
	if outcome_layer:
		outcome_layer.visible = true
	if outcome_label:
		outcome_label.text = "ПОБЕДА" if won else "ПОРАЖЕНИЕ"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

