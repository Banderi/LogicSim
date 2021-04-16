extends Polygon2D

var speed = 5
var amplitude = 100

var phase = 0

func TICK():
	# live
	$outputs.get_child(0).apply_tension(amplitude * sin(phase + PI * 0/3))
	$outputs.get_child(1).apply_tension(amplitude * sin(phase + PI * 2/3))
	$outputs.get_child(2).apply_tension(amplitude * sin(phase + PI * 4/3))

	# neutrals
	$inputs.get_child(0).apply_tension(amplitude * sin(phase + PI * 3/3))
	$inputs.get_child(1).apply_tension(amplitude * sin(phase + PI * 5/3))
	$inputs.get_child(2).apply_tension(amplitude * sin(phase + PI * 7/3))

func _process(delta):
	phase += delta * speed
	while phase >= 2 * PI:
		phase -= 2 * PI

func _ready():
	add_to_group("tick")
