extends Node2D

var focused = false
var live = false
var tension = 100

###

func TICK():
	$Pin.apply_tension(live * tension)

func _process(delta):
	if live:
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
			live = !live

func _ready():
	add_to_group("tick")
