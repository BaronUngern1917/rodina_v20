extends Resource
class_name WeaponDefinition

@export var weapon_id: StringName
@export var display_name: String = "Оружие"
@export var equip_key_physical_code: int = 50
@export var visual_scene: PackedScene
@export var fire_sound: AudioStream
@export var magazine_capacity: int = 35
@export var reserve_magazines: int = 2
@export var rounds_per_second: float = 10.0
@export var spread_degrees: float = 0.8
@export var reload_duration: float = 1.35
@export var hip_position: Vector3 = Vector3(0.35, -0.28, -0.62)
@export var ads_position: Vector3 = Vector3(0.02, -0.05, -0.62)
@export var hip_rotation_degrees: Vector3 = Vector3.ZERO
@export var ads_rotation_degrees: Vector3 = Vector3.ZERO
@export var muzzle_position: Vector3 = Vector3(0.0, -0.02, -0.55)
