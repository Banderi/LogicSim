extends Node2D

const INPUT = preload("res://scenes/node_input.tscn")
const OUTPUT = preload("res://scenes/node_output.tscn")
const GATE = preload("res://scenes/circuit_gate.tscn")
const WIRE = preload("res://scenes/wire.tscn")
const PIN = preload("res://scenes/free_pin.tscn")

const ACGEN = preload("res://scenes/ac_generator.tscn")

####

func depopulate():
	for n in $inputs.get_children():
		n.queue_free()
	for n in $outputs.get_children():
		n.queue_free()
	for n in $nodes.get_children():
		n.queue_free()

func get_pin(c, p, inputs):
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

func add_circuit_node(c):
	match c[0]:
		-999:
			var pin = PIN.instance()
			pin.position = Vector2(c[1], c[2])
			$nodes.add_child(pin)
		-201:
			var ac = ACGEN.instance()
			ac.position = Vector2(c[1], c[2])
			$nodes.add_child(ac)
		_:
			var newgate = GATE.instance()
			newgate.rect_position = Vector2(c[1], c[2])
			newgate.load_circuit(c[0])
			$nodes.add_child(newgate)

func populate(n):
	depopulate()

	# load data for circuit #n
	var circuitdata = logic.circuits[n]
	for i in circuitdata["inputs"]: # populate INPUTS
		var newinput = INPUT.instance()
		newinput.position = Vector2(220, i[1])
		newinput.get_node("Pin").input = true
		newinput.get_node("Label").text = i[0]
		$inputs.add_child(newinput)

	for i in circuitdata["outputs"]: # populate OUTPUTS
		var newoutput = OUTPUT.instance()
		newoutput.position = Vector2(-25, i[1])
		newoutput.get_node("Pin").input = false
		newoutput.get_node("Label").text = i[0]
		$outputs.add_child(newoutput)

	for c in circuitdata["circuits"]: # populate sub-circuits
		add_circuit_node(c)

#	var prev_circuit = -1
	for w in circuitdata["wires"]: # for every wire

		var newwire = WIRE.instance()

		var orig_pin = get_pin(w[0][0], w[0][1], false)
		var dest_pin = get_pin(w[1][0], w[1][1], true)

		newwire.attach(orig_pin, dest_pin)
		$wires.add_child(newwire)

###

var go = true
func _process(delta):

	if (go):
		print(" >> TICK DONE")

		get_tree().call_group("wires", "TICK")

		get_tree().call_group("pins", "propagate")
		get_tree().call_group("pins", "sum_up_neighbor_tensions")

		get_tree().call_group("sources", "maintain_tension")

		get_tree().call_group("graph", "refresh_probes")

		get_tree().call_group("pins", "cleanup_tensions")

		print(" >> NEW TICK")
#		go = false


func _ready():

	logic.probe = $graph

	populate(2)


func _on_Button_pressed():
	go = true
