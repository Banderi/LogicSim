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
	refresh_probes(false)

var label_n = 9
func read(v, nam, u, col, absol = false, rectify = 1.0):
	# get set from data by name
	var set = {
		"name":nam,
		"color":col,
		"unit":u,
		"absolute":absol,
		"rectify":rectify,
		"points":[],
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
	v *= rectify
	if absol:
		v = -v
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
	l.text = logic.proper(v, "", false, false, rectify)
	l.rect_position = Vector2(504, clamp(p + 100 - 10,0,190))
	l.visible = true
#	l.modulate = col
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

var div_t = 0
var div_split = 50
func _draw():

	# draw graph container/grid
	draw_line(Vector2(0,0), Vector2(500,0), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,0), Vector2(500,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(500,200), Vector2(0,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,200), Vector2(0,0), Color(0.4, 0.55, 0.8), 1)

	draw_line(Vector2(250,0), Vector2(250,200), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,100), Vector2(500,100), Color(0.4, 0.55, 0.8), 1)

	# scrolling divider lines
	for l in range(0, 1000/div_split):
		var lx = rect_size.x - zoom_x * (l * div_split + div_t)
		if lx > 0 && lx < 500:
			draw_line(Vector2(lx,0), Vector2(lx,200), Color(0.4, 0.55, 0.8), 1)

	for set in data:
		draw_points(set)

func refresh_probes(tick = true):
	# reset labels
	for l in range(0,10):
		$Labels.get_child(l).visible = false
	label_n = 9

	# read data from attached nodes
	$L/Label.clear()
	if probing:
		$L/Label.append_bbcode("Probing: " + str(probing))
		match probing_type:
			0:
				read(probing.tension, "Tension", "Volts", Color(1, 0, 0))
			1:
				read(probing.voltage, "Voltage", "Volts", Color(1, 0, 0))
				read(probing.current, "Current", "Amps", Color(1, 1, 0), true, 1000)
				read(probing.conductance, "Conductance", "Siemens", Color(0, 1, 1))
				read(probing.resistance, "Resistance", "Ohms", Color(1, 0.5, 0))

		$L/Label.append_bbcode("\n")
		for set in data:
			$L/Label.push_color(set["color"])
			$L/Label.append_bbcode("\n" + set["name"] + ": ")
			$L/Label.pop()
			$L/Label.append_bbcode(logic.proper(-set["points"][0], set["unit"], true, true, set["rectify"], 0.01))
	else:
		$L/Label.append_bbcode("Probing: (nothing)")

	# update divider lines tick
	if tick:
		div_t += 1
		if div_t > div_split:
			div_t -= div_split
	update()

func _ready():
	logic.probe = self
	add_to_group("graph")
