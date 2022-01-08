extends Node2D

export(bool) var can_interact = true
var node_type = -998
var node_token = null

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

#var imp_vector = Vector2()
var impedance = null
#
var resistance = 1.0
var conductance = 1.0
#
var reactance = 1.0
var reactance_inv = 1.0

var capacitance = 0.0
var inductance = 0.0

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
func get_B_from_A(A):
	var B = null
	if A == orig_pin:
		return dest_pin
	else:
		return orig_pin

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
func query_tension_drop(source, dest, tA, tB):
	DebugLogger.clearme(self)
	DebugLogger.logme(self, self)
	var voltage = tB - tA # this is when there is ZERO resistence.

#	if str(conductance) != "inf":
#		voltage = voltage * 0.01


	DebugLogger.logme(self, "Voltage query: " + logic.proper(voltage, "V", true))

	return voltage

func update_conductance():
	$L/Label.rect_position = (orig_pin.global_position + dest_pin.global_position) / 2

	# first, calculate from conductance
	if str(conductance) == "inf":
		resistance = 0
	elif conductance == 0:
		resistance = "inf"
		$L/Label.text = "inf Ohms"
		return

	# then, from cable properties
#	resistance = resistivity * length / area
	if resistance == 0:
		conductance = "inf"
	else:
		conductance = 1/resistance

	# update voltage and current
	voltage = orig_pin.tension - dest_pin.tension
	if str(conductance) == "inf" && dest_pin.enabled && orig_pin.enabled:
		if abs(voltage) > 0.000001:
			if voltage > 0:
				current = "inf"
			else:
				current = "-inf"
		else:
			current = 0
#		elif orig_pin.tension != orig_pin.oldtension || dest_pin.tension != dest_pin.oldtension:
#			current = "inf" # TODO: figure out direction? not really a priority though...
#		else:
#			current = 0
	else:
		var cond_coeff = conductance
		if !dest_pin.enabled || !orig_pin.enabled:
			cond_coeff = 0
		current = voltage * cond_coeff

#	$L/Label.text = str(stepify(abs(current),0.001)) + "A"
	if str(resistance) == "inf":
		$L/Label.text = "inf Ohms"
	else:
		$L/Label.text = str(stepify(abs(resistance),0.001)) + " Ohms"

var phase = 0
var dot_size = 6
var dot_gap = 25
func _process(delta):
	# update phase anim
	if str(current) == "inf" || str(current) == "-inf":
		pass
	else:
		if logic.simulation_go == -1:
			phase += clamp(current, -0.2, 0.2) * 2000 * delta
		elif logic.simulation_go != 0:
			phase += clamp(current, -0.2, 0.2)
		while phase > dot_size + dot_gap:
			phase -= (dot_size + dot_gap)
		while phase < 0:
			phase += dot_size + dot_gap

	update()

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
			if str(current) == "inf" || str(current) == "-inf":
				draw_dashed_line(
					orig_pin.global_position,
					dest_pin.global_position,
					Color(1, 1, 0, 1), dot_size,
					999999, 0, false)
			elif current != 0:
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

func redraw():
	length = (orig_pin.global_position - dest_pin.global_position).length()
	$wire.set_global_position(orig_pin.global_position)
	$wire.rotation = orig_pin.global_position.angle_to_point(dest_pin.global_position) + PI
	$wire.scale[0] = length
	$Line2D.points = [
		orig_pin.global_position,
		dest_pin.global_position
	]

func _ready():
	add_to_group("wires")

	set_global_position(Vector2())

	redraw()

	$L/Label.visible = false
	update_conductance()

onready var hover_element = $wire/bg/bg
func _input(event):

	# check if mouse is ACTUALLY inside the element
	var local_p = hover_element.get_local_mouse_position()
	var local_r = hover_element.get_global_rect()
	var size_r = Rect2(Vector2(0,0), local_r.size)
	if size_r.has_point(local_p) && logic.main.node_selection == null:
		soft_focus = true
		logic.main.node_selection = self
	else:
		soft_focus = false

	if focused:
		if logic.main.buildmode_stage == null && Input.is_action_just_released("mouse_right"):
			logic.probe.attach(self, 1)

var focused = false
var soft_focus = false
func _on_bg_mouse_entered():
	focused = true
	$L/Label.visible = true

func _on_bg_mouse_exited():
	focused = false
	$L/Label.visible = false
