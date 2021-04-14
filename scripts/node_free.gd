#tool
extends ColorRect

export(int, 1, 20) var inputs = 1 #setget refresh_inputs
export(int, 1, 20) var outputs = 1 #setget refresh_outputs
export(String) var circuitname = "AND" #setget refresh_name

export(int, -99, 99) var circuit = -99 #setget refresh_circuit # AND gate

const PIN = preload("res://scenes/pin.tscn")

var input_wires

###

func calculate(inputs):
	pass

###

func refresh_name(newname):
#	if !Engine.editor_hint:
#		yield(self, "ready")
	$Label.text = newname
	circuitname = newname

func refresh_circuit(c):
#	if !Engine.editor_hint:
#		yield(self, "ready")
	match c:
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
	circuit = c

func refresh_inputs(pins):
#	if !Engine.editor_hint:
#		yield(self, "ready")
	inputs = pins
	for n in $inputs.get_children():
		n.queue_free()
	for i in range(0, pins):
		var newpin = PIN.instance()
		newpin.rect_position = Vector2(-10, (i+1)*(rect_size[1] / (pins+1)) - 10)
		newpin.input = true
		$inputs.add_child(newpin)
	rect_size[1] = 30 * max(inputs, outputs) + 30

func refresh_outputs(pins):
#	if !Engine.editor_hint:
#		yield(self, "ready")
	outputs = pins
	for n in $outputs.get_children():
		n.queue_free()
	for i in range(0, pins):
		var newpin = PIN.instance()
		newpin.rect_position = Vector2(rect_size[0] - 10, (i+1)*(rect_size[1] / (pins+1)) - 10)
		newpin.input = false
		$outputs.add_child(newpin)
	rect_size[1] = 30 * max(inputs, outputs) + 30


# Called when the node enters the scene tree for the first time.
func _ready():
#	refresh_inputs(inputs)
#	refresh_outputs(outputs)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Engine.editor_hint:
		refresh_inputs(inputs)
		refresh_outputs(outputs)
	pass
