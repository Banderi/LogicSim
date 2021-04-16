extends ColorRect

export(float, 100, 1000) var zoom_x = 200
export(float, 100, 1000) var zoom_y = 200

var points = []

var probing = null

func attach(p):
#	probing = null
#	if probing == null:
	probing = p
#	return

func read(v):
	points.push_front(v)

	if points.size() > 1000:
		points.pop_back()

func _draw():

	var x = rect_size.x
	var y = rect_size.y
	for i in range(0, points.size() - 2, 1):
		draw_line(Vector2(x-i, points[i] + y/2), Vector2(x-(i + 1), points[i + 1] + y/2), Color(255, 0, 0), 1)

#	draw_line(Vector2(0,0), Vector2(0, -50), Color(255, 0, 0), 1)

func _process(delta):
	$Label.text = "Probing: " + str(probing)
	if probing:
		read(probing.tension)

	update()
