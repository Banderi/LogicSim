#tool
extends ColorRect

export(int, 1, 20) var inputs = 1 #setget refresh_inputs
export(int, 1, 20) var outputs = 1 #setget refresh_outputs
export(String) var circuitname = "AND" #setget refresh_name

export(int, -99, 99) var circuit = -99 #setget refresh_circuit # AND gate

const PIN = preload("res://scenes/pin.tscn")

var input_wires

###

#func calculate(inputs):
#	pass

###

func refresh_name(newname):
	$Label.text = newname
	circuitname = newname

func load_circuit(n):
	match n:
		-99:
			refresh_name("AND")
			refresh_inputs(2)
			refresh_outputs(1)
			pass
		-98:
			refresh_name("NOT")
			refresh_inputs(1)
			refresh_outputs(1)
			pass
	circuit = n

func refresh_inputs(pins): # generates number of input pins
	inputs = pins
	for n in $inputs.get_children():
		n.queue_free()
	for i in range(0, pins):
		var newpin = PIN.instance()
		newpin.rect_position = Vector2(-10, (i+1)*(rect_size[1] / (pins+1)) - 10)
		newpin.input = true
		$inputs.add_child(newpin)
	rect_size[1] = 30 * max(inputs, outputs) + 30

func refresh_outputs(pins): # generates number of output pins
	outputs = pins
	for n in $outputs.get_children():
		n.queue_free()
	for i in range(0, pins):
		var newpin = PIN.instance()
		newpin.rect_position = Vector2(rect_size[0] - 10, (i+1)*(rect_size[1] / (pins+1)) - 10)
		newpin.input = false
		$outputs.add_child(newpin)
	rect_size[1] = 30 * max(inputs, outputs) + 30

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Engine.editor_hint:
		refresh_inputs(inputs)
		refresh_outputs(outputs)

	# basic logic for common gates
	match circuit:
		-99: # AND gate
			var through = true
			for i in $inputs.get_children():
				if !i.enabled || !i.live:
					through = false
			$outputs.get_child(0).live = through

		-98: # NOT gate
			$outputs.get_child(0).live = !$inputs.get_child(0).live
