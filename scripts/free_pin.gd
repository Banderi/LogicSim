extends Node2D

export(float) var tension = 0
var node_type = -999
var node_token = null

###

func TICK():
	pass

func _ready():
	add_to_group("tick")
