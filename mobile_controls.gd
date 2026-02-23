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
	if not OS.has_feature("mobile") and not OS.has_feature("web_android") and not OS.has_feature("web_ios"):
		pass # Оставлено для удобства тестирования на ПК
		
	update_positions()
	get_tree().get_root().size_changed.connect(update_positions)

func update_positions():
	var screen_size = get_viewport_rect().size
	
	joy_base_pos = Vector2(160, screen_size.y - 160)
	joy_stick_pos = joy_base_pos
	
	jump_pos = Vector2(screen_size.x - 140, screen_size.y - 140)
	# Немного опустили кнопку выстрела, чтобы она была на одной линии с прыжком
	action_pos = Vector2(screen_size.x - 280, screen_size.y - 140) 
	queue_redraw()

# ПУЛЕНЕПРОБИВАЕМЫЙ ПОИСК ИГРОКА
func _get_player():
	var p = get_parent()
	while p != null:
		if p is CharacterBody3D:
			return p
		p = p.get_parent()
	return null

func _input(event):
	if not visible: return
	
	var handled = false
	
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(joy_base_pos) < joy_radius * 2.0:
				joy_touch_id = event.index
				update_joystick(event.position)
				handled = true
			elif event.position.distance_to(jump_pos) < btn_radius * 1.5:
				jump_touch_id = event.index
				Input.action_press("ui_accept")
				handled = true
			elif event.position.distance_to(action_pos) < btn_radius * 1.5:
				action_touch_id = event.index
				trigger_action()
				handled = true
		else:
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
			handled = true 
			
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
	var player = _get_player()
	if player:
		if player.has_method("shoot"):
			player.shoot()
		elif player.has_method("try_transform"):
			player.try_transform()

func _draw():
	# Отрисовка джойстика
	draw_circle(joy_base_pos, joy_radius, Color(0, 0, 0, 0.3))
	var stick_alpha = 0.8 if joy_touch_id != -1 else 0.5
	draw_circle(joy_stick_pos, joy_radius * 0.4, Color(1, 1, 1, stick_alpha))
	
	# Отрисовка кнопки прыжка
	var jump_alpha = 0.8 if jump_touch_id != -1 else 0.4
	draw_circle(jump_pos, btn_radius, Color(0.2, 0.6, 0.9, jump_alpha))
	
	# Отрисовка кнопки действия
	var action_alpha = 0.8 if action_touch_id != -1 else 0.4
	var player = _get_player()
	
	var is_hunter = false
	var action_color = Color(0.4, 0.4, 0.4, action_alpha) # Серый (дефолтный на случай ошибки)
	
	# Определяем роль и цвет
	if player:
		if player.has_method("shoot"):
			is_hunter = true
			action_color = Color(0.9, 0.2, 0.2, action_alpha) # Красная (для охотника)
		elif player.has_method("try_transform"):
			action_color = Color(0.6, 0.2, 0.9, action_alpha) # Фиолетовая (для пропа)
			
	draw_circle(action_pos, btn_radius, action_color)
	
	# Рисуем иконку прицела, если это охотник
	if is_hunter:
		var icon_col = Color(1, 1, 1, action_alpha)
		var center = action_pos
		
		# Внешняя окружность прицела
		draw_arc(center, btn_radius * 0.45, 0, TAU, 32, icon_col, 3.0, true)
		
		# Настройки линий перекрестия
		var line_len = btn_radius * 0.65
		var gap = btn_radius * 0.2
		
		# Верхняя линия
		draw_line(center - Vector2(0, gap), center - Vector2(0, line_len), icon_col, 3.0, true)
		# Нижняя линия
		draw_line(center + Vector2(0, gap), center + Vector2(0, line_len), icon_col, 3.0, true)
		# Левая линия
		draw_line(center - Vector2(gap, 0), center - Vector2(line_len, 0), icon_col, 3.0, true)
		# Правая линия
		draw_line(center + Vector2(gap, 0), center + Vector2(line_len, 0), icon_col, 3.0, true)
		
		# Точка в самом центре
		draw_circle(center, 2.5, icon_col)
