extends Node2D

var focused = false
var enabled = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if enabled:
		$ColorRect/ColorRect.color = Color("ff0000")
	elif focused:
		$ColorRect/ColorRect.color = Color("323232")
	else:
		$ColorRect/ColorRect.color = Color("000000")

func _on_ColorRect_mouse_entered():
	focused = true

func _on_ColorRect_mouse_exited():
	focused = false

func _input(event):
	if event is InputEventMouseButton && event.button_index == BUTTON_LEFT && !event.pressed:
		if focused:
			enabled = !enabled
	$Pin.enabled = enabled
#	logic.update_wires()
