class_name ActionControllerTuning
extends Resource
## Share a preset, or duplicate it per player. All distances are metres, times seconds.

@export_group("Locomotion")
@export var move_speed := 7.0
@export var sprint_speed := 12.0
@export var crouch_speed := 3.0
@export var ground_acceleration := 48.0
@export var ground_deceleration := 42.0
@export var air_acceleration := 12.0
@export var gravity := 28.0
@export var max_fall_speed := 50.0
@export var jump_velocity := 10.0
@export var coyote_time := 0.12
@export var jump_buffer := 0.12
@export var capsule_radius := 0.38
@export var standing_height := 1.8
@export var crouching_height := 1.05
@export_flags_3d_physics var world_mask := 1

@export_group("Slide")
@export var slide_min_speed := 8.0
@export var slide_end_speed := 3.0
@export var slide_friction := 5.0
@export var slide_steering := 1.5
@export var slide_downhill_acceleration := 16.0
@export var slide_downhill_min_angle := 12.0
@export var slide_max_speed := 22.0

@export_group("Dodge")
@export var dodge_speed := 21.0
@export var dodge_duration := 0.22
@export var dodge_charge_cooldown := 3.0

@export_group("Parkour")
@export var wall_reach := 0.75
@export var wall_max_normal_y := 0.15
@export var wall_run_min_speed := 6.0
@export var wall_run_duration := 1.5
@export var wall_run_gravity_scale := 0.16
@export var wall_run_steering := 2.0
@export var wall_reattach_delay := 0.6
@export var wall_jump_force := 9.0
@export var wall_jump_up := 11.0
@export var wall_jump_forward := 5.0
@export var mantle_reach := 0.95
@export var mantle_min_height := 0.35
@export var mantle_low_height := 1.1
@export var mantle_max_height := 2.4
@export var mantle_low_duration := 0.28
@export var mantle_high_duration := 0.55

@export_group("Air dash")
@export var air_dash_startup := 0.28
@export var air_dash_speed := 36.0
@export var air_dash_duration := 0.18
@export var air_dash_steering := 0.8
@export var air_dash_cooldown := 0.8
@export var air_dash_momentum_retained := 0.15
@export var air_dash_exit_speed := 15.0
@export var allow_dash_from_wall_run := false

@export_group("Combat")
@export var block_move_scale := 0.4
@export var jump_cancels_block := true
@export var dodge_cancels_block := true
@export var attack_move_scale := 0.22
@export var attack_startup := PackedFloat32Array([0.12, 0.16, 0.22])
@export var attack_active := PackedFloat32Array([0.1, 0.12, 0.16])
@export var attack_recovery := PackedFloat32Array([0.28, 0.3, 0.42])
## Per hit, relative to its start. The window overlaps active and early recovery.
@export var combo_window_start := PackedFloat32Array([0.14, 0.18, 0.24])
@export var combo_window_end := PackedFloat32Array([0.38, 0.44, 0.55])
