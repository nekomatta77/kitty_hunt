extends Control

var is_mobile = false

# Настройки джойстика
var joy_base_pos = Vector2()
var joy_stick_pos = Vector2()
var joy_radius = 80.0
var joy_touch_id = -1
var joy_vector = Vector2.ZERO

# Настройки кнопок
var jump_pos = Vector2()
var action_pos = Vector2()
var btn_radius = 55.0
var jump_touch_id = -1
var action_touch_id = -1

func _ready():
	# Если хочешь, чтобы интерфейс скрывался на ПК, раскомментируй hide()
	if not OS.has_feature("mobile") and not OS.has_feature("web_android") and not OS.has_feature("web_ios"):
		pass # hide() 
		
	update_positions()
	get_tree().get_root().size_changed.connect(update_positions)

# Адаптация под размер экрана
func update_positions():
	var screen_size = get_viewport_rect().size
	
	# Джойстик слева внизу
	joy_base_pos = Vector2(160, screen_size.y - 160)
	joy_stick_pos = joy_base_pos
	
	# Кнопки справа внизу
	jump_pos = Vector2(screen_size.x - 140, screen_size.y - 140)
	action_pos = Vector2(screen_size.x - 280, screen_size.y - 200)
	queue_redraw()

func _input(event):
	if not visible: return
	
	var handled = false
	
	if event is InputEventScreenTouch:
		if event.pressed:
			# Попали в джойстик?
			if event.position.distance_to(joy_base_pos) < joy_radius * 2.0:
				joy_touch_id = event.index
				update_joystick(event.position)
				handled = true
			# Попали в кнопку прыжка?
			elif event.position.distance_to(jump_pos) < btn_radius * 1.5:
				jump_touch_id = event.index
				Input.action_press("ui_accept")
				handled = true
			# Попали в кнопку действия (Стрельба/Превращение)?
			elif event.position.distance_to(action_pos) < btn_radius * 1.5:
				action_touch_id = event.index
				trigger_action()
				handled = true
		else:
			# Отпустили палец
			if event.index == joy_touch_id:
				joy_touch_id = -1
				joy_stick_pos = joy_base_pos
				joy_vector = Vector2.ZERO
				simulate_joystick_input()
				handled = true
			elif event.index == jump_touch_id:
				jump_touch_id = -1
				Input.action_release("ui_accept")
				handled = true
			elif event.index == action_touch_id:
				action_touch_id = -1
				handled = true
				
		if handled:
			get_viewport().set_input_as_handled()
			queue_redraw()
			
	elif event is InputEventScreenDrag:
		if event.index == joy_touch_id:
			update_joystick(event.position)
			handled = true
		elif event.index == jump_touch_id or event.index == action_touch_id:
			handled = true # Глушим свайп, чтобы камера не дергалась
			
		if handled:
			get_viewport().set_input_as_handled()

func update_joystick(pos: Vector2):
	var dir = pos - joy_base_pos
	if dir.length() > joy_radius:
		dir = dir.normalized() * joy_radius
	joy_stick_pos = joy_base_pos + dir
	
	joy_vector = dir / joy_radius
	simulate_joystick_input()
	queue_redraw()

func simulate_joystick_input():
	if joy_vector.x < -0.2: Input.action_press("ui_left")
	else: Input.action_release("ui_left")
	
	if joy_vector.x > 0.2: Input.action_press("ui_right")
	else: Input.action_release("ui_right")
	
	if joy_vector.y < -0.2: Input.action_press("ui_up")
	else: Input.action_release("ui_up")
	
	if joy_vector.y > 0.2: Input.action_press("ui_down")
	else: Input.action_release("ui_down")

func trigger_action():
	var player = get_parent().get_parent() # Добираемся до логики Охотника/Пропа
	if player:
		if player.has_method("shoot"):
			player.shoot()
		elif player.has_method("try_transform"):
			player.try_transform()

func _draw():
	# Отрисовка базы джойстика
	draw_circle(joy_base_pos, joy_radius, Color(0, 0, 0, 0.3))
	# Отрисовка стика (ярче, когда нажат)
	var stick_alpha = 0.8 if joy_touch_id != -1 else 0.5
	draw_circle(joy_stick_pos, joy_radius * 0.4, Color(1, 1, 1, stick_alpha))
	
	# Кнопка Прыжка (Зеленоватая)
	var jump_alpha = 0.8 if jump_touch_id != -1 else 0.4
	draw_circle(jump_pos, btn_radius, Color(0.2, 0.8, 0.4, jump_alpha))
	
	# Кнопка Действия (Красная для Охотника, Фиолетовая для Пропа)
	var action_alpha = 0.8 if action_touch_id != -1 else 0.4
	var action_color = Color(0.9, 0.2, 0.2, action_alpha) # Красный по умолчанию
	
	var player = get_parent().get_parent()
	if player and player.has_method("try_transform"):
		action_color = Color(0.6, 0.2, 0.9, action_alpha) # Фиолетовый
		
	draw_circle(action_pos, btn_radius, action_color)
