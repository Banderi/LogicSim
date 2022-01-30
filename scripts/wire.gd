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

var is_dangling = false
func magic_matrix(inv_resistance, sigmaA_invs, sigmaB_invs, sigmaA_ratios, sigmaB_ratios):
	# these are "row-major" but actually, they are stored
	# column-wise compared to classic math matrices.
	# also, the rows are from TOP to BOTTOM.
	var A = Basis()
	A.x = Vector3(inv_resistance, -sigmaA_invs, 0) # <--- this is the FIRST COLUMN, rows from 1 to 3
	A.y = Vector3(-inv_resistance, 0, sigmaB_invs) # <--- this is the SECOND COLUMN, rows from 1 to 3
	A.z = Vector3(-1, -1, -1)					   # <--- this is the THIRD COLUMN, rows from 1 to 3
	var B = Vector3(0, -sigmaA_ratios, sigmaB_ratios)
	if A.determinant() == 0:
		return null
	var Ai = A.inverse()
	var S = Ai * B
	return S
func equalize_current_flows(delta):
	if !is_enabled():
		return
	if str(resistance) == "inf":
		pass # deal with these later...
	elif str(resistance) == "0":
#		var wlist = orig_pin.query_neighbors(orig_pin.QUERY_ONLY_PERFECT_WIRES)
#		if wlist.size() != 0:
#			var node_tension = orig_pin.tension
#			for wentry in wlist:
#				var w = wentry[0]
#				var pin = get_B_from_A(wentry[1])
#				node_tension += pin.tension
#			node_tension = node_tension / (wlist.size() + 1)
#			if !orig_pin.is_source:
#				orig_pin.tension = node_tension
#			if !dest_pin.is_source:
#				dest_pin.tension = node_tension
		pass # deal with these later...
	else:
		var wA = orig_pin.query_neighbors(orig_pin.QUERY_JUMP_OVER_WIRES, [dest_pin])
		var wB = dest_pin.query_neighbors(dest_pin.QUERY_JUMP_OVER_WIRES, [orig_pin])
		if wA.size() > 0 && wB.size() > 0:
			var inv_resistance = conductance

			var sigmaA_invs = 0
			var sigmaA_ratios = 0
			for wentry in wA:
				var w = wentry[0]
				if wentry[0] != self:
					var pin = get_B_from_A(wentry[1])
					if str(w.resistance) == "inf":
						pass # deal with these later...
					else:
						sigmaA_invs += w.conductance
						sigmaA_ratios += w.voltage * w.conductance

			var sigmaB_invs = 0
			var sigmaB_ratios = 0
			for wentry in wB:
				var w = wentry[0]
				if wentry[0] != self:
					var pin = get_B_from_A(wentry[1])
					if str(w.resistance) == "inf":
						pass # deal with these later...
					else:
						sigmaB_invs += w.conductance
						sigmaB_ratios += w.voltage * w.conductance

			var s = magic_matrix(inv_resistance, sigmaA_invs, sigmaB_invs, sigmaA_ratios, sigmaB_ratios)
			if s != null:
				if !orig_pin.is_source:
					orig_pin.tension = s.x
				if !dest_pin.is_source:
					dest_pin.tension = s.y
			else:
				var tt = (orig_pin.tension + dest_pin.tension) / 2
				if !orig_pin.is_source:
					orig_pin.tension = tt
				if !dest_pin.is_source:
					dest_pin.tension = tt
		elif wA.size() > 0:
			orig_pin.equalize_current_flows(delta)
			if !dest_pin.is_source:
				dest_pin.tension = orig_pin.tension
			pass
		elif wB.size() > 0:
			dest_pin.equalize_current_flows(delta)
			if !orig_pin.is_source:
				orig_pin.tension = dest_pin.tension
			pass
		else:
			if orig_pin.is_source && !dest_pin.is_source:
				dest_pin.tension = orig_pin.tension
			elif !orig_pin.is_source && dest_pin.is_source:
				orig_pin.tension = dest_pin.tension
			elif !orig_pin.is_source && !dest_pin.is_source:
				var tt = (orig_pin.tension + dest_pin.tension) / 2
				orig_pin.tension = tt
				dest_pin.tension = tt
			pass
#		var s = magic_matrix(0.002, 0.00183333333333, 0.018333333333333, 0.013, -0.09)
	pass

var r_bar = 0.99
func update_voltage_and_current():
	if !dest_pin.enabled || !orig_pin.enabled:
		voltage = 0
		current = 0
		return
	voltage = orig_pin.tension - dest_pin.tension
	if str(resistance) == "inf":
		current = 0.0
	elif resistance == 0:
		if voltage < 0:
			current = "inf"
		elif voltage > 0:
			current = "-inf"
		else:
			current = 0.0
	else:
		current = voltage / resistance
		if abs(current) < 0.000000000001:
			current = 0
func get_current_from_A(A):
	update_voltage_and_current()
	if A == orig_pin:
		return current
	else:
		return -current
func equalize_voltage():
	if !orig_pin.enabled || !dest_pin.enabled:
		return
	if str(resistance) != "0":
		return
	DebugLogger.logme(self, "\nEqualizing tensions...")
	var v = orig_pin.tension - dest_pin.tension

#	var forward_coeff = query_tension_drop_coeff(null, null, orig_pin.tension, dest_pin.tension)
	var forward_coeff = 1.0
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
	update_voltage_and_current()
#	voltage = orig_pin.tension - dest_pin.tension
#	if str(conductance) == "inf" && dest_pin.enabled && orig_pin.enabled:
#		if abs(voltage) > 0.000001:
#			if voltage > 0:
#				current = "inf"
#			else:
#				current = "-inf"
#		else:
#			current = 0
##		elif orig_pin.tension != orig_pin.oldtension || dest_pin.tension != dest_pin.oldtension:
##			current = "inf" # TODO: figure out direction? not really a priority though...
##		else:
##			current = 0
#	else:
#		var cond_coeff = conductance
#		if !dest_pin.enabled || !orig_pin.enabled:
#			cond_coeff = 0
#		current = voltage * cond_coeff
#		if abs(current) < 0.000000000001:
#			current = 0

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
