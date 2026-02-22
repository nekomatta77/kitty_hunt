extends Control

var max_health = 100.0
var current_health = 100.0
var segments = 10 
var segment_gap = 4 

func set_health(hp):
	# 🔥 ФИКС: Принудительно конвертируем входящее значение во float (дробное)
	# чтобы математика делений в _draw() не ломалась об целые числа
	current_health = float(hp)
	queue_redraw() 

func _draw():
	if segments <= 0 or size.x <= 0: return # Защита от ошибок отрисовки
	
	var seg_width = (size.x - (segments - 1) * segment_gap) / float(segments)
	
	for i in range(segments):
		var x_pos = i * (seg_width + segment_gap)
		var rect = Rect2(x_pos, 0, seg_width, size.y)
		
		draw_rect(rect, Color(0.1, 0.1, 0.1, 0.7))
		
		var hp_per_segment = max_health / float(segments)
		var hp_for_this_segment = current_health - (i * hp_per_segment)
		var fill_ratio = clamp(hp_for_this_segment / hp_per_segment, 0.0, 1.0)
		
		if fill_ratio > 0:
			var fill_rect = Rect2(x_pos, 0, seg_width * fill_ratio, size.y)
			var color = Color(0.2, 0.8, 0.2) 
			if current_health <= 50.0: color = Color(0.8, 0.8, 0.2) 
			if current_health <= 25.0: color = Color(0.9, 0.2, 0.2) 
			draw_rect(fill_rect, color)
		
		draw_rect(rect, Color(0, 0, 0, 1), false, 2.0)
