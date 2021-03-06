extends Node

export(bool) var can_interact = true
var node_type = -999
#var node_token = null # inherited from parent?

export(bool) var input = true

# tension source
export(bool) var is_source = false
export var tension_static = 0.0
export var tension_amplitude = 0.0
export var tension_speed = 0.0
export var tension_phase = 0.0

var owner_node = null

var nodename = ""
func get_token():
	return owner_node.node_token
func get_name():
	if nodename == null || nodename == "":
		return "Node " + str(get_token())
	else:
		return nodename

var init_arr = null

var enabled = true
var oldtension = 0.0
var tension = 0.0

var color = null

func update_node_data():
	owner_node.update_node_data(self)

var wires_list = []
var pin_neighbors = []


enum {
	QUERY_ALL_NEIGHBORS
	QUERY_ONLY_VALID_RESISTANCE
	QUERY_ONLY_NON_ZERO_RESISTANCE
	QUERY_ONLY_PERFECT_WIRES
	QUERY_ONLY_PERFECT_INSULATORS
	QUERY_JUMP_OVER_WIRES
}
var cached_wire_island_list = null
var use_cached_island_list = false
func query_neighbors(query_method, ignore_pins = [], depth = 0):
	var arr = []
	match query_method:
		QUERY_ALL_NEIGHBORS:
			for w in wires_list:
				if w.is_enabled():
					arr.push_back([w, self])
		QUERY_ONLY_VALID_RESISTANCE:
			for w in wires_list:
				if str(w.resistance) != "0" && str(w.resistance) != "inf":
					if w.is_enabled():
						arr.push_back([w, self])
		QUERY_ONLY_NON_ZERO_RESISTANCE:
			for w in wires_list:
				if str(w.resistance) != "0":
					if w.is_enabled():
						arr.push_back([w, self])
		QUERY_ONLY_PERFECT_WIRES:
			for w in wires_list:
				if str(w.resistance) == "0":
					if w.is_enabled():
						arr.push_back([w, self])
		QUERY_ONLY_PERFECT_INSULATORS:
			for w in wires_list:
				if str(w.resistance) == "inf":
					if w.is_enabled():
						arr.push_back([w, self])
		QUERY_JUMP_OVER_WIRES:
			if use_cached_island_list && cached_wire_island_list != null && depth == 0:
				return cached_wire_island_list
			for w in wires_list:
				if str(w.resistance) != "0":
					if w.is_enabled():
						var next_pin = w.get_B_from_A(self)
						if !(next_pin in ignore_pins):
							arr.push_back([w, self])
				else: # perfect wire!
					if w.is_enabled():
						ignore_pins.push_back(self)
						var next_pin = w.get_B_from_A(self)
						# skip pins we've already gone over, to prevent loopbacks
						# also, ignore sources. sources do not "connect" normally
						# to other parts of the circuits - treat them all as isolated!
						if !(next_pin in ignore_pins) && !next_pin.is_source:
							arr.append_array(next_pin.query_neighbors(QUERY_JUMP_OVER_WIRES, ignore_pins, depth + 1))
	if depth == 0 && use_cached_island_list:
		cached_wire_island_list = arr
	return arr

var tension_neighbors = {}
func add_tension_from_neighbor(SOURCE_PIN_NODE, WIRE_NODE, t):
	if enabled && !tension_neighbors.has(SOURCE_PIN_NODE):
		tension_neighbors[SOURCE_PIN_NODE] = [t, WIRE_NODE]
func add_tension_drop_from_neighbor(SOURCE_PIN_NODE, WIRE_NODE, voltage):
	if enabled && !tension_neighbors.has(SOURCE_PIN_NODE):
		tension_neighbors[SOURCE_PIN_NODE] = [voltage, WIRE_NODE]
func sum_up_neighbor_tensions():
	var neighbors = tension_neighbors.size()
	if neighbors == 0:
		return # no valid neighbors

	var overall_tension = 0
	for t in tension_neighbors:
		var data = tension_neighbors[t]
		overall_tension += data[0]
	var new_tension_normalized = 0
	new_tension_normalized = overall_tension / neighbors

	DebugLogger.logme(self, [
		"New tension: ( ", Color(1,1,1),
		logic.proper(overall_tension, "V ", true), Color(1,0.2,0.2),
		"/ ", Color(1,1,1),
		neighbors, Color(1,1,1),
		" ) = ", Color(1,1,1),
		logic.proper(new_tension_normalized, "V", true), Color(1,0.2,0.2)
	])

	oldtension = tension
	tension = new_tension_normalized
	cleanup_tensions()
func propagate(only_perfect_wires = false):

	DebugLogger.clearme(self)
	DebugLogger.logme(self, [
		get_name(), Color(1,1,1),
		" (" + str(self) + ")", Color(0.65,0.65,0.65)
	])
	if !enabled:
		DebugLogger.logme(self, "\nPin is disabled! Sleeping...")
		return
	DebugLogger.logme(self, "\nPropagating tensions...")
	for w in wires_list:
		if !w.is_enabled():
			DebugLogger.logme(self, "  > Wire is asleep!")
		elif !only_perfect_wires || str(w.resistance) == "0":
			var target_pin = w.get_B_from_A(self)
			var tA = tension
			var tB = target_pin.tension
			if !target_pin.is_source:
#				var voltage = w.query_tension_drop(self, target_pin, tA, tB)
				var voltage = tB - tA
				DebugLogger.logme(self, [
					"  > Sending: ", Color(1,1,1),
					logic.proper(voltage, "V", true), Color(1,0.2,0.2),
					" to " + target_pin.get_name(), Color(1,1,1),
					" (" + str(target_pin) + ")", Color(0.65,0.65,0.65)
				])
				add_tension_drop_from_neighbor(target_pin, w, voltage)
				target_pin.add_tension_drop_from_neighbor(self, w, -voltage)
func equalize_tensions():
	DebugLogger.clearme(self)
	DebugLogger.logme(self, [
		get_name(), Color(1,1,1),
		" (" + str(self) + ")", Color(0.65,0.65,0.65)
	])
	DebugLogger.logme(self, "\n1) Equalizing tensions...")
	if !enabled:
		DebugLogger.logme(self, "Pin is disabled! Sleeping...")
		return
	if is_source:
		DebugLogger.logme(self, "Infinite source! Ignoring...")
		return

	var list = query_neighbors(QUERY_JUMP_OVER_WIRES)
	DebugLogger.logme(self, "Neighbors: " + str(list.size()))
	for wentry in list:
		var w = wentry[0]
		var nn = w.get_B_from_A(wentry[1])
#		arr_V.push_back(nn.tension)
#		arr_R.push_back(w.resistance)
		add_tension_from_neighbor(nn, w, nn.tension)
		DebugLogger.logme(self, [
			"  > Pin tension: ", Color(1,1,1),
			logic.proper(nn.tension, "V ", true), Color(1,0.2,0.2),
			"from " + nn.get_name(), Color(1,1,1),
			" (" + str(nn) + ")", Color(0.65,0.65,0.65)
		])
func cleanup_tensions():
	# reset tension source/sink
	var s = "+" if tension > 0.01 else ""
	$L/Label2.text = s + str(stepify(tension,0.01)) + "V"
	tension_neighbors = {}

var source_tensions = {}
func maintain_tension(): # actual source of tension!
	if is_source:
		DebugLogger.logme(self, "\n1) Updating SOURCE TENSION")
		tension = tension_static + 2 * tension_amplitude * sin(tension_phase * PI / 180)

		# update tension phase
		tension_phase += logic.get_pref("simulation_speed") * tension_speed * 4
		while tension_phase >= 360:
			tension_phase -= 360

		DebugLogger.logme(self, [
			"New tension: ", Color(1,1,1),
			logic.proper(tension, "V", true), Color(1,0.2,0.2)
		])

		# 2nd propagation loop, JUST for SOURCES
		propagate_instant_tension(tension, self, null)
func active_tension_loop_propagation():
	if !enabled || !is_source:
		return
	var wlist = query_neighbors(QUERY_JUMP_OVER_WIRES)
	for wentry in wlist:
		var w = wentry[0]
		w.propagate_active_tension_from_A(wentry[1], tension_static)

func propagate_instant_tension(t, source_node, delegate_wire):
	if enabled:
		# update tension with received INSTANT TENSION
		DebugLogger.logme(self, "\n2) Propagating instant tension...")

		if source_node != self && !(source_node in source_tensions): # ignore same-source loopbacks.
			DebugLogger.logme(self, [
				" > Received: ", Color(1,1,1),
				logic.proper(t, "V", true), Color(1,0.2,0.2),
				" from " + source_node.get_name(), Color(1,1,1),
				" (" + str(source_node) + ")", Color(0.65,0.65,0.65)
			])
			if source_tensions.size() > 0:
				logic.main.tooltip("SHORT CIRCUIT!!!!")
				# UH OH.
				# SHORT CIRCUIT!!
				pass
			source_tensions[source_node] = t

		var wires_done = 0
		for w in wires_list:
			if !w.is_enabled():
				DebugLogger.logme(self, "  > Wire is asleep!")
			elif w != delegate_wire: # ignore the wire that literally just trasmitted us the tension.
				var target_pin = w.get_B_from_A(self)
				if !(source_node in target_pin.source_tensions):
					if str(w.resistance) == "0": # ONLY propagate through ideal wires
						DebugLogger.logme(self, [
							"  > Sending: ", Color(1,1,1),
							logic.proper(t, "V", true), Color(1,0.2,0.2),
							" to " + target_pin.get_name(), Color(1,1,1),
							" (" + str(target_pin) + ")", Color(0.65,0.65,0.65)
						])
						target_pin.propagate_instant_tension(t, source_node, w)
						wires_done += 1
		if wires_done == 0:
			DebugLogger.logme(self, "No more perfect wires found!")
func sum_up_instant_tensions():
	if is_source:
		return
	DebugLogger.logme(self, "\n3) Summing up instant tensions...")
	var overall_instant_tension = 0
	for s in source_tensions:
		overall_instant_tension += source_tensions[s]
	if source_tensions.size() > 0:
		tension = overall_instant_tension / source_tensions.size()
	source_tensions = {}

var capacitance = 0.00000000001
var charge_stored = 0.0
func add_charge(volts):
	var max_c = max_charge(volts)
	var charge_goal = max(charge_stored, capacitance * volts)
	var charge_diff = charge_goal - charge_stored
	DebugLogger.logme(self, [
		"Charge in: ", Color(1,1,1),
#		logic.proper(charge_stored, "C ", true), Color(0,1,0),
		"( ", Color(1,1,1),
#		logic.proper(charge_diff, "C ", true), Color(1,1,0),
		logic.proper(capacitance, "F ", true), Color(1,0,1),
		"* ", Color(1,1,1),
		logic.proper(volts, "V ", true), Color(1,0.2,0.2),
		") = ", Color(1,1,1),
		logic.proper(charge_diff, "C ", true), Color(0,1,0),
	])
	charge_stored += charge_diff * 1.0
	pass
func remove_charge(curr, delta):
	if curr > 0:
		curr = 0
	var charge_depletion = curr * delta
	var charge_depletion_clamped = charge_depletion
	if charge_stored + charge_depletion < 0.0:
		charge_depletion_clamped = -charge_stored
	DebugLogger.logme(self, [
		"Charge out: ", Color(1,1,1),
#		logic.proper(charge_stored, "C ", true), Color(0,1,0),
		"( ", Color(1,1,1),
#		logic.proper(abs(charge_depletion), "C ", true), Color(1,1,0),
		logic.proper(curr, "C ", true), Color(0,1,0),
		"* ", Color(1,1,1),
		delta, Color(1,1,1),
		" ) = ", Color(1,1,1),
		logic.proper(charge_depletion_clamped, "C ", true), Color(0,1,0),
	])
	charge_stored += charge_depletion_clamped * 1.0
	pass
func max_charge(volts):
	return capacitance * volts
func get_max_current_in(delta, volts):
	var volts_str = ""
	if volts > 0:
		volts_str = logic.proper(volts, "V ", true)
	else:
		volts_str = "n/a "
		volts = 0
	var max_in = max_charge(volts) / delta
	DebugLogger.logme(self, [
		"Limit current in: ( ", Color(1,1,1),
		logic.proper(capacitance, "F ", true), Color(1,0,1),
		"* ", Color(1,1,1),
		volts_str, Color(1,0.2,0.2),
		") / ", Color(1,1,1),
		delta, Color(1,1,1),
		" = ", Color(1,1,1),
		logic.proper(max_in, "A ", true), Color(1,1,0)
	])
	return max_in
func get_max_current_out(delta):
	var max_out = charge_stored / delta
	DebugLogger.logme(self, [
		"Limit current out: ", Color(1,1,1),
		logic.proper(charge_stored, "C ", true), Color(0,1,0),
		"/ ", Color(1,1,1),
		delta, Color(1,1,1),
		" = ", Color(1,1,1),
		logic.proper(-max_out, "A ", true), Color(1,1,0)
	])
	return -max_out
func sum_up_charge_flows(delta):
	if enabled && !is_source: # ignore sources
		DebugLogger.logme(self, "\nSumming up charge flows...")
		var arr_V = []
		var arr_R = []
		var list = query_neighbors(QUERY_JUMP_OVER_WIRES)
		for wentry in list:
			var w = wentry[0]
			var nn = w.get_B_from_A(wentry[1])
			arr_V.push_back(nn.tension)
			arr_R.push_back(w.resistance)
			DebugLogger.logme(self, [
				"  > Wire: ", Color(1,1,1),
				logic.proper(nn.tension, "V ", true), Color(1,0.2,0.2),
				logic.proper(w.resistance, "O. ", true), Color(1,0.5,0),
				logic.proper(w.current, "A ", true), Color(1,1,0),
				"> " + nn.get_name(), Color(1,1,1),
				" (" + str(nn) + ")", Color(0.65,0.65,0.65)
			])
		var vsum = 0
		var csum = 0
		if arr_V.size() > 0:
			vsum = volts_summ(tension, arr_V, true)
			csum = curr_summ(tension, arr_V, arr_R, true)
		DebugLogger.logme(self, [
			"Charge stored: ", Color(1,1,1),
			logic.proper(charge_stored, "C ", true), Color(0,1,0)
		])
		add_charge(vsum)
		remove_charge(csum, delta)
		if charge_stored < 0.0:
			charge_stored = 0.0
		DebugLogger.logme(self, [
			"New charge: ", Color(1,1,1),
			logic.proper(charge_stored, "C ", true), Color(0,1,0)
		])
	pass

#var is_dangling = true
#func is_part_of_loop():
#	if is_source:
#		is_dangling = false
##	is_dangling = true
#	$ColorRect.visible = is_dangling
##	$ColorRect.visible = false

var new_tension = null
var total_voltages_in_out = 0
var total_currents_in_out = 0
func volts_summ(V0, arr_V, only_in_flow = false):
	var sum = 0
	if only_in_flow:
		DebugLogger.logme(self, "Tensions coming in:")
	else:
		DebugLogger.logme(self, "Sum of tensions:")
	for i in arr_V.size():
		var pt = arr_V[i] - V0
		DebugLogger.logme(self, [
			"     ", Color(1,1,1),
			logic.proper(pt, "V ", true), Color(1,0.2,0.2)
		])
		sum += pt
	if only_in_flow:
		sum = max(sum, 0.0)
		DebugLogger.logme(self, [
			"  = ", Color(1,1,1),
			logic.proper(sum, "V", true), Color(1,0.2,0.2),
			" (clamped to zero)", Color(1,1,1)
		])
	else:
		DebugLogger.logme(self, [
			"  = ", Color(1,1,1),
			logic.proper(sum, "V ", true), Color(1,0.2,0.2)
		])
	return sum
func curr_summ(V0, arr_V, arr_R, only_out_flow = false):
	var total = 0
	if only_out_flow:
		DebugLogger.logme(self, "Currents going out:")
	else:
		DebugLogger.logme(self, "Sum of currents:")
	for i in arr_V.size():
		var pi = (arr_V[i]-V0)/arr_R[i]
		DebugLogger.logme(self, [
			"     ", Color(1,1,1),
			logic.proper(pi, "A ", true), Color(1,1,0)
		])
		total += pi
	if only_out_flow:
		total = min(total, 0.0)
		DebugLogger.logme(self, [
			"  = ", Color(1,1,1),
			logic.proper(total, "A ", true), Color(1,1,0),
			" (clamped to zero)", Color(1,1,1)
		])
	else:
		DebugLogger.logme(self, [
			"  = ", Color(1,1,1),
			logic.proper(total, "A ", true), Color(1,1,0)
		])
	return total
func funky_summ(V0, arr_V, arr_R):
	var lhs = 0
	var rhs = 0

	for R in arr_R:
		lhs -= 1.0 / R
	for i in arr_V.size():
		var nm = arr_V[i] / arr_R[i]
		rhs += nm
		pass

	var total = V0 * lhs + rhs
	pass
	return total
func mystery_equation(V0, arr_V, arr_R, max_current):
	var lhs = 0
	var rhs = 0
	for i in arr_V.size():
		lhs += 1.0 / arr_R[i]
		rhs += arr_V[i] / arr_R[i]

	var new_V0 = (rhs - max_current) / lhs
	pass
	return new_V0
func equalize_current_flows(delta):
#	if !terminations:
#		var ww = wires_list.size()
#		if ww == 1:
#			return
#	elif terminations:
#		var ww = wires_list.size()
#		if ww != 1:
#			return

	if enabled && !is_source: # ignore sources
		DebugLogger.logme(self, "\n1) Equalizing current flows...")
		DebugLogger.logme(self, [
			"Old tension: ", Color(1,1,1),
			logic.proper(tension, "V ", true), Color(1,0.2,0.2)
		])

		var arr_V = []
		var arr_R = []
		var list = query_neighbors(QUERY_JUMP_OVER_WIRES)
		var neighbors = list.size()
		DebugLogger.logme(self, [
			"Neighbors: ", Color(1,1,1),
			neighbors, Color(1,1,1),
		])
#		for wentry in list:
#			var w = wentry[0]
#			var nn = w.get_B_from_A(wentry[1])
		if neighbors == 0:
			DebugLogger.logme(self, "No neighbors!")
			return
#		if neighbors == 1:
#			DebugLogger.logme(self, "Dangling pin! Skipping...")
#			return

#		if get_name() == "Node 4":
#			pass
#		if get_name() == "Node 2":
#			pass
		for wentry in list:
			var w = wentry[0]
			var nn = w.get_B_from_A(wentry[1])
			arr_V.push_back(nn.tension)
			arr_R.push_back(w.resistance)
			DebugLogger.logme(self, [
				"  > Resistor: ", Color(1,1,1),
				logic.proper(nn.tension, "V ", true), Color(1,0.2,0.2),
				logic.proper(w.resistance, "O. ", true), Color(1,0.5,0),
				logic.proper(w.current, "A ", true), Color(1,1,0),
				"> " + nn.get_name(), Color(1,1,1),
				" (" + str(nn) + ")", Color(0.65,0.65,0.65)
			])

		var termination = false
		if arr_V.size() == 1:
			termination = true

		if arr_V.size() > 0:
			total_voltages_in_out = volts_summ(tension, arr_V)
			total_currents_in_out = curr_summ(tension, arr_V, arr_R)
#			var max_in = get_max_current_in(delta, vsum) # this is POSITIVE
#			var max_out = get_max_current_out(delta) # this is NEGATIVE
#			max_in = 0

#			var currents_optimal = clamp(csum, max_out, max_in)
#			var currents_optimal = (max_in + max_out) / 2
			DebugLogger.logme(self, [
				"Optimal current: ", Color(1,1,1),
				logic.proper(0, "A ", true), Color(1,1,0)
			])

			var new_V0 = mystery_equation(tension, arr_V, arr_R, 0)
#			if termination && csum < 0:
#				new_V0 = 0


			DebugLogger.logme(self, [
				"New tension: ", Color(1,1,1),
				logic.proper(new_V0, "V ", true), Color(1,0.2,0.2)
			])
			new_tension = new_V0

#			is_dangling = false
			var neighbor_tensions = neighboring_tensions()
			var tension_diff = (new_tension - neighbor_tensions)
			DebugLogger.logme(self, [
				"Tension DIFFERENCE: ", Color(1,1,1),
				logic.proper(tension_diff, "V ", true), Color(1,0.2,0.2)
			])

			DebugLogger.logme(self, [
				"New total current: ", Color(1,1,1),
				logic.proper(curr_summ(new_tension, arr_V, arr_R), "A ", true), Color(1,1,0)
			])

		var asdasdda = 34
		pass
	sum_up_new_tension()
#	sum_up_instant_tensions() # this needs to be done here, *AFTER* calculating the pin's tension!!
	pass
func neighboring_tensions():
	var wlist = query_neighbors(QUERY_JUMP_OVER_WIRES)
	var neighbors = wlist.size()
	if neighbors == 0:
		return 0.0
	var total = 0
	for wentry in wlist:
		var w = wentry[0]
		var nn = w.get_B_from_A(wentry[1])
		total += tension
		pass
	total = total / neighbors
	return total
func voltages_in_out(wlist):
	var total = 0
	for wentry in wlist:
		var w = wentry[0]
		var nn = w.get_B_from_A(wentry[1])
		total += tension - nn.tension
		pass
	return -total
func currents_in_out(wlist):
	var total = 0
	for wentry in wlist:
		var w = wentry[0]
		total += w.get_current_from_A(wentry[1])
		pass
	return -total
func update_total_in_out():
	var wlist = query_neighbors(QUERY_JUMP_OVER_WIRES)
	total_voltages_in_out = voltages_in_out(wlist)
	total_currents_in_out = currents_in_out(wlist)
	DebugLogger.logme(self, [
		"VOLTAGES IN/OUT: ", Color(1,1,1),
		logic.proper(total_voltages_in_out, "V ", true), Color(1,0.2,0.2)
	])
	DebugLogger.logme(self, [
		"CURRENTS IN/OUT: ", Color(1,1,1),
		logic.proper(total_currents_in_out, "A ", true), Color(1,1,0)
	])
func sum_up_new_tension():
	if new_tension != null:
		tension += (new_tension - tension) * 1.0
		new_tension = null
#	sum_up_instant_tensions()
	update_total_in_out()

func _process(delta):
	$L/Label.text = "_/_"
	if enabled:
		$L/Label.text = "___"
		color = logic.get_tension_color(tension)
	else:
		color = logic.colors_tens[3]
	$L/Label.visible = false
	if !is_source:
		$L/Label2.visible = false
	else:
		$L/Label2.visible = true
	if focused:
		color = logic.colors_tens[4]
		if can_interact && !logic.main.selection_mode & 1:
			$L/Label.visible = true
		$L/Label2.visible = true

#	$L/Label3.text = ""
	$L/Label3.text = str(focused) + " " + str(soft_focus)

	$Pin.color = color

var orig_position = Vector2()
onready var hover_element = $Pin
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
		if logic.main.edit_moving:
			if Input.is_action_just_pressed("mouse_left"):
				orig_position = owner_node.position
			if event is InputEventMouseMotion && Input.is_action_pressed("mouse_left"):
				owner_node.position = orig_position + (event.position - logic.main.click_origin.left) * logic.main.camera.zoom

				# grid snapping!
				if !(logic.main.selection_mode & 2):
					var rx = round(owner_node.position.x / 50.0) * 50.0
					var ry = round(owner_node.position.y / 50.0) * 50.0
					owner_node.position = Vector2(rx, ry)

				for i in owner_node.get_child(0).get_children():
					for w in i.wires_list:
						w.redraw()
				for o in owner_node.get_child(1).get_children():
					for w in o.wires_list:
						w.redraw()

				# delegate updates to MAIN;
				# ask owner to bundle array of node data, which will then update
				# the correct field in the memory struct by use of their TOKEN
				update_node_data()
		elif logic.main.buildmode_stage == null:
			if Input.is_action_just_released("mouse_left"):
				enabled = !enabled
				update_node_data()
			if Input.is_action_just_released("mouse_right"):
				logic.probe.attach(self, 0)

var focused = false
var soft_focus = false
func _on_Pin_mouse_entered():
	focused = true

func _on_Pin_mouse_exited():
	focused = false

func _ready():
	owner_node = get_parent().get_parent()
	add_to_group("pins")
	add_to_group("sources")
