extends Node2D

const INPUT = preload("res://scenes/node_input.tscn")
const OUTPUT = preload("res://scenes/node_output.tscn")
const GATE = preload("res://scenes/circuit_gate.tscn")
const WIRE = preload("res://scenes/wire.tscn")
const FREEPIN = preload("res://scenes/free_pin.tscn")

const ACGEN = preload("res://scenes/ac_generator.tscn")

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

var circuitdata = {
	"name": "",
	"color": "000000",
	"inputs": [],
	"outputs": [],
	"circuits": {}
}

####

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

	# get new token for node
	if data[0] == null:
		data[0] = generate_new_token()

	match type:
		-999:
			add_freepin_node(data)
		-998:
			add_wire_based_node(type, data)
		-201:
			var ac = ACGEN.instance()
			ac.position = data[0]
			nodes.add_child(ac)
		_:
			var newgate = GATE.instance()
			newgate.rect_position = data[0]
			newgate.load_circuit(type)
			nodes.add_child(newgate)
	if !circuitdata["circuits"].has(type):
		circuitdata["circuits"][type] = []
	circuitdata["circuits"][type].push_back(data)

func add_freepin_node(a):
	var freepin = FREEPIN.instance()
	freepin.position = a[1]

	var pin = freepin.get_child(0).get_child(0)

	if (a.size() > 3): # additional values
		pin.is_source = float(a[2])
		pin.tension_static = float(a[3])
		pin.tension_amplitude = float(a[4]) if a.size() > 4 else 0
		pin.tension_speed = float(a[5]) if a.size() > 5 else 0
		pin.tension_phase = float(a[6]) if a.size() > 6 else 0

	# node id info
	freepin.node_type = -999
	register_token(freepin, a[0])
#	pin.node_token = a[0] # terminating pin node also has a token field...

	nodes.add_child(freepin)
func add_wire_based_node(type, a):
	var newwire = WIRE.instance()
	var orig_pin = get_pin_from_token(a[1][0], a[1][1])
	var dest_pin = get_pin_from_token(a[2][0], a[2][1])
	newwire.attach(orig_pin, dest_pin)

	var imp = a[3] if a.size() > 3 else Vector2()
	newwire.impedance = null # reset impedance

	# resistance
	if str(imp[0]) == "inf":
		newwire.resistance = "inf"
		newwire.conductance = 0.0
		newwire.impedance = "inf"
	elif float(imp[0]) == 0.0:
		newwire.resistance = 0.0
		newwire.conductance = "inf"
		newwire.impedance = "inf"
	else:
		newwire.resistance = float(imp[0])
		newwire.conductance = 1.0 / newwire.resistance

	# reactance
	if str(imp[1]) == "inf":
		newwire.reactance = "inf"
		newwire.reactance_inv = 0.0
		newwire.impedance = "inf"
	elif float(imp[1]) == 0.0:
		newwire.reactance = 0.0
		newwire.reactance_inv = "inf"
		newwire.impedance = "inf"
	else:
		newwire.reactance = float(imp[1])
		newwire.reactance_inv = 1.0 / newwire.reactance

	# impedance
	if newwire.impedance == null:
		newwire.impedance = sqrt(imp[0] * imp[0] + imp[1] * imp[1])

	# etc.
	newwire.capacitance = a[4] if a.size() > 4 else 0.0
	newwire.inductance = a[5] if a.size() > 5 else 0.0

	# node id info
	newwire.node_type = type
	register_token(newwire, a[0])

	wires.add_child(newwire)

func unload_circuit():
	circuitdata = {
		"name": "",
		"color": "000000",
		"inputs": [],
		"outputs": [],
		"circuits": {}
	}
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
	logic.circuits[n] = circuitdata
func load_circuit(n):
	unload_circuit() # *ALWAYS* depopulate first.

	var to_load_from = logic.circuits[n]

	circuitdata["name"] = to_load_from["name"]
	circuitdata["color"] = to_load_from["color"]

	# load data for circuit #n
	for i in to_load_from["inputs"]: # populate INPUTS
		add_input_node(i)
	for o in to_load_from["outputs"]: # populate OUTPUTS
		add_output_node(o)
	for id in to_load_from["circuits"]: # populate sub-circuits
		var list_of_such = to_load_from["circuits"][id]
		for data in list_of_such:
			add_circuit_node(id, data)

func update_node_data(token, data):

	# traverse memory struct and look for item with correct TOKEN
	for t in circuitdata["circuits"].keys():
		for i in circuitdata["circuits"][t].size():
			if circuitdata["circuits"][t][i][0] == token: # BINGO!
				if data == null:
					circuitdata["circuits"][t].erase(circuitdata["circuits"][t][i])
					print("Node " + str(token) + " was removed!")
				else:
					data.push_front(token)
					circuitdata["circuits"][t][i] = data
					print("Node " + str(token) + " was updated with data " + str(data))
				return true
	print("Could not find node " + str(token))
	return false
func erase_node_data(token):
	update_node_data(token, null)

###

func _process(delta):
	$BACK/grid.update()

	if (logic.simulation_go > 0):
			logic.simulation_go -= 1
	if (logic.simulation_go != 0):

		for n in range(0, logic.iteration_times):
			get_tree().call_group("pins", "propagate")
			get_tree().call_group("pins", "sum_up_neighbor_tensions")
			get_tree().call_group("sources", "maintain_tension")
			get_tree().call_group("wires", "update_conductance")

		get_tree().call_group("graph", "refresh_probes")
		get_tree().call_group("pins", "cleanup_tensions")

	$HUD/top_right/FPS.text = str(Performance.get_monitor(Performance.TIME_FPS))
	$BACK/grid.update()

func _draw():
	$HUD/graph/Control/scale_x.text = "X scale: " + str(logic.probe.zoom_x)
	$HUD/graph/Control/scale_y.text = "Y scale: " + str(logic.probe.zoom_y)

func _ready():
	logic.main = self
	load_circuit(3)
#	save_circuit(3)
#	load_circuit(3)
#	save_circuit(3)
#	load_circuit(3)
#	save_circuit(3)
#	load_circuit(3)
#	save_circuit(3)
#	load_circuit(3)
#	save_circuit(3)
#	load_circuit(3)
	tooltip("")

func tooltip(txt):
	$HUD/bottom_right/tooltip.text = txt

###

var buildmode_circuit_type = null
var buildmode_stage = null
var buildmode_last_pin = null
func buildmode_start(type):
	buildmode_circuit_type = type
	buildmode_stage = 0
	buildmode_last_pin = null
	tooltip("Select starting pin")
func buildmode_terminate():
	buildmode_circuit_type = null
	buildmode_stage = null
	buildmode_last_pin = null
	tooltip("")
func buildmode_push_stage(pin):
	match buildmode_stage:
		0:
			tooltip("Select destination pin")
			buildmode_last_pin = pin
			buildmode_stage += 1
		1:
			if buildmode_last_pin.pin_neighbors.has(pin):
				tooltip("You can't overlap wires!")
			else:
				add_circuit_node(-998, [
						generate_new_token(),
						[buildmode_last_pin.get_parent().get_parent().node_token, 0],
						[pin.get_parent().get_parent().node_token, 0]
					])
				buildmode_terminate()
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
var mouse_position = Vector2(0,0)
var drag_button = 0
var selection_mode = 0
var edit_moving = false
var orig_drag_point_left = null
var orig_drag_point_middle = null
var orig_drag_point_right = null
var orig_camera_point = null
func _input(event):
	# reset node selection
	if node_selection != null && !node_selection.focused:
		node_selection = null

	# update input flags
	selection_mode = 0
	if Input.is_action_pressed("ctrl"):
		selection_mode += 1
	if Input.is_action_pressed("shift"):
		selection_mode += 2
	if Input.is_action_pressed("alt"):
		selection_mode += 4
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
	if Input.is_action_just_pressed("mouse_middle"):
		orig_drag_point_middle = mouse_position
		orig_camera_point = camera.position
	if Input.is_action_just_pressed("mouse_left"):
		orig_drag_point_left = mouse_position
		local_event_drag_start = local_event_drag_corrected
	if Input.is_action_just_released("mouse_middle"):
		orig_drag_point_middle = null
		orig_camera_point = null
	if Input.is_action_just_released("mouse_left"):
		orig_drag_point_left = null
		local_event_drag_start = null

	if buildmode_stage != null:
		if Input.is_action_just_released("mouse_right"):
			buildmode_terminate()
		if buildmode_circuit_type == null: # deleting!!
			if Input.is_action_just_released("mouse_left") && node_selection != null:
				buildmode_remove_node(node_selection)
		else:
			if Input.is_action_just_released("mouse_left"): # || (Input.is_action_pressed("mouse_left") && local_event_drag_start != local_event_drag_corrected):
				if node_selection != null && node_selection != buildmode_last_pin && node_selection.node_type == -999:
					buildmode_push_stage(node_selection)

	# camera scrolling and dragging
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP:
			camera.zoom *= 0.75
		if event.button_index == BUTTON_WHEEL_DOWN:
			camera.zoom *= 1.0 / 0.75
	if event is InputEventMouseMotion:
		mouse_position = event.position
		local_event_drag_corrected = get_global_mouse_position() # update cursor position pointer

		if selection_mode & 2: # snap to grid!
			local_event_drag_corrected.x = round(local_event_drag_corrected.x / 50.0) * 50.0
			local_event_drag_corrected.y = round(local_event_drag_corrected.y / 50.0) * 50.0
		elif drag_button & 2: # drag camera around
			camera.position = orig_camera_point + (orig_drag_point_middle - mouse_position) * camera.zoom
			camera.position.x = clamp(camera.position.x, -max_camera_pan, max_camera_pan)
			camera.position.y = clamp(camera.position.y, -max_camera_pan, max_camera_pan)

		# keep cursor centered on focused pin IF not doing other actions e.g. dragging
		if node_selection != null && node_selection.node_type == -999 && !Input.is_action_pressed("mouse_left"):
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

		if local_event_drag_start != null:
			cursor.position = local_event_drag_start
			cursor3.position = local_event_drag_start
		if buildmode_last_pin != null:
			cursor.position = buildmode_last_pin.owner_node.position
			cursor3.position = buildmode_last_pin.owner_node.position
			cursorline.visible = true
			cursorline.points = [
				buildmode_last_pin.owner_node.position,
				local_event_drag_corrected
			]
		if node_selection == null:
			cursor.visible = false

	# update debug key display
	$HUD/bottom_left/keys.text = str(buildmode_circuit_type) + " : " + str(buildmode_stage) + " : " + str(buildmode_last_pin) # + " " + str(get_node_pin_id(buildmode_last_pin))
	$HUD/bottom_left/keys.text += "\n" + str(node_selection) # + " " + str(get_node_pin_id(node_selection))
	$HUD/bottom_left/keys.text += "\n" + str(drag_button) + " " + str(selection_mode)
	$HUD/bottom_left/keys.text += "\n" + str(local_event_drag_start) + " " + str(local_event_drag_corrected)
	$HUD/bottom_left/keys.text += "\n" + str(camera.position)
	$HUD/bottom_left/keys.text += "\n" + str(camera.zoom)
	$HUD/bottom_left/keys.text += "\n" + str(cursor.position)

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

###

func _on_btn_save_pressed():
	save_circuit(3)

func _on_btn_load_pressed():
	load_circuit(3)

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
