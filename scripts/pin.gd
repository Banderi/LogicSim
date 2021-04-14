extends ColorRect

export(bool) var input = true

var enabled = false

func propagate():

	pass


# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("pins")
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if enabled:
		color = Color("ff0000")
	else:
		color = Color("000000")

	propagate()
