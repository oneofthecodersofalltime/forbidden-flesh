extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var home_pos : Vector3 = global_transform.origin

@onready var nav := $NavigationAgent3D as NavigationAgent3D
@onready var sword := $Sword as Node3D
@onready var hit_audio := $HitAudio as AudioStreamPlayer3D
@onready var swing_audio := $SwingAudio as AudioStreamPlayer3D

@onready var lunge_timer := $LungeTimer as Timer
@onready var pacification_timer := $PacificationTimer as Timer

@export var able_to_lunge : bool = true

var boost_applied : bool = false
var lunging : bool = false
var swinging : bool = false
var attacking : bool = false

var pacified : bool = false

var speed : float = 2.0 + randf_range(0, 1.5)

var splat_ready : bool = true
var health : int = 7
@onready var invincibility_timer := $InvincibilityTimer as Timer
var inside_sword : bool = false
var invincible : bool = false

var new_velocity : Vector3 = Vector3.ZERO

var player_pos : Vector3 = Vector3.ZERO

@onready var global_vars : Object = get_node("/root/global")

func _ready() -> void:
	pacification_timer.start(5 + randi_range(0, 10))
	if able_to_lunge: ($AttackArea/NormalArea as CollisionShape3D).queue_free()
	else: ($AttackArea/LungeArea as CollisionShape3D).queue_free()

func attack() -> void:
	if sword.rotation.y <= (80 * PI) / 180 and swinging: # 80 deg
		sword.rotation.y += PI/32
		
	else:
		swinging = false
		if sword.rotation.y >= -(80 * PI) / 180: sword.rotation.y -= PI/64
		else: 
			attacking = false


func take_damage():
	pacified = false
	if splat_ready: 
		splat_ready = false
		($GPUParticles3D as GPUParticles3D).emitting = true
		
	var damage_dict = global_vars.melee_damage_dict
	var player_weapon = global_vars.current_melee
		
	# Tutkii autoloaderin damage dictistä, että kuinka paljon pelaajan ase tekee lämää
	for dicts in damage_dict:
		if str(dicts) in str(player_weapon):
			health -= damage_dict[dicts] + randi_range(0, 1)
	hit_audio.play()
	($MeshInstance3D/MeshInstance3D as MeshInstance3D).transparency = health * 0.1
	invincible = true
	invincibility_timer.start()


func _physics_process(_delta) -> void:
	player_pos = global_vars.player_position
	if inside_sword and not invincible and global_vars.player_attack:
		take_damage()
	death()
	attack()
	if not attacking: 

		var current_location = global_transform.origin
		var next_location = null
		
		# Pacification
		if not pacified: nav.target_position = player_pos
		else: nav.target_position = home_pos
		
		
		next_location = nav.get_next_path_position()
		
		
		if lunging and not boost_applied and able_to_lunge: 
			lunge_timer.start()
			boost_applied = true
			new_velocity = (next_location - current_location).normalized() * speed * 10
		elif not lunging or not able_to_lunge:
			new_velocity = (next_location - current_location).normalized() * speed
			
			# Koska look_at:tin tulos pitää olla != 0, niin lisätään 0.001, jotta aina olisi pieni offset 0:llasta.
			look_at(next_location + Vector3(0.001, 0.001, 0.001))
			rotation.y += PI
		velocity = new_velocity
		if pacified:
			look_at(player_pos)
			rotation.y += PI
		rotation.x = 0
		if not is_on_floor(): velocity.y -= gravity
		move_and_slide()

func _on_area_3d_area_entered(area) -> void:
	if area.is_in_group("PlayerSword"): 
		inside_sword = true
	if area.is_in_group("Arrow"):
		take_damage()
	elif area.is_in_group("InstaDeath"): health = 0

func _on_area_3d_area_exited(area):
	if area.is_in_group("PlayerSword"): 
		inside_sword = false


func death() -> void:
	if health <= 0: 
		get_parent().get_tree().call_group("KD", "kill_confirmed")
		var ragdoll = preload("res://Objects/DemoEnemy/dead_demo_enemy.tscn").instantiate()
		add_sibling(ragdoll)
		ragdoll.global_transform.origin = global_transform.origin
		queue_free()

func _on_attack_area_area_entered(area) -> void:
	if area.is_in_group("Player"): 
		if pacified:
			pacified = false
			nav.target_position = player_pos
		if able_to_lunge: lunging = true
		else:
			attacking = true
			swinging = true

func _on_lunge_timer_timeout() -> void:
	swing_audio.play(0.3)
	lunge_timer.stop()
	boost_applied = false
	lunging = false
	attacking = true
	swinging = true


func _on_pacification_timer_timeout() -> void:
	if randi_range(10 - health, 100) > 50: 
		pacified = true
		var time : int = 1
		time += 10 - health + randi_range(0, 5)
		pacification_timer.start(time)
	else: 
		pacified = false
		pacification_timer.start(15)


func _on_invincibility_timer_timeout() -> void:
	invincible = false

func _on_gpu_particles_3d_finished() -> void:
	splat_ready = true
