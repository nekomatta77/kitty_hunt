extends Control

var max_health = 100.0
var current_health = 100.0
var segments = 10 # Количество делений
var segment_gap = 4 # Расстояние между делениями (пиксели)

func set_health(hp):
	current_health = hp
	queue_redraw() # Даем команду перерисовать интерфейс

func _draw():
	# Вычисляем ширину одного отсека
	var seg_width = (size.x - (segments - 1) * segment_gap) / float(segments)
	
	for i in range(segments):
		var x_pos = i * (seg_width + segment_gap)
		var rect = Rect2(x_pos, 0, seg_width, size.y)
		
		# 1. Задний фон (пустой отсек, полупрозрачный черный)
		draw_rect(rect, Color(0.1, 0.1, 0.1, 0.7))
		
		# 2. Вычисляем, сколько здоровья в этом конкретном отсеке
		var hp_per_segment = max_health / segments
		var hp_for_this_segment = current_health - (i * hp_per_segment)
		var fill_ratio = clamp(hp_for_this_segment / hp_per_segment, 0.0, 1.0)
		
		# 3. Рисуем заливку
		if fill_ratio > 0:
			var fill_rect = Rect2(x_pos, 0, seg_width * fill_ratio, size.y)
			
			# Динамический цвет
			var color = Color(0.2, 0.8, 0.2) # Зеленый (Full)
			if current_health <= 50: color = Color(0.8, 0.8, 0.2) # Желтый (Medium)
			if current_health <= 25: color = Color(0.9, 0.2, 0.2) # Красный (Low)
			
			draw_rect(fill_rect, color)
		
		# 4. Красивая рамка вокруг каждого отсека
		draw_rect(rect, Color(0, 0, 0, 1), false, 2.0)
