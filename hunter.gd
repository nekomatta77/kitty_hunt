extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var mouse_sensitivity = 0.002
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var health = 100.0 

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var mobile_ui = $MobileUI

var health_bar = null

func _ready():
	raycast.add_exception(self)
	
	for child in mobile_ui.get_children():
		if child.has_method("set_health"):
			health_bar = child
			break
	
	if is_multiplayer_authority():
		camera.current = true
		mobile_ui.show()
		if health_bar:
			health_bar.set_health(health)
	else:
		mobile_ui.hide()

func _enter_tree():
	var id = name.to_int()
	if id == 0: id = 1 
	set_multiplayer_authority(id)

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
		
	var is_valid_drag = false
	if event is InputEventMouseMotion:
		is_valid_drag = true
	elif event is InputEventScreenDrag:
		if event.position.x > get_viewport().size.x / 2.0:
			is_valid_drag = true

	if is_valid_drag:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		shoot()

func shoot():
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var target = raycast.get_collider()
		if target.has_method("receive_damage"):
			target.rpc("receive_damage", 25.0)
		else:
			rpc("receive_damage", 10.0)
	else:
		rpc("receive_damage", 10.0)

func _physics_process(delta):
	if not is_multiplayer_authority(): return 

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY

	var h_axis = int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	if h_axis == 0: h_axis = Input.get_axis("ui_left", "ui_right")
	
	var v_axis = int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	if v_axis == 0: v_axis = Input.get_axis("ui_up", "ui_down")

	var input_dir = Vector2(h_axis, v_axis).normalized()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

@rpc("any_peer", "call_local", "reliable")
func receive_damage(amount: float):
	if is_multiplayer_authority():
		health -= amount
		if health_bar: health_bar.set_health(health)
		
		if health <= 0:
			rpc("die_rpc")
		else:
			rpc("sync_health", health)

@rpc("authority", "call_remote", "reliable")
func sync_health(new_health: float):
	health = new_health

@rpc("authority", "call_local", "reliable")
func die_rpc():
	queue_free()
	
	# === ВАЖНО: Если охотник умер - пропы досрочно победили ===
	if multiplayer.is_server():
		var level = get_node_or_null("/root/Level")
		if level and level.has_method("show_game_over"):
			level.rpc("show_game_over", false)
