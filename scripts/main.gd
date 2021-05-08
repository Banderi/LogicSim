extends Node2D

const INPUT = preload("res://scenes/node_input.tscn")
const OUTPUT = preload("res://scenes/node_output.tscn")
const GATE = preload("res://scenes/circuit_gate.tscn")
const WIRE = preload("res://scenes/wire.tscn")
const FREEPIN = preload("res://scenes/free_pin.tscn")

const ACGEN = preload("res://scenes/ac_generator.tscn")

onready var camera = $Camera2D

var circuitdata = {
	"name": "",
	"color": "000000",
	"inputs": [],
	"outputs": [],
	"circuits": [],
	"wires": []
}

####

func get_pin(c, p, inputs): # return pin node's handle from circuit C, slot P, input/output side
	if c == -99:
		return $inputs.get_child(p).get_node("Pin")
	elif c == 99:
		return $outputs.get_child(p).get_node("Pin")
	else:
		if inputs:
			return $nodes.get_child(c).get_node("inputs").get_child(p)
		else:
			var o = $nodes.get_child(c).get_node("outputs").get_child(p)
			if o == null:
				return $nodes.get_child(c).get_node("inputs").get_child(p)
			return $nodes.get_child(c).get_node("outputs").get_child(p)

func add_input_node(i):
	var newinput = INPUT.instance()
	newinput.position = Vector2(220, i[1])
	newinput.get_node("Pin").input = true
	newinput.get_node("Label").text = i[0]
	$inputs.add_child(newinput)
	circuitdata["inputs"].push_back(i)
func add_output_node(o):
	var newoutput = OUTPUT.instance()
	newoutput.position = Vector2(-25, o[1])
	newoutput.get_node("Pin").input = false
	newoutput.get_node("Label").text = o[0]
	$outputs.add_child(newoutput)
	circuitdata["outputs"].push_back(o)
func add_circuit_node(id, c): # needed for in-game circuit spawn
	match id:
		-999:
			add_freepin_node(c)
		-998:
			add_wire_based_node(id, c)
		-201:
			var ac = ACGEN.instance()
			ac.position = c[0]
			$nodes.add_child(ac)
		_:
			var newgate = GATE.instance()
			newgate.rect_position = c[0]
			newgate.load_circuit(id)
			$nodes.add_child(newgate)
	circuitdata["circuits"].push_back(c)

func add_freepin_node(p):
	var freepin = FREEPIN.instance()
	freepin.position = p[0]

	var pin = freepin.get_child(0).get_child(0)

	if (p.size() > 1): # additional values
		pin.is_source = true
		pin.tension_static = float(p[1])
		pin.tension_amplitude = float(p[2]) if p.size() > 2 else 0
		pin.tension_speed = float(p[3]) if p.size() > 3 else 0
		pin.tension_phase = float(p[4]) if p.size() > 4 else 0
	$nodes.add_child(freepin)
func add_wire_based_node(id, w):
	var newwire = WIRE.instance()
	var orig_pin = get_pin(w[0][0], w[0][1], false)
	var dest_pin = get_pin(w[1][0], w[1][1], true)
	newwire.attach(orig_pin, dest_pin)

	newwire.resistance = w[2] if w.size() > 2 else 0.0
	if str(newwire.resistance) == "inf":
		newwire.conductance = 0
	else:
		newwire.resistance = float(w[2]) if w.size() > 2 else 0.0
		if newwire.resistance == 0:
			newwire.conductance = "inf"
		else:
			newwire.conductance = abs(1/newwire.conductance)

	newwire.node_type = id

	$wires.add_child(newwire)
	circuitdata["wires"].push_back(w)

func unload_circuit():
	circuitdata = {
		"name": "",
		"color": "000000",
		"inputs": [],
		"outputs": [],
		"circuits": [],
		"wires": []
	}
	for n in $inputs.get_children():
		n.free()
	for n in $outputs.get_children():
		n.free()
	for n in $nodes.get_children():
		n.free()
	for n in $wires.get_children():
		n.free()
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
		for c in list_of_such:
			add_circuit_node(id, c)

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

###

var buildmode_circuit = null
var buildmode_stage = null
var buildmode_last_pin = null

var node_selection = null
var drag_button = 0
var selection_mode = 0
var orig_drag_point = Vector2()
var orig_camera_point = Vector2()
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

	# update button flags
	drag_button = 0
	if Input.is_action_pressed("mouse_left"):
		drag_button += 1
	if Input.is_action_pressed("mouse_middle"):
		drag_button += 2
	if Input.is_action_pressed("mouse_right"):
		drag_button += 4

	# update debug key display
	$HUD/bottom_left/keys.text = str(buildmode_circuit) + " : " + str(buildmode_stage) + " : " + str(buildmode_last_pin)
	$HUD/bottom_left/keys.text += "\n" + str(node_selection)
	$HUD/bottom_left/keys.text += "\n" + str(drag_button) + " " + str(selection_mode)

	# mouse clicks!
	if Input.is_action_just_pressed("mouse_middle") || Input.is_action_just_pressed("mouse_left"):
		orig_drag_point = event.position
		orig_camera_point = camera.position
	if Input.is_action_just_released("mouse_middle") || Input.is_action_just_released("mouse_left"):
		orig_drag_point = Vector2()
		orig_camera_point = Vector2()

	# camera scrolling and dragging
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP:
			camera.zoom *= 0.9
		if event.button_index == BUTTON_WHEEL_DOWN:
			camera.zoom *= 1.2
	if event is InputEventMouseMotion:
		if drag_button & 2:
			camera.position = orig_camera_point + (orig_drag_point - event.position) * camera.zoom
	camera.zoom.x = clamp(camera.zoom.x, 0.4, 10)
	camera.zoom.y = clamp(camera.zoom.y, 0.4, 10)

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

#####

func _on_wire_pressed():
#	buildmode_circuit =
	pass
