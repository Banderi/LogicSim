extends Node2D

const INPUT = preload("res://scenes/node_input.tscn")
const OUTPUT = preload("res://scenes/node_output.tscn")
const GATE = preload("res://scenes/circuit_gate.tscn")
const WIRE = preload("res://scenes/wire.tscn")
const PIN = preload("res://scenes/free_pin.tscn")

const ACMOTOR = preload("res://scenes/ac_motor.tscn")

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

	for i in circuitdata["circuits"]: # populate sub-circuits
		if i[0] == -999:
			var pin = PIN.instance()
			pin.position = Vector2(i[1], i[2])
			$nodes.add_child(pin)
		elif i[0] <= -200:
			match i[0]:
				-201:
					var motor = ACMOTOR.instance()
					motor.position = Vector2(i[1], i[2])
					$nodes.add_child(motor)
		else:
			var newgate = GATE.instance()
			newgate.rect_position = Vector2(i[1], i[2])
			newgate.load_circuit(i[0])
			$nodes.add_child(newgate)

	var prev_circuit = -1
	for w in circuitdata["wires"]: # for every wire

		var newwire = WIRE.instance()

		var orig_pin = get_pin(w[0][0], w[0][1], false)
		var dest_pin = get_pin(w[1][0], w[1][1], true)

		newwire.attach(orig_pin, dest_pin)
		$wires.add_child(newwire)

###

func _process(delta):
	get_tree().call_group("tick", "TICK")

func _ready():

	logic.probe = $graph

	populate(2)
