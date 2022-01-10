extends Node2D

export(bool) var can_interact = true
var node_type = -998
var node_token = null

var nodename = ""
func get_token():
	return node_token
func get_name():
	if nodename == null || nodename == "":
		return "Node " + str(get_token())
	else:
		return nodename

var orig_pin = null
var dest_pin = null

func update_node_data():
	var data = {
		"resistance": resistance,
		"reactance": reactance,
		"conductance": conductance
	}
	logic.main.update_node_data(node_token, data)

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
func query_tension_drop_coeff(source, dest, tA, tB):
#	DebugLogger.clearme(self)
#	DebugLogger.logme(self, [
#		get_name(), Color(1,1,1),
#		" (" + str(self) + ")", Color(0.65,0.65,0.65)
#	])
#	var v = tB - tA # this is when there is ZERO resistence.
#	if resistance == 500:
#		return 1.06
#	if resistance > 0:
#		voltage = voltage / (resistance)
#	else:
#		voltage = voltage

#	if str(conductance) != "inf":
#		voltage = voltage * 0.01

#	DebugLogger.logme(self, [
#		"\nVoltage query: ", Color(1,1,1),
#		logic.proper(v, "V", true), Color(1,0.2,0.2)
#	])
	return 1.0
func equalize_voltage():
	if !orig_pin.enabled || !dest_pin.enabled:
		return
	if str(resistance) != "0":
		return
	DebugLogger.logme(self, "\nEqualizing tensions...")
	var v = orig_pin.tension - dest_pin.tension

	var forward_coeff = query_tension_drop_coeff(null, null, orig_pin.tension, dest_pin.tension)
	var backward_coeff = (-2 + forward_coeff)

#	if resistance == 500:
#		forward_coeff = 0.7
#		backward_coeff = -1.3

	if !dest_pin.is_source:
		dest_pin.add_tension_drop_from_neighbor(orig_pin, self, forward_coeff * v)
	if !orig_pin.is_source:
		orig_pin.add_tension_drop_from_neighbor(dest_pin, self, backward_coeff * v)

func refresh_impedences(setting):
	match setting:
		"resistance":
			if str(resistance) == "inf":
				conductance = 0
			elif resistance == 0:
				conductance = "inf"
			else:
				conductance = 1.0 / resistance
		"conductance":
			if str(conductance) == "inf":
				resistance = 0
			elif conductance == 0:
				resistance = "inf"
			else:
				resistance = 1.0 / conductance

func update_material_properties():
	$L/Label.rect_position = (orig_pin.global_position + dest_pin.global_position) / 2 - Vector2(300, 0)
#	$L/Label.rect_position = Vector2()

	# first, calculate from conductance
	refresh_impedences("resistance")

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
		if abs(current) < 0.000000000001:
			current = 0

#	$L/Label.text = str(stepify(abs(current),0.001)) + "A"
	if focused:
		$L/Label.visible = true
		$L/Label.modulate.a = 1.0
		if str(resistance) == "inf":
			$L/Label.text = "inf Ohms"
		else:
			$L/Label.text = str(stepify(abs(resistance),0.001)) + " Ohms"
	else:
		if str(resistance) == "0":
			$L/Label.visible = false
		else:
			$L/Label.modulate.a = 0.5
			if str(resistance) == "inf":
				$L/Label.text = "inf"
			else:
				$L/Label.text = logic.proper(resistance, "")

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

	$L/Label.modulate.a = 0.5
	if str(resistance) == "0":
		$L/Label.visible = false
	if str(resistance) == "inf":
		$L/Label.text = "inf"
	else:
		$L/Label.text = logic.proper(resistance, "")
	update_material_properties()

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

func _on_bg_mouse_exited():
	focused = false
