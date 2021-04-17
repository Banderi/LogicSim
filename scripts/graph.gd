extends ColorRect

export(float, 0.5, 10) var zoom_x = 2
export(float, 0.5, 10) var zoom_y = 1

var points = []

var probing = null

func attach(p):
	probing = p

func read(v):
	var p = v - 2*v
	$Label2.text = str(stepify(v,0.01))
	$Label2.rect_position = Vector2(500, p + 100)
	points.push_front(p)
	while points.size() > (rect_size.x) / zoom_x + 2:
		points.pop_back()

func _draw():

	# draw graph container/grid
	draw_line(Vector2(0,0), Vector2(500,0), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,0), Vector2(500,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,200), Vector2(0,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,200), Vector2(0,0), Color(0.4, 0.55, 0.8), 1)

	draw_line(Vector2(250,0), Vector2(250,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,100), Vector2(500,100), Color(0.4, 0.55, 0.8), 1)

	var x = rect_size.x
	var y = rect_size.y
	for i in range(0, points.size() - 2, 1):
		var s = i * zoom_x
		draw_line(
			Vector2(x-s, zoom_y * points[i] + y/2),
			Vector2(x-(s + zoom_x), zoom_y * points[i + 1] + y/2),
			Color(1, 0, 0), 1)

func refresh_probes():
	if probing:
		read(probing.tension)
		$Label.text = "Probing: " + str(probing)
		for t in probing.tension_neighbors:
			$Label.text += "\n" + str(t[0]) + " > " + str(stepify(t[1],0.01))
	else:
		$Label.text = "Probing: (nothing)"
		read(0)

	update()
	print(str(self) + " (graph) : refresh_probes")

func _ready():
	for p in range(0,1000):
		points.push_front(0)
	add_to_group("graph")
