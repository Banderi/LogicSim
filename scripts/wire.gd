extends Node2D

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
var conductance = 1.0

var focused = false
func _on_bg_mouse_entered():
	focused = true

func _on_bg_mouse_exited():
	focused = false

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

func is_enabled():
	return orig_pin.enabled && dest_pin.enabled

var r_bar = 0.99
func conduct_neighboring_tension(t, delegate_node):
	if !is_enabled():
		return
	# get network's total resistance...
#	var r_bar = 0.0
#	if conductance == 0:
#		r_bar = 0.0
#	else:
	var r_total = logic.get_total_network_resistance(self)
	r_bar = 1 - (r_total - resistance) / r_total

	var target_node = null
	if delegate_node == orig_pin:
		target_node = dest_pin
	else:
		target_node = orig_pin

	t = t #- target_node.tension #/ pow(resistance, -2) #+ (target_node.tension - t) * r_bar
	target_node.add_tension_from_neighbor(t, conductance, delegate_node)

func update_conductance():
	# first, calculate from conductance
	if conductance == 0:
		resistance = "inf"
		return
	# then, from cable properties
#	resistance = resistivity * length / area
	if resistance == 0:
		conductance = "inf"
	else:
		conductance = 1/resistance

	# update voltage and current
	voltage = 0
	if dest_pin.enabled && orig_pin.enabled:
		voltage = orig_pin.tension - dest_pin.tension
	current = voltage * conductance

#	$L/Label.text = str(stepify(abs(current),0.001)) + "A"
	$L/Label.text = str(stepify(abs(resistance),0.001)) + " Ohms"
	$L/Label.rect_position = (orig_pin.global_position + dest_pin.global_position) / 2

	update()

var phase = 0
var dot_size = 6
var dot_gap = 25
func _process(delta):
	if logic.simulation_go == -1:
		phase += clamp(current, -0.2, 0.2) * 2000 * delta
	else:
		phase += clamp(current, -0.2, 0.2)
	while phase > dot_size + dot_gap:
		phase -= (dot_size + dot_gap)
	while phase < 0:
		phase += dot_size + dot_gap

var color_mode = 0
func _draw():

	$wire/bg/bg.color.a = int(focused)

	match color_mode:
		0:
			if !orig_pin.enabled || !dest_pin.enabled:
				$Line2D.gradient.set_color(0, Color())
				$Line2D.gradient.set_color(1, Color())
			else:
				$Line2D.gradient.set_color(0, logic.get_tension_color(orig_pin.tension))
				$Line2D.gradient.set_color(1, logic.get_tension_color(dest_pin.tension))
			draw_dashed_line(
				orig_pin.global_position,
				dest_pin.global_position,
				Color(1, 1, 0, 1), dot_size,
				dot_size, dot_gap, false)
		1:
			var red = min(max(0,voltage), 100)/100
			var blue = max(min(0,voltage), -100)/-100
			draw_dashed_line(
				orig_pin.global_position,
				dest_pin.global_position,
				Color(red, 0, blue, 1), 5,
				10, 5, false)

func _ready():
	add_to_group("wires")

	set_global_position(Vector2())
	length = (orig_pin.global_position - dest_pin.global_position).length()

	$wire.set_global_position(orig_pin.global_position)
	$wire.rotation = orig_pin.global_position.angle_to_point(dest_pin.global_position) + PI
	$wire.scale[0] = length
	$Line2D.points = [
		orig_pin.global_position,
		dest_pin.global_position
	]

	update_conductance()

func _input(event):
	if focused:
		if event is InputEventMouseButton && !event.pressed:
			if event.button_index == BUTTON_RIGHT:
				logic.probe.attach(self, 1)
