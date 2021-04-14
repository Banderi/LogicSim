extends ColorRect

export(bool) var input = true

var enabled = true
var focused = false
var live = false

var wires_list = []

func propagate():

	for w in wires_list:
		if w.live:
			live = true

	if (enabled && live):
		for w in wires_list:
			w.live = true
	else:
		for w in wires_list:
			w.live = false


# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("pins")
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Label.text = "_/_"
	if enabled:
		$Label.text = "___"
		if live:
			color = Color("ff0000")
		else:
			color = Color("000000")
	else:
		color = Color("102090")
	if focused:
		color = Color("323232")
		$Label.visible = true
	else:
		$Label.visible = false

	propagate()

func _on_Pin_mouse_entered():
	focused = true

func _on_Pin_mouse_exited():
	focused = false

func _input(event):
	if event is InputEventMouseButton && event.button_index == BUTTON_LEFT && !event.pressed:
		if focused:
			enabled = !enabled
