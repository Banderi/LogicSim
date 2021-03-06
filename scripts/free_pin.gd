extends Node2D

export(float) var tension = 0
var node_type = -999
var node_token = null

###

func update_node_data(pin):
	var data = {
		"position": position,
		"is_source": pin.is_source,
		"tension_static": pin.tension_static,
		"tension_amplitude": pin.tension_amplitude,
		"tension_speed": pin.tension_speed,
		"tension_phase": pin.tension_phase,
		"enabled": pin.enabled
	}
	logic.main.update_node_data(node_token, data)

func _ready():
	add_to_group("tick")
