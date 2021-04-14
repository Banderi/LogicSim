extends Line2D

var orig_pin = null
var dest_pin = null
var dest_circuit = null
var dest_pin_slot = 0

func _ready():
	points = [
		orig_pin.get_child(0).global_position + Vector2(10,10),
		dest_pin.get_child(0).global_position + Vector2(10,10)
	]
	set_global_position(Vector2())
