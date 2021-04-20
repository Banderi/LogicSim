extends Line2D

var orig_pin = null
var dest_pin = null
#var dest_circuit = null
#var dest_pin_slot = 0

#var speed = 40.0
var voltage = 0.0
var current = 0.0

var resistivity = 0.01
var area = 1.0
var length = 0.0

var resistance = 1.0

func attach(orig, dest):
	orig_pin = orig
	dest_pin = dest
	orig_pin.wires_list.append(self)
	dest_pin.wires_list.append(self)
	orig_pin.pin_neighbors.append(dest_pin)
	dest_pin.pin_neighbors.append(orig_pin)
func detach():
	orig_pin.wires_list.erase(self)
	dest_pin.wires_list.erase(self)
	orig_pin.pin_neighbors.erase(dest_pin)
	dest_pin.pin_neighbors.erase(orig_pin)

# from https://github.com/juddrgledhill/godot-dashed-line/blob/master/line_harness.gd
func draw_dashed_line(from, to, color, width, dash_length = 5, gap = 2.5, antialiased = false):
	var length = (to - from).length()
	var normal = (to - from).normalized()
	var dash_step = normal * dash_length

	# for each step...
	for s in range(-1, (length/(dash_length + gap)) + 1):

		# first, calculate linear values
		var linear_start = s * (dash_length + gap) + phase
		var linear_end = linear_start + dash_length

		# then, get actual 2D positions
		var segment_start = from + normal * min(length, max(0, linear_start))
		var segment_end = from + normal * min(length, max(0, linear_end))

		draw_line(segment_start, segment_end, color, width, antialiased)

###

func update_resist():
	resistance = resistivity * length / area

func conduct_neighboring_tension(t, node):
	# get network's total resistance...
	var r_total = logic.get_total_network_resistance(self)
	var r_bar = (r_total - resistance) / r_total

	if node == orig_pin:
		t = t + (dest_pin.tension - t) * r_bar
		dest_pin.add_tension_from_neighbor(t, node)
	else:
		t = t + (orig_pin.tension - t) * r_bar
		orig_pin.add_tension_from_neighbor(t, node)

func conduct_instant_tension(source_tension, falloff_degree, delegate_node, source_node):
	# get network's total resistance...
	var r_total = logic.get_total_network_resistance(self)
#	var r_bar = (r_total - resistance) / r_total
	var r_bar_inv = r_total / (r_total - resistance)

#	var falloff_coeff = (1-(falloff_degree/(2 + falloff_degree))) #* r_bar

	if delegate_node == orig_pin:
		if dest_pin.tension_neighbors.has(source_node) || dest_pin == source_node || dest_pin.is_source || !dest_pin.enabled:
			return
#		var t = (source_tension - dest_pin.tension) * falloff_coeff
#		dest_pin.add_tension_from_neighbor(t, source_node, falloff_degree)
		dest_pin.add_tension_from_neighbor(source_tension, source_node, falloff_degree)
		dest_pin.propagate(true, source_tension, falloff_degree + 1, source_node)

	else:
		if orig_pin.tension_neighbors.has(source_node) || orig_pin == source_node || orig_pin.is_source || !orig_pin.enabled:
			return
#		var t = (source_tension - orig_pin.tension) * falloff_coeff
#		orig_pin.add_tension_from_neighbor(t, source_node, falloff_degree)
		orig_pin.add_tension_from_neighbor(source_tension, source_node, falloff_degree)
		orig_pin.propagate(true, source_tension, falloff_degree + 1, source_node)

func TICK():
	# update voltage and current
	voltage = 0
	if dest_pin.enabled && orig_pin.enabled:
		voltage = orig_pin.tension - dest_pin.tension
	current = voltage / resistance

	$L/Label.text = str(stepify(abs(current),0.001)) + "A"
	$L/Label.rect_position = (orig_pin.global_position + dest_pin.global_position) / 2

	update()

var phase = 0
var dot_size = 6
var dot_gap = 25
func _process(delta):
	phase += clamp(current, -0.2, 0.2) * 2000 * delta
	while phase > dot_size + dot_gap:
		phase -= (dot_size + dot_gap)
	while phase < 0:
		phase += dot_size + dot_gap

func _draw():
	if (true):
		gradient.set_color(0, logic.get_tension_color(orig_pin.tension))
		gradient.set_color(1, logic.get_tension_color(dest_pin.tension))
		draw_dashed_line(
			orig_pin.global_position,
			dest_pin.global_position,
			Color(1, 1, 0, 1), dot_size,
			dot_size, dot_gap, false)
	else:
		var red = min(max(0,voltage), 100)/100
		var blue = max(min(0,voltage), -100)/-100
		draw_dashed_line(
			orig_pin.global_position,
			dest_pin.global_position,
			Color(red, 0, blue, 1), 5,
			10, 5, false)

func _ready():
	add_to_group("wires")
	points = [
		orig_pin.global_position,
		dest_pin.global_position
	]
	set_global_position(Vector2())
	$Line2D2.points = [
		orig_pin.global_position,
		dest_pin.global_position
	]
	$Line2D2.set_global_position(Vector2())

	length = (orig_pin.global_position - dest_pin.global_position).length()
