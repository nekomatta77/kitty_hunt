extends Control

var max_health: float = 100.0
var current_health: float = 100.0
var displayed_health: float = 100.0 # Для плавной анимации получения урона
var font: Font

func _ready():
	font = ThemeDB.fallback_font # Стандартный шрифт Godot
	# Убедимся, что размеры не нулевые (если Control сжат)
	if size.x == 0: size.x = 300
	if size.y == 0: size.y = 30

func set_health(hp: float):
	current_health = clamp(float(hp), 0.0, max_health)
	
	# Создаем плавную анимацию (Tween) для эффекта отстающего красного следа
	var tween = create_tween()
	tween.tween_property(self, "displayed_health", current_health, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Сразу форсируем перерисовку текста и основы
	queue_redraw()

func _process(_delta):
	# Заставляем перерисовываться каждый кадр, пока идет анимация урона
	if abs(displayed_health - current_health) > 0.01:
		queue_redraw()

func _draw():
	if size.x == 0 or size.y == 0: return

	# 1. Задний фон (темно-сине-серый)
	var bg_box = StyleBoxFlat.new()
	bg_box.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	bg_box.set_corner_radius_all(10) # Красивые скругленные углы
	draw_style_box(bg_box, Rect2(0, 0, size.x, size.y))

	# 2. "Призрак" урона (Красный след, который плавно тает)
	if displayed_health > 0:
		var ghost_width = (displayed_health / max_health) * size.x
		var ghost_box = StyleBoxFlat.new()
		ghost_box.bg_color = Color(0.8, 0.2, 0.2, 0.8) # Мягкий красный
		ghost_box.set_corner_radius_all(10)
		draw_style_box(ghost_box, Rect2(0, 0, ghost_width, size.y))

	# 3. Основная полоса ХП
	if current_health > 0:
		var hp_width = (current_health / max_health) * size.x
		var hp_box = StyleBoxFlat.new()
		
		# Плавная смена цвета в зависимости от количества жизней
		if current_health > 60:
			hp_box.bg_color = Color(0.2, 0.8, 0.3, 1.0) # Зеленый (Full)
		elif current_health > 30:
			hp_box.bg_color = Color(0.9, 0.7, 0.1, 1.0) # Желтый/Оранжевый (Warning)
		else:
			hp_box.bg_color = Color(0.8, 0.1, 0.1, 1.0) # Темно-красный (Critical)
			
		hp_box.set_corner_radius_all(10)
		draw_style_box(hp_box, Rect2(0, 0, hp_width, size.y))

	# 4. Внешняя блестящая рамка
	var border_box = StyleBoxFlat.new()
	border_box.bg_color = Color(0, 0, 0, 0) # Прозрачный центр
	border_box.border_color = Color(0.8, 0.8, 0.8, 0.5)
	border_box.set_border_width_all(2)
	border_box.set_corner_radius_all(10)
	draw_style_box(border_box, Rect2(0, 0, size.x, size.y))
	
	# 5. Текст по центру полоски (например: "75 / 100")
	if font:
		var text = str(int(current_health)) + " / " + str(int(max_health))
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		# Центрируем текст математически
		var text_pos = Vector2((size.x - text_size.x) / 2, (size.y + text_size.y) / 2 - 4)
		
		# Рисуем черную тень для текста, чтобы он читался на любом фоне
		draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.BLACK)
		# Рисуем сам текст
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)
