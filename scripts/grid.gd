extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

var center = Vector2(500, 500)

func _draw():
#	if logic.main.selection_mode & 1:

#	var o = center + OS.window_size/2 - logic.main.camera.position

	var cam = logic.main.camera.position
	var z = logic.main.camera.zoom

	var pos_x =  center + Vector2(cam.x - center.x, 0)
	var pos_y =  center + Vector2(0, cam.y - center.y)
	var offset_x = Vector2(OS.window_size.x / 2, 0) * z
	var offset_y = Vector2(0, OS.window_size.y / 2) * z

	# horizontal lines
	for i in range (-1000, 1000):
		var y = Vector2(0, i * 50)
		draw_line(pos_x - offset_x + y, pos_x + offset_x + y, Color(0.2, 0.33, 0.78, 0.5))

	# vertical lines
	for i in range (-1000, 1000):
		var x = Vector2(i * 50, 0)
		draw_line(pos_y - offset_y + x, pos_y + offset_y + x, Color(0.2, 0.33, 0.78, 0.5))
