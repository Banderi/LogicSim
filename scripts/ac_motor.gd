extends Polygon2D

var speed = 5
var amplitude = 100

var phase = 0.5

func TICK():
	# live
	$outputs.get_child(0).maintain_tension(amplitude * sin(phase + PI * 0/3), self)
	$outputs.get_child(1).maintain_tension(amplitude * sin(phase + PI * 2/3), self)
	$outputs.get_child(2).maintain_tension(amplitude * sin(phase + PI * 4/3), self)

	# neutrals
	$inputs.get_child(0).maintain_tension(amplitude * sin(phase + PI * 3/3), self)
	$inputs.get_child(1).maintain_tension(amplitude * sin(phase + PI * 5/3), self)
	$inputs.get_child(2).maintain_tension(amplitude * sin(phase + PI * 7/3), self)

	print(str(self) + " (AC generator) : TICK")

func _process(delta):
#	return
	phase += delta * speed
	while phase >= 2 * PI:
		phase -= 2 * PI

func _ready():
	add_to_group("components")
