extends ColorRect

export(float, 0.5, 10) var zoom_x = 3.2
export(float, 0.5, 10) var zoom_y = 0.6

var max_x = rect_size.x
var max_y = rect_size.y

var max_x_reach = 10000
var max_y_reach = 10000

var data = []

var probing = null
var probing_type = -1

func debugger_log_clear():
	if probing == null:
		return
	DebugLogger.clearme(probing)
	DebugLogger.logme(probing, [
		probing.get_name(), Color(1,1,1),
		" (" + str(probing) + ")", Color(0.65,0.65,0.65)
	])

func attach(p, t):
	if probing == p:
		return
	data = []
	probing = p
	probing_type = t
	refresh_probes()

	logic.main.update_node_settings_enabled = false
	if probing == null:
		logic.main.node_options.root.visible = false
	else:
		for m in logic.main.node_options:
			var d = logic.main.node_options[m]
			if m in probing:
				d.visible = true
				if d is SpinBox:
					var mm = probing.get(m)
					if str(mm) == "inf":
						d.editable = false
					else:
						d.editable = true
						d.value = probing.get(m)
				elif d is CheckBox:
					d.pressed = probing.get(m)
			else:
				d.visible = false
		logic.main.node_options.root.visible = true
		logic.main.node_options.vbox.visible = true
		logic.main.node_options.name.visible = true
		logic.main.node_options.name.text = probing.get_name()

#		logic.main.node_options.tension_static.editable = logic.main.node_options.is_source.pressed
#		if "tension" in probing:
#			logic.main.node_options.tension.visible = true
#			logic.main.node_options.tension.value = probing.tension_static
#		if "is_source" in probing:
#			logic.main.node_options.is_source.visible = true
#			logic.main.node_options.is_source.pressed = probing.is_source
	logic.main.update_node_settings_enabled = true
func detach():
	probing = null
	probing_type = null
	logic.main.node_options.root.visible = false
	DebugLogger.clear()

var label_n = 9
func read(v, TICK, nam, u, col, absol = false, rectify = 1.0):
	# get set from data by name
	var set = {
		"name":nam,
		"color":col,
		"unit":u,
		"absolute":absol,
		"rectify":rectify,
		"points":[],
		"tick_cache":[],
	}
	var found = false
	for s in data:
		if s["name"] == nam:
			set = s
			found = true
			s["rectify"] = rectify
			break
	if !found:
		data.append(set)

	# add value to cache FIRST
	var cache = set["tick_cache"]
	cache.push_front(v)

	# if not a TICK update, discard point - just add to the caches
	if !TICK:
		return

	# else, retrieve the final value from the cache!
	for cv in cache:
		if str(v) != "inf" && str(v) != "-inf" && str(cv) != "inf" && str(cv) != "-inf":
			if abs(cv) > abs(v):
				v = cv
		else:
			pass
	cache.clear()

	var points = set["points"]
	var l = $Labels.get_child(label_n)

	# add datapoints to set
	var text_p = 0
	if str(v) == "inf":
		text_p = 9999
		l.text = "inf"
		points.push_front("inf")
	elif str(v) == "-inf":
		text_p = -9999
		l.text = "-inf"
		if absol:
			text_p = 9999
			l.text = "inf"
		points.push_front("-inf")
	else:
		text_p = v * rectify
		if absol:
			text_p = abs(text_p)
		l.text = str(stepify((text_p / rectify), 0.0001))
		points.push_front(v * rectify)

	while points.size() > max_x_reach:
		points.pop_back()

	# update labels
	l.rect_position = Vector2(max_x + 4, clamp(max_y/2 - zoom_y * text_p - 10, 0, max_y - 10))
	l.visible = true
	l.modulate.a = float(1)/float(9-label_n+1)
	label_n -= 1

func draw_points(set):
	var col = set["color"]
	var points = set["points"]
	for i in range(0, min(points.size() - 2, (2 * max_x / zoom_x) + 1), 1):
		var p1_x = max(max_x - (zoom_x * logic.simulation_speed) * i, 0)
		var p2_x = max(max_x - (zoom_x * logic.simulation_speed) * (i + 1), 0)

		var p = points[i]
		var p2 = points[i + 1]
		p = -9999 if str(p) == "inf" else (9999 if str(p) == "-inf" else -p)
		p2 = -9999 if str(p2) == "inf" else (9999 if str(p2) == "-inf" else -p2)

		if set["absolute"]:
			p = -abs(p)
			p2 = -abs(p2)

		var p1_y = clamp(max_y/2 + zoom_y * p, -1, max_y + 1)
		var p2_y = clamp(max_y/2 + zoom_y * p2, -1, max_y + 1)

		if (p1_y < 0 && p2_y < 0) || (p1_y > max_y && p2_y > max_y):
			pass
		else:
			draw_line(
				Vector2(p1_x, p1_y),
				Vector2(p2_x, p2_y),
				col, 1)

var min_zoom_x = 3.2 # until better optimised....
var min_zoom_y = 0.125
var max_zoom_x = 32
var max_zoom_y = 32
func zoom_hor(z, parent):
	if z < 0:
		zoom_x *= 0.625
	if z > 0:
		zoom_x *= 1.6
	zoom_x = stepify(clamp(zoom_x, min_zoom_x, max_zoom_x), 0.1)
	update()
	parent.update()
func zoom_ver(z, parent):
	if z < 0:
		zoom_y *= 0.625
	if z > 0:
		zoom_y *= 1.6
	zoom_y = stepify(clamp(zoom_y, min_zoom_y, max_zoom_y), 0.1)
	update()
	parent.update()

var div_t = 0
var div_split_x = 50
var div_split_y = 100
func _draw():
	max_x = rect_size.x
	max_y = rect_size.y

	# draw graph container/grid
	draw_line(Vector2(0,0), Vector2(max_x,0), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(max_x,0), Vector2(max_x,max_y), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(max_x,max_y), Vector2(0,max_y), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,max_y), Vector2(0,0), Color(0.4, 0.55, 0.8), 1)

	# half grid lines
	draw_line(Vector2(max_x/2,0), Vector2(max_x/2,max_y), Color(0.4, 0.55, 0.8), 1)
	draw_line(Vector2(0,max_y/2), Vector2(max_x,max_y/2), Color(0.4, 0.55, 0.8), 1)

	# scrolling divider lines
	for l in range(0, max_x_reach / div_split_x):
		var lx = rect_size.x - zoom_x * (l * div_split_x + div_t)
		if lx > 0 && lx < max_x:
			draw_line(Vector2(lx, 0), Vector2(lx, max_y), Color(0.4, 0.55, 0.8, 0.5), 1)

	# horizontal divider lines
	for l in range(1, max_y_reach / (div_split_y * 2)):
		var ly = zoom_y * (div_split_y * l) # start from center line!
		if ly > 0 && ly < (max_y / 2):
			draw_line(Vector2(0, (max_y / 2) - ly), Vector2(max_x, (max_y / 2) - ly), Color(0.4, 0.55, 0.8, 0.5), 1)
			draw_line(Vector2(0, (max_y / 2) + ly), Vector2(max_x, (max_y / 2) + ly), Color(0.4, 0.55, 0.8, 0.5), 1)

	for s in range(0, data.size()):
		var set = data[data.size() - s - 1]
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
				if probing.is_source:
					$L/Label.append_bbcode("\nTension source (" + str(probing.tension_static) + ")")
				else:
					$L/Label.append_bbcode("\nWire junction")
				read(probing.tension, tick, "Tension", "Volts", Color(1, 0, 0))
				read(probing.charge_stored, tick, "Charge", "Coulombs", Color(0, 1, 0))
			1:
				$L/Label.append_bbcode("\nA-B connection")
				read(probing.current, tick, "Current", "Amps", Color(1, 1, 0), true) # 500.0
				read(probing.voltage, tick, "Voltage", "Volts", Color(1, 0, 0))
				read(probing.resistance, tick, "Resistance", "Ohms", Color(1, 0.5, 0))
				read(probing.conductance, tick, "Conductance", "Siemens", Color(0, 1, 1))

		$L/Label.append_bbcode("\n")
		for set in data:
			$L/Label.push_color(set["color"])
			$L/Label.append_bbcode("\n" + set["name"] + ": ")
			$L/Label.pop()
			$L/Label.append_bbcode(logic.proper(set["points"][0], set["unit"], true, true, set["rectify"], 0.0001, set["absolute"]))
	else:
		$L/Label.append_bbcode("Probing: (nothing)")

	# update divider lines tick
	if tick:
		div_t += 1 * logic.simulation_speed
		while div_t > div_split_x:
			div_t -= div_split_x
	update()

func _ready():
	logic.probe = self
	add_to_group("graph")
