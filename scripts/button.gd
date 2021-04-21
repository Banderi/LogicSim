tool
extends Button


# Called when the node enters the scene tree for the first time.
func _draw():
	$Label.text = text
	$Label.rect_size = rect_size / 0.4


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
