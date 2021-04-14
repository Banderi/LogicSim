extends Node2D

const INPUT = preload("res://scenes/node_input.tscn")
const OUTPUT = preload("res://scenes/node_output.tscn")
const NODE = preload("res://scenes/node_free.tscn")
const WIRE = preload("res://scenes/wire.tscn")

####

func depopulate():
	for n in $inputs.get_children():
		n.queue_free()
	for n in $outputs.get_children():
		n.queue_free()
	for n in $nodes.get_children():
		n.queue_free()

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
		var newnode = NODE.instance()
		newnode.rect_position = Vector2(i[1], i[2])
		newnode.load_circuit(i[0])
		$nodes.add_child(newnode)

	var prev_circuit = -1
	for c in circuitdata["wires"]: # for every circuit "stage"
		var output = 0
		for i in c: # for every output of previous circuit
			for w in i: # for every wire

				var orig_pin
				var dest_pin

				var newwire = WIRE.instance()

				if prev_circuit == -1:
					orig_pin = $inputs.get_child(output).get_node("Pin")
				else:
					orig_pin = $nodes.get_child(prev_circuit).get_node("outputs").get_child(output)
				if w[0] == 99: # circuit 99 is the OUTPUTS
					dest_pin = $outputs.get_child(w[1]).get_node("Pin")
#					newwire.dest_pin_slot = 0
				else:
					dest_pin = $nodes.get_child(w[0]).get_node("inputs").get_child(w[1])
#					newwire.dest_pin_slot = w[1]

				newwire.attach(orig_pin, dest_pin)
#				newwire.dest_circuit = dest_pin.get_parent()
				orig_pin.add_child(newwire)
			output += 1
		prev_circuit += 1

# Called when the node enters the scene tree for the first time.
func _ready():
	populate(1)
