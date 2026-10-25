extends Node3D

const COMBATANT_SCRIPT: Script = preload("res://scripts/Chapter3Combatant.gd")
const TANK_SCRIPT: Script = preload("res://scripts/Chapter3Tank.gd")
const PROJECTILE_SCRIPT: Script = preload("res://scripts/Chapter3Projectile.gd")

const LINE_Z: Array[float] = [0.0, 42.0, 84.0]
const MAX_ACTIVE_COMBATANTS: int = 42
const DEFAULT_LINE_SECONDS: float = 76.0
const FAST_TEST_SECONDS: float = 8.0
const FAST_TEST_STUKA_SECONDS: float = 4.0

var game: Node
var player: CharacterBody3D
var world_root: Node3D
var ui_layer: CanvasLayer
var objective_label: Label
var phase_label: Label
var prompt_label: Label
var message_label: Label
var reticle_label: Label
var result_panel: ColorRect
var result_label: Label
var ammo_label: Label
var active: bool = false
var test_scenario: String = ""
var stage: StringName = &"line1"
var stage_elapsed: float = 0.0
var stage_player_kills: int = 0
var total_player_kills: int = 0
var wave_timer: float = 0.0
var artillery_timer: float = 9.0
var stuka_timer: float = 48.0
var stuka_active: bool = false
var stuka_elapsed: float = 0.0
var stuka_target_z: float = 0.0
var pending_bomb: bool = false
var test_elapsed: float = 0.0
var test_capture_done: bool = false
var reinforcements_called: bool = false
var radio_used: bool = false
var radio_area: Area3D
var bunker_area: Area3D
var shelters: Array[Area3D] = []
var tanks: Array[Node3D] = []
var artillery_positions: Array[Node3D] = []
var active_gun_index: int = -1
var gun_shells: Array[int] = [5, 5, 4]
var gun_stations: Array[Area3D] = []
var pickup_areas: Array[Area3D] = []
var sound_pool: Array[AudioStreamPlayer3D] = []
var world_music: AudioStreamPlayer
var sound_cooldowns: Dictionary = {}
var recent_spawns: Array[Vector3] = []
var german_spawn_count: int = 0
var soviet_spawn_count: int = 0
var line_one_ptrd_spawned: bool = false
var active_decals: Array[Node3D] = []
var firing_tracers: Array[MeshInstance3D] = []

func begin(game_node: Node, scenario: String = "") -> void:
	game = game_node
	player = game.get("player") as CharacterBody3D
	test_scenario = scenario
	active = true
	stage = &"line1"
	stage_elapsed = 0.0
	stage_player_kills = 0
	total_player_kills = 0
	add_to_group("chapter3_controller")
	game.call("clear_previous_world_for_chapter3")
	_build_world()
	_build_hud()
	_build_sound_pool()
	player.position = Vector3(0.0, 0.9, 2.0)
	player.velocity = Vector3.ZERO
	player.collision_layer = 1
	player.collision_mask = 1
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.health = 100.0
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.call("begin_chapter3")
	game.state = "chapter3"
	if world_music != null:
		world_music.play()
	_set_objective("Первая линия: удерживай позицию. Поддерживай бойцов РККА.")
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("CHAPTER3_GERMAN_INFANTRY rigs=%s animation=procedural" % str(COMBATANT_SCRIPT.GERMAN_INFANTRY_RIGS))
	print("CHAPTER3_STARTED scenario=%s" % test_scenario)

func _build_world() -> void:
	world_root = Node3D.new()
	world_root.name = "Chapter3Battlefield"
	add_child(world_root)
	_build_environment()
	_build_ground()
	_build_defense_line(0, LINE_Z[0])
	_build_approach_pockets()
	_build_defense_line(1, LINE_Z[1])
	_build_defense_line(2, LINE_Z[2])
	_build_bunker()
	_build_flanks()
	_build_artillery()
	_build_gun_station(0, Vector3(-8.0, 0.0, 5.5))
	_build_gun_station(1, Vector3(15.5, 0.0, 47.0))
	_build_gun_station(2, Vector3(-13.5, 0.0, 88.0))
	_build_radio()
	_build_stuka()
	_build_tanks()
	_spawn_initial_line(0)
	_create_supply_crate(Vector3(3.0, 0.0, 12.0), &"ppsh_ammo", 35, "Ящик ППШ")
	_create_supply_crate(Vector3(-5.0, 0.0, 49.0), &"ptrd_ammo", 1, "Снаряд ПТРД")
	_build_battle_bounds()
	if test_scenario == "fast" or test_scenario == "smoke":
		stuka_timer = FAST_TEST_STUKA_SECONDS

func _build_environment() -> void:
	var environment_node := game.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node != null:
		var environment := Environment.new()
		environment.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("#566879")
		sky_material.sky_horizon_color = Color("#a5a08c")
		sky_material.ground_bottom_color = Color("#4c5146")
		sky_material.ground_horizon_color = Color("#8f8c78")
		sky.sky_material = sky_material
		environment.sky = sky
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("#788271")
		environment.ambient_light_energy = 0.72
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.fog_enabled = true
		environment.fog_light_color = Color("#9ba398")
		environment.fog_density = 0.0017
		environment_node.environment = environment
	var sun := game.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = Vector3(-42.0, -36.0, 4.0)
		sun.light_color = Color("#ffe6c5")
		sun.light_energy = 1.15
		sun.shadow_enabled = true

func _build_ground() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "BattlefieldGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(230.0, 270.0)
	terrain.mesh = plane
	terrain.position = Vector3(0.0, 0.0, 25.0)
	var ground_material := ShaderMaterial.new()
	var ground_shader := Shader.new()
	ground_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_disabled;

float hash_value(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise_value(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash_value(cell);
	float b = hash_value(cell + vec2(1.0, 0.0));
	float c = hash_value(cell + vec2(0.0, 1.0));
	float d = hash_value(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.56;
	for (int octave = 0; octave < 4; octave++) {
		value += noise_value(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.48;
	}
	return value;
}

void fragment() {
	vec2 field = UV * vec2(230.0, 270.0);
	float broad = fbm(field * 0.055);
	float patches = fbm(field * 0.22);
	float grain = noise_value(field * 1.7);
	float value = broad * 0.58 + patches * 0.34 + grain * 0.08;
	vec3 earth = mix(vec3(0.105, 0.118, 0.091), vec3(0.235, 0.218, 0.159), smoothstep(0.28, 0.72, value));
	float worn = smoothstep(0.61, 0.78, patches) * 0.12;
	ALBEDO = mix(earth, vec3(0.27, 0.25, 0.185), worn);
	ROUGHNESS = 1.0;
}
"""
	ground_material.shader = ground_shader
	terrain.material_override = ground_material
	world_root.add_child(terrain)
	_add_box_collider(world_root, Vector3(0.0, -0.225, 25.0), Vector3(230.0, 0.45, 270.0), "BattlefieldFloor")
	_add_asset("res://assets/props/grass.glb", "GroundWeeds_A", Vector3(-7.0, 0.0, -4.0), 0.62, 0.0, true)
	_add_asset("res://assets/props/grass.glb", "GroundWeeds_B", Vector3(10.0, 0.0, 32.0), 0.78, 1.9, true)
	_add_asset("res://assets/props/grass.glb", "GroundWeeds_C", Vector3(-16.0, 0.0, 76.0), 0.7, 3.2, true)
	# Low irregular vegetation and scattered stone patches make the broad ground
	# read as churned field terrain while leaving the firing lanes unobstructed.
	var brush_positions: Array[Vector3] = [
		Vector3(-34.0, 0.0, -8.0), Vector3(33.0, 0.0, -14.0), Vector3(-39.0, 0.0, 27.0),
		Vector3(37.0, 0.0, 38.0), Vector3(-36.0, 0.0, 66.0), Vector3(39.0, 0.0, 84.0),
		Vector3(-24.0, 0.0, 111.0), Vector3(26.0, 0.0, 119.0), Vector3(-44.0, 0.0, 48.0),
		Vector3(44.0, 0.0, 7.0), Vector3(-28.0, 0.0, 92.0), Vector3(31.0, 0.0, 57.0)
	]
	for index in brush_positions.size():
		_add_asset("res://assets/props/grass.glb", "BattleBrush_%02d" % index, brush_positions[index], randf_range(0.48, 0.9), randf_range(0.0, TAU), true)
	var rubble_positions: Array[Vector3] = [
		Vector3(-26.0, 0.0, -5.0), Vector3(28.0, 0.0, 3.0), Vector3(-27.0, 0.0, 38.0),
		Vector3(29.0, 0.0, 35.0), Vector3(-35.0, 0.0, 79.0), Vector3(34.0, 0.0, 91.0),
		Vector3(-17.0, 0.0, 105.0), Vector3(20.0, 0.0, 111.0), Vector3(-47.0, 0.0, 31.0),
		Vector3(48.0, 0.0, 70.0), Vector3(-43.0, 0.0, 99.0), Vector3(45.0, 0.0, -28.0)
	]
	for index in rubble_positions.size():
		_add_asset("res://assets/props/stylised_rocks_asset_pack.glb", "FieldRubble_%02d" % index, rubble_positions[index], randf_range(0.045, 0.085), randf_range(0.0, TAU), true)
	var crater_layout: Array[Vector3] = [
		Vector3(-12.0, 1.55, -12.0), Vector3(13.0, 1.35, -26.0), Vector3(-27.0, 1.65, -32.0), Vector3(28.0, 1.45, -8.0),
		Vector3(-5.8, 1.28, -20.0), Vector3(7.2, 1.42, -17.0),
		Vector3(-12.0, 1.55, 29.0), Vector3(15.0, 1.4, 52.0), Vector3(-29.0, 1.5, 37.0), Vector3(31.0, 1.65, 63.0),
		Vector3(-12.0, 1.4, 69.0), Vector3(14.0, 1.6, 94.0), Vector3(-30.0, 1.65, 104.0), Vector3(34.0, 1.35, 82.0)
	]
	for index in crater_layout.size():
		var crater: Vector3 = crater_layout[index]
		_add_shell_crater(Vector3(crater.x, 0.025, crater.z), crater.y, float(index) * 1.31)

func _add_shell_crater(at: Vector3, radius: float, seed: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS: int = 20
	var ring_fractions: Array[float] = [0.24, 0.52, 0.78, 1.0]
	var ring_heights: Array[float] = [-0.045, -0.015, 0.10, 0.025]
	var ring_colors: Array[Color] = [Color("#211b14"), Color("#382f22"), Color("#716044"), Color("#4b4030")]
	# Fill the shallow center explicitly. The old near-point center ring left
	# almost no dark soil visible at player height, reading only as a thin arc.
	surface.set_color(Color("#1d1812"))
	surface.add_vertex(Vector3(0.0, -0.03, 0.0))
	for ring_index in ring_fractions.size():
		for segment_index in SEGMENTS:
			var angle: float = TAU * float(segment_index) / float(SEGMENTS)
			var irregularity: float = 1.0 + 0.085 * sin(angle * 3.0 + seed) + 0.055 * cos(angle * 5.0 - seed * 0.7)
			var ring_radius: float = radius * ring_fractions[ring_index] * irregularity
			var ring_y: float = ring_heights[ring_index] + 0.025 * sin(angle * 2.0 + seed) * ring_fractions[ring_index]
			var color_t: float = clampf(float(ring_index) / float(ring_fractions.size() - 1) + 0.035 * sin(angle * 4.0 + seed), 0.0, 1.0)
			surface.set_color(ring_colors[ring_index].lerp(ring_colors[mini(ring_index + 1, ring_colors.size() - 1)], color_t if ring_index < ring_colors.size() - 1 else 0.0))
			surface.add_vertex(Vector3(cos(angle) * ring_radius, ring_y, sin(angle) * ring_radius))
	for segment_index in SEGMENTS:
		var next_segment: int = (segment_index + 1) % SEGMENTS
		surface.add_index(0)
		surface.add_index(1 + next_segment)
		surface.add_index(1 + segment_index)
	for ring_index in range(ring_fractions.size() - 1):
		for segment_index in SEGMENTS:
			var next_segment: int = (segment_index + 1) % SEGMENTS
			var a: int = 1 + ring_index * SEGMENTS + segment_index
			var b: int = 1 + ring_index * SEGMENTS + next_segment
			var c: int = 1 + (ring_index + 1) * SEGMENTS + segment_index
			var d: int = 1 + (ring_index + 1) * SEGMENTS + next_segment
			surface.add_index(a)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(b)
			surface.add_index(d)
			surface.add_index(c)
	surface.generate_normals()
	var crater_mesh := MeshInstance3D.new()
	crater_mesh.name = "ShallowShellCrater"
	crater_mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#6a5b42")
	material.vertex_color_use_as_albedo = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	crater_mesh.material_override = material
	crater_mesh.position = at
	world_root.add_child(crater_mesh)
	var pit := MeshInstance3D.new()
	pit.name = "CraterDarkSoil"
	var pit_mesh := CylinderMesh.new()
	pit_mesh.top_radius = radius * 0.34
	pit_mesh.bottom_radius = radius * 0.34
	pit_mesh.height = 0.03
	pit.mesh = pit_mesh
	var pit_material := StandardMaterial3D.new()
	pit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pit_material.albedo_color = Color("#322a1d")
	pit_material.roughness = 1.0
	pit.material_override = pit_material
	pit.position = at
	world_root.add_child(pit)

func _build_defense_line(line_index: int, z: float) -> void:
	for position_data in [
		[Vector3(-18.0, 0.0, z - 1.8), 0.12, 0.0],
		[Vector3(18.0, 0.0, z - 1.6), 0.12, -0.07]
	]:
		_add_asset("res://assets/props/trench_set.glb", "Line%d_Trench" % (line_index + 1), position_data[0], position_data[1], position_data[2], true)
	_add_asset("res://assets/props/sandbags_-_defense_line.glb", "Line%d_Sandbags_Left" % (line_index + 1), Vector3(-11.8, 0.0, z + 1.0), 0.08, 0.1 * line_index, true)
	_add_asset("res://assets/props/sandbags_-_defense_line.glb", "Line%d_Sandbags_Right" % (line_index + 1), Vector3(12.6, 0.0, z + 1.5), 0.08, PI + 0.16, true)
	var flank_sandbag_x: Array[float] = [-23.0, -17.0, 18.0, 24.0]
	for segment_index in flank_sandbag_x.size():
		var sandbag_x: float = flank_sandbag_x[segment_index]
		var sandbag_position := Vector3(sandbag_x, 0.0, z + 1.15)
		_add_asset("res://assets/props/sandbags_-_defense_line.glb", "Line%d_SandbagFlank_%d" % [line_index + 1, segment_index], sandbag_position, 0.08, PI if sandbag_x > 0.0 else 0.0, true)
		_add_box_collider(world_root, Vector3(sandbag_x, 0.67, z + 1.15), Vector3(2.8, 1.34, 2.5), "Line%d_SandbagFlankCollision_%d" % [line_index + 1, segment_index])
	if line_index == 0:
		_add_asset("res://assets/props/sandbags_-_defense_line.glb", "FirstLineCenterCover_Left", Vector3(-3.3, 0.0, z + 1.2), 0.08, 0.08, true)
		_add_asset("res://assets/props/sandbags_-_defense_line.glb", "FirstLineCenterCover_Right", Vector3(3.3, 0.0, z + 1.2), 0.08, PI - 0.08, true)
		_add_box_collider(world_root, Vector3(-3.3, 0.67, z + 1.2), Vector3(2.8, 1.34, 2.5), "FirstLineCenterCover_L")
		_add_box_collider(world_root, Vector3(3.3, 0.67, z + 1.2), Vector3(2.8, 1.34, 2.5), "FirstLineCenterCover_R")
	_add_box_collider(world_root, Vector3(-11.8, 0.67, z + 1.0), Vector3(2.8, 1.34, 2.5), "Line%d_Cover_L" % (line_index + 1))
	_add_box_collider(world_root, Vector3(12.6, 0.67, z + 1.5), Vector3(2.8, 1.34, 2.5), "Line%d_Cover_R" % (line_index + 1))
	# Each defensive line has a different set of physical and visual fieldworks.
	# Keep the central approach open while creating cover on both flanks.
	var flank_sign: float = -1.0 if line_index % 2 == 0 else 1.0
	_add_asset("res://assets/props/wooden_wall.glb", "Line%d_BrokenWall_L" % (line_index + 1), Vector3(-25.0, 0.0, z + 5.5), 1.0, 0.12 * line_index, true)
	_add_asset("res://assets/props/wooden_fences__low_poly.glb", "Line%d_FieldFence_R" % (line_index + 1), Vector3(29.0, 0.0, z + 6.5), 0.84, PI * 0.5 * flank_sign, true)
	for obstacle_side in [-1.0, 1.0]:
		var obstacle_x_offset: float = 12.0 if line_index == 0 else 27.0 + float(line_index % 2) * 2.0
		var obstacle_scale: float = 0.45 if line_index == 0 else 0.31 + 0.025 * line_index
		var obstacle_position := Vector3(obstacle_side * obstacle_x_offset, 0.0, z - 7.5 + float(line_index) * 1.6)
		_add_asset("res://assets/props/metal_barrier_tank_17_mb.glb", "Line%d_AntiTankObstacle_%s" % [line_index + 1, str(obstacle_side)], obstacle_position, obstacle_scale, PI * 0.5 * obstacle_side, true)
		var obstacle_collider_size: Vector3 = Vector3(2.8, 1.1, 3.6) if line_index == 0 else Vector3(2.45, 0.85, 2.15)
		_add_box_collider(world_root, obstacle_position + Vector3(0.0, obstacle_collider_size.y * 0.5, 0.0), obstacle_collider_size, "Line%d_AntiTankObstacleCollision_%s" % [line_index + 1, str(obstacle_side)])
	var house_x: float = -29.0 if line_index % 2 == 0 else 29.0
	_add_asset("res://assets/props/old_russian_house.glb", "Line%d_RuinedHouse" % (line_index + 1), Vector3(house_x, 0.0, z + 8.0), 1.15, PI if line_index % 2 == 0 else 0.0, true)
	_add_box_collider(world_root, Vector3(house_x, 1.55, z + 8.0), Vector3(5.6, 3.1, 5.8), "Line%d_HouseCollision" % (line_index + 1))
	_add_asset("res://assets/props/stylised_rocks_asset_pack.glb", "Line%d_Rubble" % (line_index + 1), Vector3(25.0 * (1.0 if line_index % 2 == 0 else -1.0), 0.0, z - 6.0), 0.13, 0.7 * line_index, true)
	if line_index == 0:
		_add_asset("res://assets/props/old_russian_house.glb", "FirstLineApproachRuin", Vector3(-22.0, 0.0, z - 14.0), 0.96, 0.24, true)
		_add_box_collider(world_root, Vector3(-22.0, 1.45, z - 14.0), Vector3(5.0, 2.9, 5.4), "FirstLineApproachRuinCollision")
		_add_asset("res://assets/props/wooden_fences__low_poly.glb", "FirstLineApproachFence", Vector3(-17.0, 0.0, z - 15.2), 0.82, -0.11, true)
	if line_index == 1:
		_add_asset("res://assets/props/airplane_crash.glb", "SecondLineWreck", Vector3(-31.0, 0.0, z - 12.0), 0.012, 0.35, true)
		_add_asset("res://assets/props/soviet_strong-point.glb", "SecondLineStrongPoint", Vector3(52.0, 0.0, z + 3.0), 0.01, -0.18, true)
	if line_index == 2:
		_add_asset("res://assets/props/old_wooden_barn.glb", "ThirdLineBurnedSupplyShed", Vector3(31.0, 0.0, z + 12.0), 0.17, PI * 0.5, true)
		_add_asset("res://assets/props/soviet_strong-point.glb", "ThirdLineStrongPoint", Vector3(-39.0, 0.0, z + 3.0), 0.01, 0.22, true)

func _build_approach_pockets() -> void:
	# Distinct forward fighting pockets add usable flank cover while leaving a
	# clear central approach for movement between the first and second lines.
	_add_asset("res://assets/props/sandbags_-_defense_line.glb", "FirstLineApproachCover_Left", Vector3(-9.5, 0.0, -17.5), 0.074, -0.12, true)
	_add_box_collider(world_root, Vector3(-9.5, 0.55, -17.5), Vector3(2.6, 1.1, 2.0), "FirstLineApproachCover_Left_Collision")
	_add_asset("res://assets/props/sandbags_-_defense_line.glb", "FirstLineApproachCover_Right", Vector3(10.8, 0.0, -24.0), 0.074, PI + 0.18, true)
	_add_box_collider(world_root, Vector3(10.8, 0.55, -24.0), Vector3(2.6, 1.1, 2.0), "FirstLineApproachCover_Right_Collision")
	_add_asset("res://assets/props/wooden_wall.glb", "FirstLineBrokenBarricade_Left", Vector3(-18.5, 0.0, -23.0), 0.62, 0.28, true)
	_add_asset("res://assets/props/old_wooden_barn.glb", "FirstLineRuin_Right", Vector3(29.5, 0.0, -20.0), 0.12, -0.36, true)
	_add_box_collider(world_root, Vector3(29.5, 1.2, -20.0), Vector3(4.4, 2.4, 4.8), "FirstLineRuin_Right_Collision")

func _build_bunker() -> void:
	var center := Vector3(2.0, 0.0, 113.0)
	_add_asset("res://assets/props/bunker_o323a-160_z.glb", "ReinforcementBunker", center, 0.85, PI, true)
	# Local wall collision preserves the bunker entrance facing the approach from
	# the third trench while keeping the roof as a real Stuka shelter.
	_add_box_collider(world_root, center + Vector3(-4.3, 1.45, 0.0), Vector3(0.75, 2.9, 7.5), "BunkerLeftWall")
	_add_box_collider(world_root, center + Vector3(4.3, 1.45, 0.0), Vector3(0.75, 2.9, 7.5), "BunkerRightWall")
	_add_box_collider(world_root, center + Vector3(0.0, 3.0, 0.0), Vector3(8.0, 0.6, 7.5), "BunkerRoof")
	_add_box_collider(world_root, center + Vector3(0.0, 1.45, 3.7), Vector3(8.0, 2.9, 0.65), "BunkerRearWall")
	bunker_area = _make_interaction_area("BunkerExit", center + Vector3(0.0, 0.9, -3.7), Vector3(2.3, 1.8, 2.0), &"bunker")
	_add_shelter(center + Vector3(0.0, 0.0, 0.2), Vector3(4.0, 3.0, 3.2), "BunkerShelter")
	var house_shelter := Vector3(-29.0, 0.0, LINE_Z[1] + 8.0)
	_add_shelter(house_shelter, Vector3(2.3, 2.0, 2.2), "RuinedHouseShelter")

func _build_flanks() -> void:
	var tree_scene: PackedScene = load("res://assets/props/pine_tree.glb") as PackedScene
	if tree_scene != null:
		var tree_positions: Array[Vector3] = [
			Vector3(-49, 0, -23), Vector3(-64, 0, -5), Vector3(-53, 0, 18), Vector3(-71, 0, 40), Vector3(-55, 0, 64), Vector3(-69, 0, 88),
			Vector3(53, 0, -31), Vector3(68, 0, -8), Vector3(54, 0, 18), Vector3(71, 0, 40), Vector3(56, 0, 68), Vector3(70, 0, 91),
			Vector3(-45, 0, -47), Vector3(46, 0, -57), Vector3(-60, 0, 108), Vector3(61, 0, 112),
			Vector3(-37, 0, -17), Vector3(40, 0, -38), Vector3(-43, 0, 10), Vector3(42, 0, 28),
			Vector3(-39, 0, 52), Vector3(45, 0, 58), Vector3(-46, 0, 83), Vector3(38, 0, 102)
		]
		for index in tree_positions.size():
			var tree_position: Vector3 = tree_positions[index]
			var tree_scale: float = 0.035 + float(index % 4) * 0.003 if index >= 16 else 0.045 + float(index % 3) * 0.006
			_add_asset("res://assets/props/pine_tree.glb", "FlankPine_%02d" % index, tree_position, tree_scale, float(index) * 0.7, true)
	for side in [-1.0, 1.0]:
		_add_asset("res://assets/props/karelian_orthodox_chapel.glb", "BattleLandmark_%s" % str(side), Vector3(side * 43.0, 0.0, 61.0), 0.62, PI * 0.5 * side, true)
		_add_asset("res://assets/props/stylised_rocks_asset_pack.glb", "FlankRubble_%s" % str(side), Vector3(side * 38.0, 0.0, 19.0), 0.14, side * 0.45, true)
		_add_asset("res://assets/props/grass.glb", "FlankBrush_%s" % str(side), Vector3(side * 34.0, 0.0, 74.0), 1.0, side * 1.2, true)

func _build_artillery() -> void:
	for index in 2:
		var position := Vector3(-32.0 if index == 0 else 33.0, 0.0, 24.0 if index == 0 else 66.0)
		var howitzer := _add_asset("res://assets/props/152mm_m-10_howitzer.glb", "SovietM10_%d" % index, position, 0.95, PI if index == 0 else 0.0, true)
		if howitzer != null:
			artillery_positions.append(howitzer)
		_add_box_collider(world_root, position + Vector3(0.0, 0.45, 0.0), Vector3(2.7, 0.9, 4.8), "M10Position_%d" % index)

func _build_gun_station(index: int, at: Vector3) -> void:
	var gun_root := Node3D.new()
	gun_root.name = "LimitedAmmo45mm_%d" % (index + 1)
	gun_root.position = at
	world_root.add_child(gun_root)
	var model: Node3D = (load("res://assets/props/russian_45mm_artillery_gun.glb") as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * 0.024
	model.rotation.y = PI
	var bounds: AABB = _visual_bounds(model)
	model.position = Vector3(-bounds.position.x - bounds.size.x * 0.5, -bounds.position.y, -bounds.position.z - bounds.size.z * 0.5)
	gun_root.add_child(model)
	_disable_imported_collisions(model)
	_add_box_collider(gun_root, Vector3(0.0, 0.45, 0.0), Vector3(1.8, 0.9, 2.8), "45mmGunCollision")
	var interaction := Area3D.new()
	interaction.name = "GunInteraction_%d" % index
	interaction.collision_layer = 1
	interaction.collision_mask = 0
	interaction.set_meta("interaction_type", &"gun")
	interaction.set_meta("interaction_index", index)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.85
	shape.shape = sphere
	shape.position.y = 1.0
	interaction.add_child(shape)
	gun_root.add_child(interaction)
	gun_stations.append(interaction)

func _build_radio() -> void:
	var radio_pos := Vector3(-4.7, 0.0, 89.0)
	_add_asset("res://assets/props/radio_receiver_angrr-5.glb", "ThirdLineRadio", radio_pos + Vector3(0.0, 0.8, 0.0), 1.35, PI, true)
	radio_area = _make_interaction_area("DeadRadioOperatorAndSet", radio_pos, Vector3(2.1, 2.0, 2.2), &"radio")
	var fallen := _spawn_combatant(&"soviet", &"rifle", radio_pos + Vector3(1.8, 0.0, 0.0))
	if fallen != null:
		fallen.set_meta("radio_operator", true)
		fallen.call("die")

func _build_stuka() -> void:
	var packed := load("res://assets/vehicles/aviation/junkers_ju_87_stuka.glb") as PackedScene
	if packed == null:
		return
	var stuka := packed.instantiate() as Node3D
	stuka.name = "StukaFlightModel"
	stuka.scale = Vector3.ONE * 1.6
	stuka.position = Vector3(-100.0, 38.0, 0.0)
	world_root.add_child(stuka)
	stuka.set_meta("aircraft", true)
	var animation := stuka.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null:
		# The imported Take 01 moves/scales the GLB in its authoring coordinate
		# space. Chapter 3 drives the aircraft with its own world-space pass below.
		animation.stop()
	set_meta("stuka_node", stuka)

func _build_tanks() -> void:
	_spawn_tank(&"tiger", "res://assets/vehicles/rtcw_tiger.glb", Vector3(-15.0, 0.0, -38.0), 1.0)
	if ResourceLoader.exists("res://assets/vehicles/panzer_3_ausf_j_tank_model.glb"):
		_spawn_tank(&"panzer_iii", "res://assets/vehicles/panzer_3_ausf_j_tank_model.glb", Vector3(18.0, 0.0, -63.0), 0.01)
	else:
		push_warning("No local Pz III model found for Chapter 3; only the available Tiger will be used.")

func _spawn_tank(kind: StringName, path: String, at: Vector3, model_scale: float) -> void:
	var tank := TANK_SCRIPT.new() as Node3D
	world_root.add_child(tank)
	tank.configure(self, kind, path, at, model_scale)
	tanks.append(tank)

func _build_battle_bounds() -> void:
	# Physical end-of-map banks keep the active battle field finite and stop the
	# player wandering into unbuilt terrain without invisible collision walls.
	for side in [-1.0, 1.0]:
		_add_asset("res://assets/props/stylised_rocks_asset_pack.glb", "OuterRubbleBank_%s" % str(side), Vector3(side * 106.0, 0.0, 27.0), 0.8, side * 0.2, true)
		_add_box_collider(world_root, Vector3(side * 111.0, 4.0, 27.0), Vector3(4.0, 8.0, 265.0), "BattlefieldBoundary_%s" % str(side))
	_add_box_collider(world_root, Vector3(0.0, 4.0, -108.0), Vector3(222.0, 8.0, 4.0), "BattlefieldNorthBoundary")
	_add_box_collider(world_root, Vector3(0.0, 4.0, 162.0), Vector3(222.0, 8.0, 4.0), "BattlefieldSouthBoundary")

func _add_shelter(center: Vector3, half_size: Vector3, node_name: String) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = half_size * 2.0
	shape.shape = box
	area.add_child(shape)
	area.position = center + Vector3(0.0, half_size.y * 0.5, 0.0)
	world_root.add_child(area)
	shelters.append(area)

func _build_hud() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "Chapter3CombatHUD"
	game.add_child(ui_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(485.0, 100.0)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.91)
	ui_layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 21)
	stack.add_child(objective_label)
	phase_label = Label.new()
	phase_label.add_theme_font_size_override("font_size", 16)
	stack.add_child(phase_label)
	ammo_label = Label.new()
	phase_label.add_theme_color_override("font_color", Color("#dfd2a3"))
	stack.add_child(ammo_label)
	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.position.y = -95.0
	message_label.size = Vector2(1100.0, 42.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_color", Color("#f2e5c2"))
	ui_layer.add_child(message_label)
	prompt_label = Label.new()
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position.y = -52.0
	prompt_label.size = Vector2(1000.0, 38.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(prompt_label)
	reticle_label = Label.new()
	reticle_label.text = "+"
	reticle_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle_label.offset_left = -10.0
	reticle_label.offset_top = -16.0
	reticle_label.offset_right = 10.0
	reticle_label.offset_bottom = 16.0
	reticle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle_label.add_theme_font_size_override("font_size", 26)
	reticle_label.add_theme_color_override("font_color", Color("#f3e7ce"))
	ui_layer.add_child(reticle_label)
	result_panel = ColorRect.new()
	result_panel.color = Color(0.0, 0.0, 0.0, 0.83)
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.visible = false
	ui_layer.add_child(result_panel)
	result_label = Label.new()
	result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 46)
	result_panel.add_child(result_label)

func _build_sound_pool() -> void:
	var music_stream := load("res://assets/audio/music_for_chapter_3.mp3") as AudioStream
	if music_stream != null:
		world_music = AudioStreamPlayer.new()
		world_music.name = "Chapter3BattleMusic"
		world_music.stream = music_stream
		world_music.volume_db = -18.0
		game.add_child(world_music)
	for index in 12:
		var player_audio := AudioStreamPlayer3D.new()
		player_audio.name = "Chapter3WorldAudio_%02d" % index
		player_audio.max_distance = 92.0
		player_audio.unit_size = 12.0
		player_audio.max_polyphony = 2
		game.add_child(player_audio)
		sound_pool.append(player_audio)

func _spawn_initial_line(line_index: int) -> void:
	var z: float = LINE_Z[line_index]
	var soviet_positions: Array[Vector3] = [
		Vector3(-23.0, 0.0, -2.5), Vector3(-19.0, 0.0, 2.2), Vector3(-14.5, 0.0, -0.8),
		Vector3(-10.0, 0.0, 3.6), Vector3(-5.0, 0.0, -2.0), Vector3(5.5, 0.0, -3.1),
		Vector3(10.0, 0.0, 2.5), Vector3(15.0, 0.0, -0.5), Vector3(20.0, 0.0, 3.2), Vector3(24.0, 0.0, -1.8)
	]
	for index in soviet_positions.size():
		var offset: Vector3 = soviet_positions[index] + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.6, 0.6))
		_spawn_combatant(&"soviet", &"rifle" if index % 5 != 0 else &"heavy", Vector3(offset.x, 0.0, z + offset.z))
	var german_positions: Array[Vector3] = [
		Vector3(-29.0, 0.0, -26.0), Vector3(-23.0, 0.0, -18.0), Vector3(-17.0, 0.0, -24.0),
		Vector3(-10.0, 0.0, -15.0), Vector3(-4.0, 0.0, -22.0), Vector3(2.5, 0.0, -17.5),
		Vector3(9.0, 0.0, -28.0), Vector3(14.5, 0.0, -20.0), Vector3(21.0, 0.0, -13.0),
		Vector3(27.0, 0.0, -24.0), Vector3(33.0, 0.0, -18.0)
	]
	for index in german_positions.size():
		var offset: Vector3 = german_positions[index] + Vector3(randf_range(-1.6, 1.6), 0.0, randf_range(-2.0, 2.0))
		_spawn_combatant(&"german", &"rifle" if index % 5 != 0 else &"heavy", Vector3(offset.x, 0.0, z + offset.z))
	_spawn_combatant(&"soviet", &"ptrd", Vector3(-7.0, 0.0, z + 6.0))
	_spawn_combatant(&"german", &"dog", Vector3(-36.0, 0.0, z - 31.0))
	_spawn_combatant(&"german", &"dog", Vector3(38.0, 0.0, z - 35.0))

func _spawn_combatant(side: StringName, soldier_role: StringName, at: Vector3) -> Node3D:
	var active_combatants: Array[Node] = get_tree().get_nodes_in_group("chapter3_combatants")
	if active_combatants.size() >= MAX_ACTIVE_COMBATANTS:
		return null
	var combatant := COMBATANT_SCRIPT.new() as CharacterBody3D
	world_root.add_child(combatant)
	combatant.configure(self, side, soldier_role, at)
	if side == &"german" and not bool(combatant.get("rigged")):
		push_error("Refusing to spawn unrigged German infantry: %s" % str(at))
		combatant.queue_free()
		return null
	if side == &"german":
		german_spawn_count += 1
	else:
		soviet_spawn_count += 1
	return combatant

func _spawn_reinforcement_wave() -> void:
	var current_line: int = mini(2, 0 if stage == &"line1" else (1 if stage == &"line2" else 2))
	var line_z: float = LINE_Z[current_line]
	var active_germans: int = 0
	for node in get_tree().get_nodes_in_group("chapter3_combatants"):
		if node.get("faction") == &"german" and not bool(node.get("dead")):
			active_germans += 1
	if active_germans >= 15:
		return
	for index in 4:
		var flank: float = -1.0 if index % 2 == 0 else 1.0
		var spawn := Vector3(flank * randf_range(9.0, 28.0), 0.0, line_z - randf_range(25.0, 43.0))
		if _spawn_combatant(&"german", &"dog" if german_spawn_count % 7 == 0 and index == 3 else &"rifle", spawn) == null:
			break
	for index in 2:
		var flank: float = -1.0 if index == 0 else 1.0
		_spawn_combatant(&"soviet", &"rifle", Vector3(flank * randf_range(8.0, 24.0), 0.0, line_z + randf_range(0.0, 10.0)))

func _process(delta: float) -> void:
	if not active:
		return
	if test_scenario != "":
		test_elapsed += delta
		if test_scenario == "fast" or test_scenario == "smoke":
			if test_elapsed >= FAST_TEST_SECONDS and stage in [&"line1", &"line2", &"line3"]:
				stage_elapsed = 999.0
		if test_scenario == "smoke" and not test_capture_done and test_elapsed >= 4.0:
			test_capture_done = true
			var image := game.get_viewport().get_texture().get_image()
			var capture_path := ProjectSettings.globalize_path("res://__chapter3_game_view.png")
			image.save_png(capture_path)
			print("CHAPTER3_VIEWPORT_CAPTURE path=%s size=%s" % [capture_path, str(image.get_size())])
			call_deferred("_capture_crater_visual_test")
		if test_scenario == "smoke" and test_elapsed >= 12.0:
			print("CHAPTER3_SMOKE_RESULT stage=%s active_germans=%d rigged_germans=%d active_soviets=%d fps=%d nodes=%d" % [String(stage), _count_faction(&"german"), _count_rigged_germans(), _count_faction(&"soviet"), Engine.get_frames_per_second(), get_tree().get_node_count()])
			get_tree().quit()
		return
	if stage in [&"line1", &"line2"]:
		stage_elapsed += delta
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = randf_range(12.0, 18.0)
			_spawn_reinforcement_wave()
		var line_index: int = 0 if stage == &"line1" else 1
		var pressure: int = _count_nearby_enemies(LINE_Z[line_index], 12.0)
		var merit_extension: float = minf(float(stage_player_kills) * 5.5, 27.0)
		var pressure_acceleration: float = maxf(0.0, float(pressure - 6)) * 1.7
		var line_limit: float = DEFAULT_LINE_SECONDS + merit_extension - pressure_acceleration
		if stage_elapsed >= line_limit:
			if stage_player_kills < 2:
				_player_killed("Позиция прорвана: Дмитрий не смог поддержать оборону.")
			else:
				_breach_line(line_index)
	if stage == &"line3":
		stage_elapsed += delta
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = 12.0
			_spawn_reinforcement_wave()
		if stage_elapsed >= DEFAULT_LINE_SECONDS * 0.62 and not radio_used:
			stage = &"radio"
			_set_objective("Радист погиб. Доберись до радиостанции и вызови подкрепление [F].")
			_show_message("Связи нет. Радиостанция у третьей линии.", 5.0)
	if stage == &"radio" or stage == &"bunker_run":
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = 10.0
			_spawn_reinforcement_wave()
	_update_tanks(delta)
	_update_artillery(delta)
	_update_stuka(delta)
	_update_hud()
	_update_tracers(delta)
	if player.health <= 0.0 and stage not in [&"dead", &"complete"]:
		_player_killed("Дмитрий погиб на поле боя.")

func _capture_crater_visual_test() -> void:
	if not is_instance_valid(player):
		return
	for node in world_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node.name == "ShallowShellCrater" and mesh_node.global_position.distance_to(Vector3(-12.0, 0.025, -12.0)) < 0.1:
			print("CHAPTER3_CRATER_NODE pos=%s bounds=%s surfaces=%d visible=%s" % [str(mesh_node.global_position), str(mesh_node.mesh.get_aabb()), mesh_node.mesh.get_surface_count(), str(mesh_node.visible)])
	for combatant in get_tree().get_nodes_in_group("chapter3_combatants"):
		combatant.set_physics_process(false)
	for effect in get_tree().get_nodes_in_group("chapter3_explosion_visuals"):
		effect.queue_free()
	for tracer in firing_tracers:
		if is_instance_valid(tracer):
			tracer.queue_free()
	firing_tracers.clear()
	for node in world_root.get_children():
		if node.get_script() == PROJECTILE_SCRIPT:
			node.queue_free()
	var previous_transform: Transform3D = player.global_transform
	var previous_head_rotation: Vector3 = player.head.rotation
	var previous_pitch: float = player.pitch
	var previous_physics: bool = player.is_physics_processing()
	player.set_physics_process(false)
	player.global_position = Vector3(-7.0, 0.9, -12.0)
	player.rotation.y = PI * 0.5
	# Frame the crater from a clear player-height approach, away from the nearby
	# ruined house and aligned with the shallow depression.
	player.pitch = -0.30
	player.head.rotation = Vector3(player.pitch, 0.0, 0.0)
	await get_tree().process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	var capture_path := ProjectSettings.globalize_path("res://__chapter3_crater_view.png")
	image.save_png(capture_path)
	print("CHAPTER3_CRATER_CAPTURE path=%s size=%s" % [capture_path, str(image.get_size())])
	player.global_transform = previous_transform
	player.pitch = previous_pitch
	player.head.rotation = previous_head_rotation
	player.set_physics_process(previous_physics)

func _breach_line(line_index: int) -> void:
	if line_index == 0:
		stage = &"line2"
		stage_elapsed = 0.0
		stage_player_kills = 0
		wave_timer = 3.0
		_set_objective("Первая линия прорвана. Отходи ко второй и помоги расчётам орудий.")
		_show_message("Командир: «Ко второй линии! Отходи!»", 5.0)
		if not line_one_ptrd_spawned:
			line_one_ptrd_spawned = true
			_create_supply_crate(Vector3(-4.0, 0.0, 14.0), &"ptrd_pickup", 3, "ПТРД бойца")
	elif line_index == 1:
		stage = &"line3"
		stage_elapsed = 0.0
		stage_player_kills = 0
		wave_timer = 3.0
		_set_objective("Вторая линия не удержалась. Отходи к последней позиции.")
		_show_message("Радист третьей линии погиб. Нужно вызвать подкрепление.", 5.0)
		var ptrd_pickup := _find_pickup(&"ptrd_pickup")
		if ptrd_pickup != null:
			ptrd_pickup.position = Vector3(-6.5, 0.0, LINE_Z[1] + 5.0)
	elif line_index == 2:
		stage = &"radio"
		_set_objective("Радист погиб. Доберись до радиостанции и вызови подкрепление [F].")

func _find_pickup(pickup_type: StringName) -> Area3D:
	for area in pickup_areas:
		if is_instance_valid(area) and area.get_meta("pickup_type", &"") == pickup_type:
			return area
	return null

func _update_tanks(delta: float) -> void:
	for tank in tanks:
		if not is_instance_valid(tank) or bool(tank.get("wrecked")):
			continue
		var front_target: float = player.position.z - 12.0
		tank.call("advance_frontline", front_target, delta)
		if bool(tank.call("should_fire", delta)):
			var muzzle: Vector3 = tank.global_position + Vector3(0.0, 1.5, 2.5)
			var target_point: Vector3 = player.global_position + Vector3(0.0, 0.9, 0.0)
			launch_projectile(muzzle, target_point - muzzle, 38.0, 40.0, 4.0, &"explosive", tank)
			play_chapter3_sound("res://assets/audio/z_uko_ye-effekty-vystrel-tanka.mp3", tank.global_position, -3.0)

func _update_artillery(delta: float) -> void:
	artillery_timer -= delta
	if artillery_timer > 0.0:
		return
	artillery_timer = randf_range(15.0, 22.0)
	var hostiles := get_tree().get_nodes_in_group("chapter3_combatants")
	for artillery in artillery_positions:
		var target: Node3D = _nearest_hostile_to(artillery.global_position)
		if target == null:
			continue
		var muzzle: Vector3 = artillery.global_position + Vector3(0.0, 1.5, 1.3)
		var aim_point: Vector3 = target.global_position + Vector3(0.0, 0.4, 0.0)
		launch_projectile(muzzle, aim_point - muzzle, 52.0, 42.0, 5.0, &"artillery", artillery)
		play_chapter3_sound("res://assets/audio/golos-orudiy--grom-vozmezdiya.mp3", artillery.global_position, -9.0)

func _update_stuka(delta: float) -> void:
	var stuka := get_meta("stuka_node", null) as Node3D
	if stuka_active:
		stuka_elapsed += delta
		var flight_t: float = clampf(stuka_elapsed / 7.0, 0.0, 1.0)
		stuka.position = Vector3(lerpf(-100.0, 100.0, flight_t), 34.0 + sin(flight_t * PI) * 1.8, stuka_target_z - 8.0)
		stuka.rotation.y = -PI * 0.5
		if pending_bomb and stuka_elapsed >= 3.4:
			pending_bomb = false
			var attack_point := player.global_position + Vector3(0.0, 0.0, -2.0)
			if not _player_is_sheltered():
				explode_at(attack_point, 74.0, 10.0, stuka, &"explosive")
				_show_message("Ударная волна Stuka сбила Дмитрия с ног!", 4.0)
			else:
				_show_message("Бетон укрыл Дмитрия от пикирующего самолёта.", 4.0)
		if stuka_elapsed >= 7.2:
			stuka_active = false
			stuka_elapsed = 0.0
			if stuka != null:
				stuka.position = Vector3(-115.0, 42.0, -60.0)
		return
	stuka_timer -= delta
	if stuka_timer <= 0.0 and stage in [&"line1", &"line2", &"line3", &"radio", &"bunker_run"]:
		stuka_active = true
		stuka_elapsed = 0.0
		pending_bomb = true
		stuka_target_z = player.global_position.z
		stuka_timer = randf_range(88.0, 115.0)
		if stuka != null:
			stuka.position = Vector3(-100.0, 38.0, stuka_target_z - 8.0)
		play_chapter3_sound("res://assets/audio/stuka-airplane.mp3", player.global_position, -4.0)
		_show_message("Сирена! Stuka заходит на удар — ищи крышу или блиндаж!", 7.0)

func _player_is_sheltered() -> bool:
	for area in shelters:
		if is_instance_valid(area) and area.overlaps_body(player):
			return true
	return false

func _update_hud() -> void:
	if not is_instance_valid(player) or objective_label == null:
		return
	var stage_name: String = "ПЕРВАЯ ЛИНИЯ" if stage == &"line1" else ("ВТОРАЯ ЛИНИЯ" if stage == &"line2" else ("ТРЕТЬЯ ЛИНИЯ" if stage in [&"line3", &"radio"] else ("ПУТЬ К БЛИНДАЖУ" if stage == &"bunker_run" else String(stage).to_upper())))
	phase_label.text = "%s  •  бойцов противника поблизости: %d  •  здоровье: %d" % [stage_name, _count_nearby_enemies(player.position.z, 35.0), int(player.health)]
	if player.current_weapon_definition != null and player.weapon_visible:
		ammo_label.text = "%s  %d / %d" % [player.current_weapon_definition.display_name, player.ammo, player.reserve_ammo]
	else:
		ammo_label.text = "F — взаимодействие   •   Q / E — выглянуть   •   Shift — бег"
	if active_gun_index >= 0:
		phase_label.text = "РАСЧЁТ 45-мм  •  снарядов: %d" % gun_shells[active_gun_index]
		prompt_label.text = "ЛКМ — выстрел   •   F — покинуть орудие"
	elif prompt_label.text.begins_with("[F]"):
		pass

func _set_objective(text: String) -> void:
	if objective_label != null:
		objective_label.text = text
	if game != null:
		game.state = "chapter3"

func _show_message(text: String, duration: float = 3.2) -> void:
	if message_label != null:
		message_label.text = text
		message_label.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_interval(maxf(0.2, duration - 0.5))
		tween.tween_property(message_label, "modulate:a", 0.0, 0.5)

func find_target_for(combatant: Node3D) -> Node3D:
	if not is_instance_valid(combatant):
		return null
	var faction: StringName = combatant.get("faction")
	var role: StringName = combatant.get("role")
	if faction == &"soviet" and role == &"ptrd":
		var enemy_tank := _nearest_enemy_tank(combatant.global_position)
		if enemy_tank != null:
			return enemy_tank
	var best_target: Node3D
	var best_score: float = INF
	for candidate in get_tree().get_nodes_in_group("chapter3_combatants"):
		if candidate == combatant or not is_instance_valid(candidate) or bool(candidate.get("dead")):
			continue
		if candidate.get("faction") == faction:
			continue
		var distance: float = combatant.global_position.distance_to(candidate.global_position)
		var score: float = distance + (2.0 if candidate.get("role") == &"dog" else 0.0)
		if score < best_score:
			best_score = score
			best_target = candidate as Node3D
	if faction == &"german" and is_instance_valid(player):
		var player_distance: float = combatant.global_position.distance_to(player.global_position)
		if player_distance < 44.0 and player_distance + 4.0 < best_score:
			best_target = player
	return best_target

func pick_cover_approach(from: Vector3, target: Vector3, faction: StringName) -> Vector3:
	var vector: Vector3 = target - from
	vector.y = 0.0
	if vector.length_squared() < 0.01:
		return from
	var side: float = -1.0 if int(get_instance_id()) % 2 == 0 else 1.0
	var flank: Vector3 = Vector3(-vector.z, 0.0, vector.x).normalized() * side * 2.4
	var cover_point: Vector3 = from + vector.normalized() * 6.0 + flank
	cover_point.x = clampf(cover_point.x, -82.0, 82.0)
	cover_point.z = clampf(cover_point.z, -92.0, 154.0)
	if faction == &"german":
		cover_point.z = minf(cover_point.z, player.position.z + 12.0)
	return cover_point

func has_clear_fire_line(from: Vector3, to: Vector3, shooter: Node3D, target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	var exclude: Array[RID] = []
	if shooter is CollisionObject3D:
		exclude.append((shooter as CollisionObject3D).get_rid())
	query.exclude = exclude
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.get("collider") == target

func draw_tracer(from: Vector3, to: Vector3, faction: StringName) -> void:
	if firing_tracers.size() >= 16:
		return
	var line := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	var total_length: float = from.distance_to(to)
	var tracer_length: float = minf(2.2, total_length * 0.16)
	var direction: Vector3 = (to - from).normalized()
	var tracer_start: Vector3 = from.lerp(to, 0.58)
	var tracer_end: Vector3 = tracer_start + direction * tracer_length
	tube.top_radius = 0.008 if faction == &"german" else 0.006
	tube.bottom_radius = tube.top_radius
	tube.height = maxf(0.01, tracer_length)
	line.mesh = tube
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#f1cc74") if faction == &"german" else Color("#d6d9a0")
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.35
	line.material_override = material
	line.position = (tracer_start + tracer_end) * 0.5
	world_root.add_child(line)
	line.look_at(tracer_end, Vector3.UP)
	line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	line.set_meta("life", 0.11)
	firing_tracers.append(line)

func _update_tracers(delta: float) -> void:
	for index in range(firing_tracers.size() - 1, -1, -1):
		var tracer: MeshInstance3D = firing_tracers[index]
		if not is_instance_valid(tracer):
			firing_tracers.remove_at(index)
			continue
		var life: float = float(tracer.get_meta("life", 0.0)) - delta
		tracer.set_meta("life", life)
		if life <= 0.0:
			tracer.queue_free()
			firing_tracers.remove_at(index)

func on_combatant_died(combatant: Node3D) -> void:
	if combatant.get("faction") == &"german":
		var attacker: Node = combatant.get("target") as Node
		if attacker == player:
			stage_player_kills += 1
			total_player_kills += 1
		if randf() < 0.36:
			_create_supply_crate(combatant.global_position + Vector3(0.0, 0.05, 0.0), &"mp40_pickup", 12, "Патроны MP40")
	elif combatant.get("faction") == &"soviet" and combatant.get("role") == &"ptrd" and not line_one_ptrd_spawned:
		line_one_ptrd_spawned = true
		_create_supply_crate(combatant.global_position + Vector3(0.0, 0.05, 0.0), &"ptrd_pickup", 3, "ПТРД бойца")

func _count_faction(faction: StringName) -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("chapter3_combatants"):
		if node.get("faction") == faction and not bool(node.get("dead")):
			count += 1
	return count

func _count_rigged_germans() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("chapter3_combatants"):
		if node.get("faction") == &"german" and not bool(node.get("dead")) and bool(node.get("rigged")):
			count += 1
	return count

func _count_nearby_enemies(line_z: float, radius: float) -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("chapter3_combatants"):
		if node.get("faction") == &"german" and not bool(node.get("dead")) and absf(node.global_position.z - line_z) <= radius:
			count += 1
	return count

func _nearest_hostile_to(from: Vector3) -> Node3D:
	var best: Node3D
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("chapter3_combatants"):
		if node.get("faction") != &"german" or bool(node.get("dead")):
			continue
		var distance: float = from.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node as Node3D
	return best

func _nearest_enemy_tank(from: Vector3) -> Node3D:
	var best: Node3D
	var best_distance: float = INF
	for tank in tanks:
		if not is_instance_valid(tank) or bool(tank.get("wrecked")):
			continue
		var distance: float = from.distance_squared_to(tank.global_position)
		if distance < best_distance:
			best_distance = distance
			best = tank
	return best

func launch_projectile(from: Vector3, direction: Vector3, speed: float, damage: float, radius: float, kind: StringName, source: Node = null) -> void:
	var projectile := PROJECTILE_SCRIPT.new() as Node3D
	world_root.add_child(projectile)
	projectile.launch(self, from, direction, speed, damage, radius, kind, source)

func explode_at(position: Vector3, damage: float, radius: float, source: Node, kind: StringName) -> void:
	var actual_radius: float = maxf(radius, 0.7)
	for node in get_tree().get_nodes_in_group("chapter3_combatants"):
		if not is_instance_valid(node) or bool(node.get("dead")) or node == source:
			continue
		var distance: float = position.distance_to(node.global_position + Vector3(0.0, 0.75, 0.0))
		if distance <= actual_radius:
			var falloff: float = clampf(1.0 - distance / (actual_radius * 1.2), 0.18, 1.0)
			node.call("receive_projectile", damage * falloff, kind, source)
	for tank in tanks:
		if not is_instance_valid(tank) or bool(tank.get("wrecked")) or tank == source:
			continue
		var distance: float = position.distance_to(tank.global_position + Vector3(0.0, 1.0, 0.0))
		if distance <= actual_radius:
			var falloff: float = clampf(1.0 - distance / (actual_radius * 1.2), 0.15, 1.0)
			tank.call("receive_projectile", damage * falloff, kind, source)
	if is_instance_valid(player) and player != source:
		var player_distance: float = position.distance_to(player.global_position + Vector3(0.0, 0.75, 0.0))
		if player_distance <= actual_radius:
			player.call("take_damage", damage * clampf(1.0 - player_distance / (actual_radius * 1.2), 0.12, 1.0), kind, source)
	play_chapter3_sound("res://assets/audio/explosion-with-fire-flame.mp3", position, -8.0)
	_spawn_explosion_visual(position)

func _spawn_explosion_visual(position: Vector3, visual_scale: float = 0.22) -> void:
	var packed := load("res://assets/props/timeframe_explosion.glb") as PackedScene
	if packed == null:
		return
	var visual := packed.instantiate() as Node3D
	visual.add_to_group("chapter3_explosion_visuals")
	visual.position = position
	visual.scale = Vector3.ONE * visual_scale
	world_root.add_child(visual)
	var animation := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null and not animation.get_animation_list().is_empty():
		animation.play(animation.get_animation_list()[0])
	get_tree().create_timer(1.6).timeout.connect(visual.queue_free)

func on_tank_destroyed(tank: Node3D, attacker: Node) -> void:
	_show_message("Немецкий танк выведен из строя.", 4.0)
	_spawn_explosion_visual(tank.global_position + Vector3(0.0, 1.0, 0.0), 0.34)
	if attacker == player:
		total_player_kills += 1

func player_melee_attack() -> void:
	var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + (-camera.global_transform.basis.z) * 2.2
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target: Object = hit.get("collider")
	if target is Node and (target as Node).has_method("receive_projectile"):
		(target as Node).call("receive_projectile", 45.0, &"melee", player)

func player_killed(reason: String) -> void:
	if not active or stage == &"dead":
		return
	_player_killed(reason)

func _player_killed(reason: String) -> void:
	active = false
	stage = &"dead"
	game.state = "chapter3_dead"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if world_music != null:
		world_music.stop()
	result_panel.visible = true
	result_label.text = "ДМИТРИЙ ПОГИБ\n%s\n\nR — начать главу заново" % reason
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_message(reason, 6.0)

func _make_interaction_area(area_name: String, at: Vector3, box_size: Vector3, kind: StringName) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	area.position = at
	area.collision_layer = 1
	area.collision_mask = 0
	area.set_meta("interaction_type", kind)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	area.add_child(shape)
	world_root.add_child(area)
	return area

func _create_supply_crate(at: Vector3, kind: StringName, count: int, label_text: String) -> void:
	var area := Area3D.new()
	area.name = "%s_%d" % [String(kind), pickup_areas.size()]
	area.position = at
	area.collision_layer = 1
	area.collision_mask = 0
	area.set_meta("interaction_type", &"pickup")
	area.set_meta("pickup_type", kind)
	area.set_meta("amount", count)
	area.set_meta("label", label_text)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.15
	shape.shape = sphere
	shape.position.y = 0.85
	area.add_child(shape)
	world_root.add_child(area)
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.65, 0.7)
	crate.mesh = box
	crate.position = at + Vector3(0.0, 0.34, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#554531") if kind.contains("ammo") else Color("#6f5537")
	material.roughness = 0.95
	crate.material_override = material
	world_root.add_child(crate)
	_add_box_collider(world_root, at + Vector3(0.0, 0.33, 0.0), box.size, "PickupCrateCollision")
	pickup_areas.append(area)

func _try_interaction() -> void:
	if active_gun_index >= 0:
		active_gun_index = -1
		player.set("using_chapter3_gun", false)
		prompt_label.text = ""
		_show_message("Дмитрий отошёл от орудия.", 2.0)
		return
	var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + (-camera.global_transform.basis.z) * 3.6
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var object: Object = hit.get("collider")
	if not object is Area3D:
		return
	var area := object as Area3D
	var kind: StringName = area.get_meta("interaction_type", &"")
	if kind == &"gun":
		var index: int = int(area.get_meta("interaction_index", -1))
		if index >= 0 and index < gun_shells.size():
			active_gun_index = index
			player.set("using_chapter3_gun", true)
			prompt_label.text = "ЛКМ — выстрел   •   F — покинуть орудие"
			_show_message("45-мм орудие готово. Осталось снарядов: %d" % gun_shells[index], 3.0)
	elif kind == &"pickup":
		_take_pickup(area)
	elif kind == &"radio" and stage == &"radio" and not radio_used:
		_call_reinforcements()
	elif kind == &"bunker" and stage == &"bunker_run":
		_complete_chapter()

func _take_pickup(area: Area3D) -> void:
	var kind: StringName = area.get_meta("pickup_type", &"")
	var count: int = int(area.get_meta("amount", 0))
	if kind == &"ptrd_pickup":
		var definition := load("res://resources/weapons/ptrd_definition.tres") as WeaponDefinition
		if definition != null:
			player.call("grant_weapon", definition)
			player.weapon_ammo[&"ptrd"] = 1
			player.weapon_reserve_ammo[&"ptrd"] = maxi(0, count - 1)
			player.ammo = 1
			player.reserve_ammo = maxi(0, count - 1)
			player.call("equip_weapon", definition)
			_show_message("ПТРД получен. Боезапас ограничен: %d выстр." % count, 4.0)
	elif kind == &"mp40_pickup":
		var definition := load("res://resources/weapons/mp40_definition.tres") as WeaponDefinition
		if definition != null:
			player.call("grant_weapon", definition)
			player.weapon_ammo[&"mp40"] = count
			player.weapon_reserve_ammo[&"mp40"] = 0
			player.ammo = count
			player.reserve_ammo = 0
			player.call("equip_weapon", definition)
			_show_message("MP40 поднят. Получено %d патронов." % count, 4.0)
	elif kind == &"ppsh_ammo":
		var added: int = mini(count, maxi(0, player.max_ammo - player.ammo))
		player.ammo += added
		if player.current_weapon_definition != null:
			player.weapon_ammo[player.current_weapon_definition.weapon_id] = player.ammo
		_show_message("Боеприпасы ППШ: +%d" % added, 3.0)
	elif kind == &"ptrd_ammo":
		var added: int = player.call("add_weapon_ammo", &"ptrd", count)
		_show_message("Снаряды ПТРД: +%d" % added, 3.0)
	area.queue_free()
	pickup_areas.erase(area)

func _call_reinforcements() -> void:
	radio_used = true
	reinforcements_called = true
	stage = &"bunker_run"
	stage_elapsed = 0.0
	wave_timer = 1.0
	_set_objective("Подкрепление вызвано. Доберись до блиндажа под огнём! [F]")
	_show_message("Радист: «Связь есть. Подкрепление принято!»", 6.0)
	play_chapter3_sound("res://assets/audio/your-soldiers-will-be-torn-to-pieces-here.mp3", radio_area.global_position, -7.0)

func _complete_chapter() -> void:
	active = false
	stage = &"complete"
	game.state = "chapter3_complete"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if world_music != null:
		world_music.stop()
	result_panel.visible = true
	result_label.text = "ПОДКРЕПЛЕНИЕ ВЫЗВАНО\n\nДмитрий добрался до блиндажа.\nПродолжение следует.\n\nГлава 3 завершена"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func interact_with_current_aim() -> void:
	_try_interaction()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R and stage == &"dead":
			game.call("start_chapter3", test_scenario)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		_try_interaction()
	if active_gun_index >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire_45mm(active_gun_index)

func _fire_45mm(index: int) -> void:
	if index < 0 or index >= gun_shells.size() or gun_shells[index] <= 0:
		_show_message("В орудии закончились снаряды. Найди следующую позицию.", 3.0)
		return
	gun_shells[index] -= 1
	var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
	var from: Vector3 = camera.global_position + (-camera.global_transform.basis.z) * 1.1
	var direction: Vector3 = -camera.global_transform.basis.z
	launch_projectile(from, direction, 74.0, 240.0, 3.2, &"artillery", player)
	play_chapter3_sound("res://assets/audio/z_uko_ye-effekty-vystrel-tanka.mp3", player.global_position, -5.0)
	_show_message("Выстрел 45-мм. Осталось снарядов: %d" % gun_shells[index], 2.0)

func play_chapter3_sound(path: String, at: Vector3, volume_db: float = -9.0) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var last_time: float = float(sound_cooldowns.get(path, -INF))
	if now - last_time < 0.12:
		return
	sound_cooldowns[path] = now
	var stream := load(path) as AudioStream
	if stream == null or sound_pool.is_empty():
		return
	var chosen: AudioStreamPlayer3D
	for candidate in sound_pool:
		if not candidate.playing:
			chosen = candidate
			break
	if chosen == null:
		chosen = sound_pool[0]
		chosen.stop()
	chosen.stream = stream
	chosen.global_position = at
	chosen.volume_db = volume_db
	chosen.play()

func _add_asset(path: String, node_name: String, at: Vector3, uniform_scale: float, yaw: float, recenter: bool, scale_override: Vector3 = Vector3.ZERO) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Chapter 3 environment asset missing: %s" % path)
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	model.name = node_name
	model.scale = scale_override if scale_override != Vector3.ZERO else Vector3.ONE * uniform_scale
	if recenter:
		var bounds: AABB = _visual_bounds(model)
		if bounds.size.length_squared() > 0.0001:
			model.position = Vector3(-bounds.position.x - bounds.size.x * 0.5, -bounds.position.y, -bounds.position.z - bounds.size.z * 0.5)
	model.rotation.y = yaw
	world_root.add_child(model)
	model.global_position = at
	_disable_imported_collisions(model)
	return model

func _visual_bounds(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect_visual_bounds(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var result: AABB = boxes[0]
	for index in range(1, boxes.size()):
		result = result.merge(boxes[index])
	return result

func _collect_visual_bounds(node: Node3D, parent_transform: Transform3D, boxes: Array[AABB]) -> void:
	var combined: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			boxes.append(combined * mesh_node.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_collect_visual_bounds(child as Node3D, combined, boxes)

func _disable_imported_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		body.collision_layer = 0
		body.collision_mask = 0
		body.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_imported_collisions(child)

func _add_box_collider(parent: Node, at: Vector3, size: Vector3, body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)
	return body
