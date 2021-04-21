extends ColorRect

export(float, 0.5, 10) var zoom_x = 2
export(float, 0.5, 10) var zoom_y = 1

var data = []

var probing = null
var probing_type = -1

func attach(p, t):
	data = []
	probing = p
	probing_type = t

var label_n = 9
func read(v, nam, u, col):
	# get set from data by name
	var set = {
		"name":nam,
		"color":col,
		"unit":u,
		"points":[]
	}
	var found = false
	for s in data:
		if s["name"] == nam:
			set = s
			found = true
			break
	if !found:
		data.append(set)

	var points = set["points"]

	# add datapoints to set
	var p = 0
	if str(v) == "inf":
		points.push_front(v)
	else:
		p = v - 2*v
		points.push_front(p)
	while points.size() > (rect_size.x) / zoom_x + 2:
		points.pop_back()

	# update labels
	var l = $Labels.get_child(label_n)
	l.text = str(stepify(v,0.01)) # + " " + set["unit"]
	l.rect_position = Vector2(504, clamp(p + 100 - 10,0,190))
	l.visible = true
	l.modulate.a = float(1)/float(9-label_n+1)
	label_n -= 1

func draw_points(set):
	var col = set["color"]
	var points = set["points"]
	var x = rect_size.x
	var y = rect_size.y
	for i in range(0, points.size() - 2, 1):
		var p1_x = x - zoom_x * i
		var p2_x = x - zoom_x * (i + 1)

		var p1_y = zoom_y * clamp(points[i], -101, 101) + y/2
		var p2_y = zoom_y * clamp(points[i + 1], -101, 101) + y/2

		if (points[i] < -100 && points[i + 1] < -100) || (points[i] > 100 && points[i + 1] > 100):
			pass
		else:
			draw_line(
				Vector2(p1_x, p1_y),
				Vector2(p2_x, p2_y),
				col, 1)

func _draw():

	# draw graph container/grid
	draw_line(Vector2(0,0), Vector2(500,0), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,0), Vector2(500,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,200), Vector2(0,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,200), Vector2(0,0), Color(0.4, 0.55, 0.8), 1)

	draw_line(Vector2(250,0), Vector2(250,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,100), Vector2(500,100), Color(0.4, 0.55, 0.8), 1)

	for set in data:
		draw_points(set)

func refresh_probes():
	# reset labels
	for l in range(0,10):
		$Labels.get_child(l).visible = false
	label_n = 9

	if probing:
		$L/Label.text = "Probing: " + str(probing)
		match probing_type:
			0:
				read(probing.tension, "Tension", "Volts", Color(1, 0, 0))
			1:
				read(probing.voltage, "Voltage", "Volts", Color(1, 0, 0))
				read(abs(probing.current * 1000), "Current", "mAmps", Color(1, 1, 0))
				read(probing.conductance, "Conductance", "Siemens", Color(0, 1, 1))
				read(probing.resistance, "Resistance", "Ohms", Color(0, 1, 1))

		for set in data:
			$L/Label.text += "\n" + set["name"] + ": " + str(-set["points"][0]) + " " + set["unit"]
	else:
		$L/Label.text = "Probing: (nothing)"

	update()

func _ready():
	logic.probe = self
	add_to_group("graph")
