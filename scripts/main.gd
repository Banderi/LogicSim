extends Node2D

const INPUT = preload("res://scenes/node_input.tscn")
const OUTPUT = preload("res://scenes/node_output.tscn")
const GATE = preload("res://scenes/circuit_gate.tscn")
const WIRE = preload("res://scenes/wire.tscn")
const FREEPIN = preload("res://scenes/free_pin.tscn")

const ACGEN = preload("res://scenes/ac_generator.tscn")

const LIST_BUTTON = preload("res://scenes/circuit_list_item.tscn")

onready var camera = $Camera2D
var max_camera_pan = 3000

onready var inputs = $inputs
onready var outputs = $outputs
onready var circuit = $circuit
onready var nodes = $circuit/nodes
onready var wires = $circuit/wires

onready var cursor = $BACK/cursor
onready var cursor2 = $BACK/cursor2
onready var cursor3 = $BACK/cursor3
onready var cursorline = $BACK/cursorline

onready var save_slot_list = $HUD/top_left/slots

onready var debug_logger = $HUD/top_right/debug

var node_options = null

###

var circuitdata = {
	"name": "",
	"color": "000000",
	"inputs": [],
	"outputs": [],
	"circuits": {}
}

####

func add_valid_circuit_dictionary_entry(dictionary, data, i, key, default):
	dictionary[key] = data[i] if (data.size() > i) else default
func construct_with_default_dictionary(dictionary, data, defaults_array, starting_index_offset = 1):
	for i in range(defaults_array.size()):
		var entry = defaults_array[i]
		add_valid_circuit_dictionary_entry(dictionary, data, i + starting_index_offset, entry[0], entry[1])

func convert_circuit_old_data_format(type, data):
	var dic = {}

	if data[0] == null:
		data[0] = generate_new_token()

	var dictionary = { # these MUST always be present, regardless of circuit type!
		"IDTOKEN": data[0] if data[0] != null else generate_new_token(),
#		"position": data[1] if data[1] != null else Vector2(),
	}
	match type:
		-999: # free-floating pin
			construct_with_default_dictionary(dictionary, data, [
				["position", Vector2()],
				["is_source", false],
				["tension_static", 0],
				["tension_amplitude", 0],
				["tension_speed", 0],
				["tension_phase", 0],
			])
#				"IDTOKEN": data[0] if data[0] != null else generate_new_token(),
#				"position": data[1],
#				"is_source": data[2] if data.size() > 2 else false,
#				"tension_static": pin.tension_static,
#				"tension_amplitude": pin.tension_amplitude,
#				"tension_speed": pin.tension_speed,
#				"tension_phase": pin.tension_phase
		-998: # A-B connection / wire-based node
			construct_with_default_dictionary(dictionary, data, [
				["conn_A", Vector2()],
				["conn_B", Vector2()],
				["RES", null],
#				["reactance", 0],
#				["impedence", 0],
#				["capacitance", 0],
#				["inductance", 0],
			])
			if dictionary.RES == null:
				dictionary["resistance"] = 0
				dictionary["reactance"] = 0
				dictionary["impedence"] = 0
			elif dictionary.RES is Array:
				add_valid_circuit_dictionary_entry(dictionary, dictionary.RES, 0, "resistance", 0)
				add_valid_circuit_dictionary_entry(dictionary, dictionary.RES, 1, "reactance", 0)
				add_valid_circuit_dictionary_entry(dictionary, dictionary.RES, 2, "impedence", 0)
			elif dictionary.RES is Dictionary:
				for k in dictionary.RES:
					dictionary[k] = dictionary.RES[k]
			dictionary.erase("RES")
			pass
	return dictionary

var node_token_list = {}
func get_pin_from_token(token, p):

	# for special legacy cases
	if token == -1:
		return inputs.get_child(p).get_node("Pin")
	elif token == -2:
		return outputs.get_child(p).get_node("Pin")
	else:
		var node = node_token_list[token]

		# if p < input count, it's an input; above that, it's an output
		if p < node.get_node("inputs").get_children().size():
			return node.get_node("inputs").get_child(p)
		else:
			return node.get_node("outputs").get_child(p)
func get_pin_from_token_pair(pair):
	return get_pin_from_token(pair[0], pair[1])
func generate_new_token():
	for token in range(0, 99):
		if !node_token_list.has(token):
			return token
	return null # oh no, out of space!
func register_token(node, token):
	node.node_token = token
	node_token_list[token] = node
func unregister_token(token):
	node_token_list.erase(token)

func add_input_node(i):
	var newinput = INPUT.instance()
	newinput.position = Vector2(220, i[1])
	newinput.get_node("Pin").input = true
	newinput.get_node("Label").text = i[0]
	inputs.add_child(newinput)
	circuitdata["inputs"].push_back(i)
func add_output_node(o):
	var newoutput = OUTPUT.instance()
	newoutput.position = Vector2(-25, o[1])
	newoutput.get_node("Pin").input = false
	newoutput.get_node("Label").text = o[0]
	outputs.add_child(newoutput)
	circuitdata["outputs"].push_back(o)
func add_circuit_node(type, data): # needed for in-game circuit spawn

	# pointer to the new node element to return
	var new_node_return = null

	# get new token for node
	if data is Array: # OLD FORMAT
		data = convert_circuit_old_data_format(type, data)
	if !("IDTOKEN" in data):
		data["IDTOKEN"] = generate_new_token()

	match type:
		-999:
			new_node_return = add_freepin_node(data)
		-998:
			new_node_return = add_wire_based_node(type, data)
		-201:
			var ac = ACGEN.instance()
			ac.position = data[0]
			nodes.add_child(ac)
			new_node_return = ac
		_:
			var newgate = GATE.instance()
			newgate.rect_position = data[0]
			newgate.load_circuit(type)
			nodes.add_child(newgate)
			new_node_return = newgate
	if !circuitdata["circuits"].has(type):
		circuitdata["circuits"][type] = []
	circuitdata["circuits"][type].push_back(data)

	# return newly added node!!
	return new_node_return

func add_freepin_node(a):
	var freepin = FREEPIN.instance()
	var pin = freepin.get_child(0).get_child(0)

	# set circuit parameters
	for key in a:
		if key in freepin:
			freepin.set(key, a[key])
		if key != "position" && key in pin:
			pin.set(key, a[key])

	# node id info
	freepin.node_type = -999
	register_token(freepin, a.IDTOKEN)

	nodes.add_child(freepin)
	return pin
func add_wire_based_node(type, a):
	var newwire = WIRE.instance()
	var orig_pin = get_pin_from_token_pair(a.conn_A)
	var dest_pin = get_pin_from_token_pair(a.conn_B)
	newwire.attach(orig_pin, dest_pin)

	# set circuit parameters
	for key in a:
		if key in newwire:
			newwire.set(key, a[key])

	# node id info
	newwire.node_type = type
	register_token(newwire, a.IDTOKEN)

	wires.add_child(newwire)
	return newwire

signal confirmation_dialog
var confirmation_dialog_confirmed = false
func ask_for_confirmation(title, body = "", ok = "OK", cancel = "Cancel"):
	confirmation_dialog_confirmed = false
	$HUD/fullscreen/ConfirmationDialog.window_title = title
	$HUD/fullscreen/ConfirmationDialog.dialog_text = body
	$HUD/fullscreen/ConfirmationDialog.get_ok().text = ok
	$HUD/fullscreen/ConfirmationDialog.get_cancel().text = cancel
	$HUD/fullscreen/ConfirmationDialog.popup()
	pass
func _on_ConfirmationDialog_confirmed():
	confirmation_dialog_confirmed = true
	emit_signal("confirmation_dialog")
func _on_ConfirmationDialog_custom_action(action):
	pass # Replace with function body.

func unload_circuit():
	circuitdata = {
		"name": "",
		"color": "000000",
		"inputs": [],
		"outputs": [],
		"circuits": {}
	}
	$HUD/top_left/line_name.text = circuitdata["name"]
	for n in inputs.get_children():
		n.free()
	for n in outputs.get_children():
		n.free()
	for n in nodes.get_children():
		n.free()
	for n in wires.get_children():
		n.free()
	node_token_list = {}
	logic.probe.attach(null, -1)
func save_circuit(n):
	if n == null:
		n = 0
		while logic.circuits.has(n): # find the first available circuit slot
			n += 1
	if n < 0:
		return # lower than 0 are BUILT IN circuits

	if logic.circuits.has(n) && logic.circuits[n].name != circuitdata.name:
		ask_for_confirmation("Existing circuit", "Overwrite the selected circuit?")
		yield(self, "confirmation_dialog")
		if !confirmation_dialog_confirmed:
			return

	print("saving circuit " + str(n))
	logic.circuits[n] = circuitdata
	save_database() # on circuit save, serialize as well
func load_circuit(n):
	if n == null:
		unload_circuit()
		return # todo
	if n < 0:
		return # lower than 0 are BUILT IN circuits
	print("loading circuit " + str(n))

	unload_circuit() # *ALWAYS* depopulate first.

	var to_load_from = logic.circuits[n]

	circuitdata["name"] = to_load_from["name"]
	circuitdata["color"] = to_load_from["color"]
	$HUD/top_left/line_name.text = circuitdata["name"]

	# load data for circuit #n
	for i in to_load_from["inputs"]: # populate INPUTS
		add_input_node(i)
	for o in to_load_from["outputs"]: # populate OUTPUTS
		add_output_node(o)
	for id in to_load_from["circuits"]: # populate sub-circuits
		var list_of_such = to_load_from["circuits"][id]
		for data in list_of_such:
			add_circuit_node(id, data)

	logic.prefs["lastcircuit"] = n
	save_prefs()
func delete_circuit(n):
	if !logic.circuits.has(n):
		return # invalid slot!
	if n < 0:
		return # lower than 0 are BUILT IN circuits

	ask_for_confirmation("Delete confirmation", "Delete the selected circuit?")
	yield(self, "confirmation_dialog")
	if !confirmation_dialog_confirmed:
		return

	print("deleting circuit " + str(n))
	logic.circuits.erase(n)
	save_database()
	reload_database()

var saveloaddel_mode = -1
func saveloaddel_button(n):
	reset_btn_saveloaddel(-1)
	match saveloaddel_mode:
		0: # save button
			save_circuit(n)
			return
		1: # load button
			load_circuit(n)
			return
		2: # delete button
			delete_circuit(n)
			return
		_:
			return

func update_node_data(token, data):

	# traverse memory struct and look for item with correct TOKEN
	for t in circuitdata["circuits"].keys():
		for i in circuitdata["circuits"][t].size():
			if circuitdata["circuits"][t][i].IDTOKEN == token: # BINGO!
				if data == null:
					circuitdata["circuits"][t].erase(circuitdata["circuits"][t][i])
					print("Node " + str(token) + " was removed!")
				else:
					data["IDTOKEN"] = token
					for entry in data:
						circuitdata["circuits"][t][i][entry] = data[entry]
					print("Node " + str(token) + " was updated with data " + str(data))
				return true
	print("Could not find node " + str(token))
	return false
func erase_node_data(token):
	update_node_data(token, null)

###

func savetofile(path, data):
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_var(data)
	file.close()
	print("Disk file '" + path + "' was modified")
func loadfromfile(path):
	var file = File.new()
	if not file.file_exists(path):
		return null
	file.open(path, File.READ)
	var data = file.get_var()
	file.close()
	print("Disk file '" + path + "' was loaded")
	return data

func save_database():
	savetofile("user://circuits.dat", logic.circuits)
func save_prefs():
	savetofile("user://prefs.dat", logic.prefs)

# todo: find files in folder
func export_database():
	pass
func import_database():
	pass

func add_circuit_button_to_list(c):
	var circuit_name = "+"
	if c != null:
		circuit_name = logic.circuits[c]["name"]

	# add circuit to slot list
	var btn = LIST_BUTTON.instance()
	btn.rect_min_size.y = 30
	btn.connect("button_down", self, "saveloaddel_button", [c])
	btn.text = circuit_name

	save_slot_list.add_child(btn)

func reload_database():

	# clear previous buttons
	for btn in save_slot_list.get_children():
		btn.queue_free()

	# reload database file
	logic.circuits = loadfromfile("user://circuits.dat")

	for c in logic.circuits:
		add_circuit_button_to_list(c)

	# for the "new circuit" button
	add_circuit_button_to_list(null)

###

func _process(delta):
	$BACK/grid.update()

	if delta == 0.0:
		delta = 0.000001

	if (logic.simulation_go > 0):
			logic.simulation_go -= 1
	if (logic.simulation_go != 0):

		for n in range(0, logic.get_pref("iteration_times")):
			get_tree().call_group("graph", "debugger_log_clear")

			# ATTEMPT ONE:
#			get_tree().call_group("pins", "sum_up_instant_tensions")
#			get_tree().call_group("wires", "equalize_instant_tensions")
#			get_tree().call_group("wires", "equalize_voltage")
			# TODO: this is a bit costly....
#			get_tree().call_group("sources", "maintain_tension") # propagate SOURCE voltage through wires a second time.
#			get_tree().call_group("pins", "sum_up_instant_tensions")
#			for l in range(1):
#				get_tree().call_group("pins", "equalize_current_flows")
#			get_tree().call_group("wires", "update_material_properties")

			# ATTEMPT TWO: these SORTA work but also don't. >:(
#			get_tree().call_group("pins", "sum_up_charge_flows", delta)
			get_tree().call_group("sources", "maintain_tension")
			get_tree().call_group("pins", "equalize_current_flows", delta)
			get_tree().call_group("pins", "sum_up_new_tension")
			get_tree().call_group("pins", "sum_up_instant_tensions")

			# ATTEMPT THREE
#			get_tree().call_group("sources", "maintain_tension")
##			get_tree().call_group("pins", "sum_up_instant_tensions")
##			get_tree().call_group("pins", "equalize_tensions")
##			get_tree().call_group("pins", "sum_up_neighbor_tensions")
#			get_tree().call_group("pins", "equalize_current_flows", delta)
##			get_tree().call_group("pins", "sum_up_instant_tensions")
#			get_tree().call_group("pins", "sum_up_new_tension")

#			get_tree().call_group("pins", "equalize_tensions")
#			get_tree().call_group("pins", "sum_up_neighbor_tensions")
#			get_tree().call_group("sources", "maintain_tension")
#			get_tree().call_group("pins", "sum_up_instant_tensions")

			get_tree().call_group("wires", "update_material_properties")

			# ATTEMPT THREE:


			get_tree().call_group("graph", "refresh_probes", false)

		get_tree().call_group("graph", "refresh_probes")
		get_tree().call_group("pins", "cleanup_tensions")

	$HUD/top_right/FPS.text = str(Performance.get_monitor(Performance.TIME_FPS))
	$BACK/grid.update()

func _draw():
	$HUD/graph/Control/scale_x.text = "X scale: " + str(logic.probe.zoom_x)
	$HUD/graph/Control/scale_y.text = "Y scale: " + str(logic.probe.zoom_y)

func _ready():
	logic.main = self
	tooltip("")

	# temp: load circuit 0 on startup
	reload_database()
	logic.prefs = loadfromfile("user://prefs.dat")
	if logic.prefs == null:
		logic.prefs = {}
	elif logic.prefs.has("lastcircuit"):
		load_circuit(logic.prefs.lastcircuit)
	$HUD/graph/Control/iterations.text = "iterat. : " + str(logic.get_pref("iteration_times"))

	# load in the value editor boxes
	node_options = {
		"root": $HUD/bottom_right/options,
		"vbox": $HUD/bottom_right/options/VBoxContainer,
		"name": $HUD/bottom_right/options/name,

		"tension": $HUD/bottom_right/options/VBoxContainer/tension,
		"is_source": $HUD/bottom_right/options/VBoxContainer/is_source,
		"resistance": $HUD/bottom_right/options/VBoxContainer/resistance,
#		"conductance": $HUD/bottom_right/options/VBoxContainer/conductance,
	}
	node_options.root.visible = false

	DebugLogger.clear()

func tooltip(txt):
	$HUD/bottom_right/tooltip.text = txt

###

# for UI workaround purposes...
func click_the_left_mouse_button():
	var evt = InputEventMouseButton.new()
	evt.button_index = BUTTON_LEFT
	evt.position = get_viewport().get_mouse_position()
	evt.pressed = true
	get_tree().input_event(evt)
	evt.pressed = false
	get_tree().input_event(evt)

var buildmode_types_singlepin = [
	-999, # free pin
	-200, # DC source
	-201  # AC source
]

var buildmode_circuit_type = null
var buildmode_stage = null
var buildmode_last_pin = null
var buildmode_last_emptyspace_position = null
func buildmode_start(type):
	buildmode_circuit_type = type
	buildmode_stage = 0
	buildmode_last_pin = null
	tooltip("Select starting pin")
func buildmode_terminate():
	buildmode_circuit_type = null
	buildmode_stage = null
	buildmode_last_pin = null
	buildmode_last_emptyspace_position = null
	tooltip("")
func buildmode_push_stage(pin):
	match buildmode_stage:
		0:
			if buildmode_types_singlepin.has(buildmode_circuit_type):
				match buildmode_circuit_type:
					-999:
						if pin != null: # existing destination pin
							tooltip("You can't overlap pins!")
						else:
							add_circuit_node(-999, [
								generate_new_token(),
								local_event_drag_corrected,
								0
							])
			else:
				tooltip("Select destination pin")
				buildmode_last_pin = pin
				if pin == null:
					buildmode_last_emptyspace_position = local_event_drag_corrected
				buildmode_stage += 1
		1:
			match buildmode_circuit_type:
				-998: # SIMPLE WIRE
					buildmode_last_pin = buildmode_add_wire(pin)
				-997: # RESISTOR
					buildmode_last_pin = buildmode_add_wire(pin, {
						"resistance": 1000,
						"reactance": 0,
						"impedance": 0
					})

func buildmode_add_wire(pin, data = null):
	if buildmode_last_pin == null: # no existing starting pin? create a new one!
		buildmode_last_pin = add_circuit_node(-999, [
			generate_new_token(),
			buildmode_last_emptyspace_position,
			0
		])

	if pin != null: # existing destination pin
		if buildmode_last_pin.pin_neighbors.has(pin):
			tooltip("You can't overlap wires!")
			return buildmode_last_pin
	else: # new destination pin!
		pin = add_circuit_node(-999, [
			generate_new_token(),
			local_event_drag_corrected,
			0
		])

	# finalize: add wire between pins!
	add_circuit_node(-998, [
		generate_new_token(),
		[buildmode_last_pin.get_parent().get_parent().node_token, 0],
		[pin.get_parent().get_parent().node_token, 0],
		data
	])

	# return the last destination pin to become the new starting pin!
	return pin

func buildmode_remove_node(node, head = true):
	if !node.can_interact:
		tooltip("Can not delete slave node!")
		return
#	if head:
	match node.node_type:
		-999: # if removing a pin, delete attached wires as well
			var wirelist = node.wires_list.duplicate() # prevent array updates while iterating over it >:(
			for w in wirelist:
				buildmode_remove_node(w, false)
		-998: # if removing a wire, detach from adjacent pins
			node.orig_pin.wires_list.erase(node)
			node.orig_pin.pin_neighbors.erase(node.dest_pin)
			node.dest_pin.wires_list.erase(node)
			node.dest_pin.pin_neighbors.erase(node.orig_pin)

	var token = null
	if "owner_node" in node:
		token = node.owner_node.node_token
	else:
		token = node.node_token
	unregister_token(token)
	erase_node_data(token)
	if node_selection == node:
		node_selection = null
	if logic.probe.probing == node:
		logic.probe.attach(null, -1)
	node.queue_free()

var node_selection = null
var local_event_drag_start = null
var local_event_drag_corrected = Vector2(0,0)
var camera_pos_mouse_diff = Vector2(0,0)
var mouse_position = Vector2(0,0)
var drag_button = 0
var selection_mode = 0
var edit_moving = false
var click_origin = {
	"left" : null,
	"middle" : null,
	"right" : null
}
var orig_camera_point = null
func _input(event):
	# reset node selection
	if node_selection != null && !node_selection.focused && !node_selection.soft_focus:
#		if buildmode_stage != 1:
#		print("unselecting " + str(node_selection) + " (no focus anymore)")
		node_selection = null

	# update input flags
	selection_mode = 0
	if Input.is_action_pressed("ctrl"):
		selection_mode += 1
	if Input.is_action_pressed("shift"):
		selection_mode += 2
	if Input.is_action_pressed("alt"):
		selection_mode += 4
	if Input.is_action_pressed("space"):
		selection_mode += 8
	# click to drag pin/node around
	if selection_mode & 1 && buildmode_stage == null:
		edit_moving = true
	else:
		edit_moving = false

	# update button flags
	drag_button = 0
	if Input.is_action_pressed("mouse_left"):
		drag_button += 1
	if Input.is_action_pressed("mouse_middle"):
		drag_button += 2
	if Input.is_action_pressed("mouse_right"):
		drag_button += 4

	# mouse clicks!
	if Input.is_action_just_pressed("mouse_left"):
		click_origin.left = mouse_position
		local_event_drag_start = local_event_drag_corrected
	if Input.is_action_just_pressed("mouse_middle"):
		click_origin.middle = mouse_position
		orig_camera_point = camera.position
	if Input.is_action_just_pressed("mouse_right"):
		click_origin.right = mouse_position

	# mouse release!
	if Input.is_action_just_released("mouse_left"):
		click_origin.left = null
		local_event_drag_start = null
	if Input.is_action_just_released("mouse_middle"):
		click_origin.middle = null
		orig_camera_point = null
	if Input.is_action_just_released("mouse_right"):
		click_origin.right = null

	# additional camera dragging (space)
	if selection_mode & 8:
		if Input.is_action_just_pressed("mouse_left") || Input.is_action_just_pressed("mouse_right"):
			orig_camera_point = camera.position

#	# unattach probes
#	if Input.is_action_just_released("mouse_right") && node_selection == null:
#		logic.probe.detach()

	if buildmode_stage != null:
		if Input.is_action_just_released("mouse_right"): # canel!!
			buildmode_terminate()
		if buildmode_circuit_type == null: # deleting!!
			if Input.is_action_just_released("mouse_left") && node_selection != null:
				buildmode_remove_node(node_selection)
		else:
			if Input.is_action_pressed("mouse_left") && buildmode_stage == 0 && click_origin.left != mouse_position:
				if !buildmode_types_singlepin.has(buildmode_circuit_type): # only do for "draggable" nodes
					buildmode_push_stage(node_selection)
					click_the_left_mouse_button()
			if Input.is_action_just_released("mouse_left"):
				if node_selection != null: # existing pin!
					if node_selection != buildmode_last_pin && node_selection.node_type == -999:
						buildmode_push_stage(node_selection)
				else:
					buildmode_push_stage(node_selection) # new pin!

	# camera scrolling and dragging
	if event is InputEventMouseButton:
		var zoom_step = 0.86
		var pan_diff_coeff = 1.0 - zoom_step
		if event.button_index == BUTTON_WHEEL_UP:
			camera.zoom *= zoom_step
			camera.position -= camera_pos_mouse_diff * pan_diff_coeff
		if event.button_index == BUTTON_WHEEL_DOWN:
			camera.zoom *= 1.0 / zoom_step
			camera.position += camera_pos_mouse_diff * pan_diff_coeff
	if event is InputEventMouseMotion:
		mouse_position = event.position
		local_event_drag_corrected = get_global_mouse_position() # update cursor position pointer
		camera_pos_mouse_diff = camera.position - local_event_drag_corrected

		if selection_mode & 2: # snap to grid!
			local_event_drag_corrected.x = round(local_event_drag_corrected.x / 50.0) * 50.0
			local_event_drag_corrected.y = round(local_event_drag_corrected.y / 50.0) * 50.0
		elif drag_button & 2 || (selection_mode & 8 && drag_button != 0): # drag camera around

			# determine which button was pressed
			var orig_drag_point = null
			if drag_button & 1:
				orig_drag_point = click_origin.left
			elif drag_button & 2:
				orig_drag_point = click_origin.middle
			elif drag_button & 4:
				orig_drag_point = click_origin.right

			# make SURE it's valid!
			if orig_drag_point != null:
				camera.position = orig_camera_point + (orig_drag_point - mouse_position) * camera.zoom
				camera.position.x = clamp(camera.position.x, -max_camera_pan, max_camera_pan)
				camera.position.y = clamp(camera.position.y, -max_camera_pan, max_camera_pan)

		# keep cursor centered on focused pin IF not doing other actions e.g. dragging
		if node_selection != null && node_selection.node_type == -999: # && !Input.is_action_pressed("mouse_left"):
			local_event_drag_corrected = node_selection.owner_node.position
	camera.zoom.x = clamp(camera.zoom.x, 0.5625, 9.98872123152)
	camera.zoom.y = clamp(camera.zoom.y, 0.5625, 9.98872123152)

	# circuit visibility in building mode
	if buildmode_stage == null:
		circuit.modulate.a = 1.0
		cursor.visible = false
		cursor2.visible = false
		cursor3.visible = false
		cursorline.visible = false
	else:
		circuit.modulate.a = 0.5
		cursor.visible = true
		cursor2.visible = true
		cursor3.visible = true

		cursor.position = local_event_drag_corrected
		cursor2.position = local_event_drag_corrected
		cursor3.position = local_event_drag_corrected

		if local_event_drag_start != null && !buildmode_types_singlepin.has(buildmode_circuit_type):
			cursor.position = local_event_drag_start
			cursor3.position = local_event_drag_start
		if buildmode_last_pin != null || buildmode_last_emptyspace_position != null:
			if buildmode_last_pin != null:
				cursor.position = buildmode_last_pin.owner_node.position
				cursor3.position = buildmode_last_pin.owner_node.position
				cursorline.points = [
					buildmode_last_pin.owner_node.position,
					local_event_drag_corrected
				]
			else:
				cursor.position = buildmode_last_emptyspace_position
				cursor3.position = buildmode_last_emptyspace_position
				cursorline.points = [
					buildmode_last_emptyspace_position,
					local_event_drag_corrected
				]
			cursorline.visible = true
		if node_selection == null:
			cursor.visible = false

	# update debug key display
	$HUD/bottom_left/keys.text = str(buildmode_circuit_type) + " : " + str(buildmode_stage) + " : " + str(buildmode_last_pin) # + " " + str(get_node_pin_id(buildmode_last_pin))
	$HUD/bottom_left/keys.text += "\n" + str(node_selection) # + " " + str(get_node_pin_id(node_selection))
	$HUD/bottom_left/keys.text += "\n" + str(drag_button) + " " + str(selection_mode)
	$HUD/bottom_left/keys.text += "\n" + str(local_event_drag_start) + " " + str(local_event_drag_corrected)
	$HUD/bottom_left/keys.text += "\n" + str(camera.position) + " " + str(camera_pos_mouse_diff)
	$HUD/bottom_left/keys.text += "\n" + str(camera.zoom)
	$HUD/bottom_left/keys.text += "\n" + str(cursor.position)

func _on_BACK_gui_input(event):
	if Input.is_action_just_released("mouse_right") && node_selection == null:
		logic.probe.detach()

func _on_btn_go_pressed():
	logic.simulation_go = -1
func _on_btn_stop_pressed():
	logic.simulation_go = 0
func _on_btn_step_pressed():
	logic.simulation_go += 2

func _on_btn_zoomx_less_pressed():
	logic.probe.zoom_hor(-1, self)
func _on_btn_zoomx_more_pressed():
	logic.probe.zoom_hor(1, self)
func _on_btn_zoomy_less_pressed():
	logic.probe.zoom_ver(-1, self)
func _on_btn_zoomy_more_pressed():
	logic.probe.zoom_ver(1, self)
func _on_btn_iter_less_pressed():
	var i = logic.available_iteration_times_temp.find(logic.get_pref("iteration_times"))
	i -= 1
	if i < 0:
		i = 0
	logic.set_pref("iteration_times", logic.available_iteration_times_temp[i])
	$HUD/graph/Control/iterations.text = "iterat. : " + str(logic.get_pref("iteration_times"))
func _on_btn_iter_more_pressed():
	var i = logic.available_iteration_times_temp.find(logic.get_pref("iteration_times"))
	i += 1
	if i > logic.available_iteration_times_temp.size() - 1:
		i = logic.available_iteration_times_temp.size() - 1
	logic.set_pref("iteration_times", logic.available_iteration_times_temp[i])
	$HUD/graph/Control/iterations.text = "iterat. : " + str(logic.get_pref("iteration_times"))

###

func reset_btn_saveloaddel(n):
	if n != 0:
		$HUD/top_left/btn_save.pressed = false
	if n != 1:
		$HUD/top_left/btn_load.pressed = false
	if n != 2:
		$HUD/top_left/btn_delete.pressed = false
	if n == -1:
		save_slot_list.visible = false

func _on_btn_new_pressed():
	reset_btn_saveloaddel(3)
	save_slot_list.visible = false
	unload_circuit()

func show_empty_save_slot():
	var ls = save_slot_list.get_child_count() - 1
	save_slot_list.get_child(ls).visible = true
func hide_empty_save_slot():
	var ls = save_slot_list.get_child_count() - 1
	save_slot_list.get_child(ls).visible = false

func _on_btn_save_pressed():
	if $HUD/top_left/btn_save.pressed:
		reload_database()
	reset_btn_saveloaddel(0)
	show_empty_save_slot()
	if $HUD/top_left/btn_save.pressed:
		saveloaddel_mode = 0
		save_slot_list.visible = true
	else:
		saveloaddel_mode = -1
		save_slot_list.visible = false
func _on_btn_load_pressed():
	if $HUD/top_left/btn_load.pressed:
		reload_database()
	reset_btn_saveloaddel(1)
	hide_empty_save_slot()
	if $HUD/top_left/btn_load.pressed:
		saveloaddel_mode = 1
		save_slot_list.visible = true
	else:
		saveloaddel_mode = -1
		save_slot_list.visible = false
func _on_btn_delete_pressed(): # todo!
	if $HUD/top_left/btn_delete.pressed:
		reload_database()
	reset_btn_saveloaddel(2)
	hide_empty_save_slot()
	if $HUD/top_left/btn_delete.pressed:
		saveloaddel_mode = 2
		save_slot_list.visible = true
	else:
		saveloaddel_mode = -1
		save_slot_list.visible = false

###

func _on_btn_settings_pressed():
	pass
func _on_btn_about_pressed():
	pass

#####

func _on_eraser_pressed():
	buildmode_start(null)
func _on_wire_pressed():
	buildmode_start(-998)
func _on_pin_pressed():
	buildmode_start(-999)
func _on_resistor_pressed():
	buildmode_start(-997)

###

func _on_line_name_text_changed(new_text):
	circuitdata.name = new_text

###

var update_node_settings_enabled = true
func update_setting(setting, s):
	if !update_node_settings_enabled:
		return false
	var node = logic.probe.probing
	if node != null && setting in node:
		node.set(setting, s)
		node.update_node_data()
		return true

func _on_name_text_changed(new_text):
	update_setting("nodename", new_text)
func _on_tension_value_changed(value):
	if node_options.is_source.pressed:
		update_setting("tension_static", value)
	else:
		update_setting("tension", value)
func _on_is_source_toggled(button_pressed):
	update_setting("is_source", node_options.is_source.pressed)
	_on_tension_value_changed(node_options.tension.value) # also refresh the tension box!

func update_impedences(setting):
	if !update_node_settings_enabled:
		return false
	var node = logic.probe.probing
	if node != null && "resistance" in node && "conductance" in node:
		node.refresh_impedences(setting)
		var r_le = node_options.resistance.get_line_edit()
#		var c_le = node_options.conductance.get_line_edit()

#		update_node_settings_enabled = false
#		if str(node.resistance) == "inf":
#			r_le.text = "inf Ohms"
#			node_options.resistance.editable = false
##			node_options.resistance.value = "inf"
#		else:
#			node_options.resistance.editable = true
#		if str(node.conductance) == "inf":
#			c_le.text = "inf Siemens"
#			node_options.conductance.editable = false
##			node_options.conductance.value = "inf"
#		else:
#			node_options.conductance.editable = true
#		update_node_settings_enabled = true
		return true
func _on_resistance_value_changed(value):
	update_setting("resistance", value)
	update_impedences("resistance")
func _on_conductance_value_changed(value):
	update_setting("conductance", value)
	update_impedences("conductance")
