extends ColorRect

export(float, 0.5, 10) var zoom_x = 2
export(float, 0.5, 10) var zoom_y = 1

var voltage_points = []
var sap_points = []

var probing = null

func attach(p):
	probing = p

var label_n = 0
func read(v, set):
	# add datapoints to set
	var p = v - 2*v
	set.push_front(p)
	while set.size() > (rect_size.x) / zoom_x + 2:
		set.pop_back()

	# update labels
	var l = $Labels.get_child(label_n)
	l.text = str(stepify(v,0.01))
	l.rect_position = Vector2(500, p + 100)
	l.visible = true
	l.modulate.a = float(1)/float(label_n+1)
	label_n += 1

func draw_points(set, color):
	var x = rect_size.x
	var y = rect_size.y
	for i in range(0, set.size() - 2, 1):
		var s = i * zoom_x
		draw_line(
			Vector2(x-s, zoom_y * set[i] + y/2),
			Vector2(x-(s + zoom_x), zoom_y * set[i + 1] + y/2),
			color, 1)

func _draw():

	# draw graph container/grid
	draw_line(Vector2(0,0), Vector2(500,0), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,0), Vector2(500,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,200), Vector2(0,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,200), Vector2(0,0), Color(0.4, 0.55, 0.8), 1)

	draw_line(Vector2(250,0), Vector2(250,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,100), Vector2(500,100), Color(0.4, 0.55, 0.8), 1)

	draw_points(sap_points, Color(0, 0, 1))
	draw_points(voltage_points, Color(1, 0, 0))

func refresh_probes():
	# reset labels
	for l in range(0,10):
		$Labels.get_child(l).visible = false
	label_n = 0

	if probing:
		read(probing.oldtension, voltage_points)
		read(probing.tension, sap_points)
		$Label.text = "Probing: " + str(probing)
		for t in probing.tension_neighbors:
			$Label.text += "\n" + str(t[0]) + " > " + str(stepify(t[1],0.01))
	else:
		$Label.text = "Probing: (nothing)"
		read(0, voltage_points)
		read(0, sap_points)

	update()
	print(str(self) + " (graph) : refresh_probes")

func _ready():
	for p in range(0,1000):
		voltage_points.push_front(0)
		sap_points.push_front(0)
	add_to_group("graph")
