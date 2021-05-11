extends Node2D

export(float) var tension = 0
var node_type = -999
var node_token = null

###

func update_node_data(pin):

	var arr = [
		position,
		pin.is_source,
		pin.tension_static,
		pin.tension_amplitude,
		pin.tension_speed,
		pin.tension_phase
	]

	logic.main.update_node_data(node_token, arr)

func _ready():
	add_to_group("tick")
