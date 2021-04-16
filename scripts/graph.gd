extends ColorRect

export(float, 0.5, 10) var zoom_x = 6
export(float, 0.5, 10) var zoom_y = 1

var points = []

var probing = null

func attach(p):
	probing = p

func read(v):
	points.push_front(v)

	if points.size() > (rect_size.x + 1) / zoom_x:
		points.pop_back()

func _draw():

	var x = rect_size.x
	var y = rect_size.y
	for i in range(0, points.size() - 2, 1):
		var s = i * zoom_x
		draw_line(
			Vector2(x-s, zoom_y * points[i] + y/2),
			Vector2(x-(s + zoom_x), zoom_y * points[i + 1] + y/2),
			Color(255, 0, 0), 1)
		if float(i - 1) / zoom_x > (rect_size.x) / zoom_x:
			return

func _process(delta):
	$Label.text = "Probing: " + str(probing)
	if probing:
		read(probing.tension)

	update()
