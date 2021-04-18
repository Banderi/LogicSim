extends Node

export(bool) var input = true

# tension source
export(bool) var is_source = false
export var tension_speed = 1
export var tension_amplitude = 20
export var tension_source = 0
export var tension_phase = 0

var enabled = true
var focused = false
var oldtension = 0
var tension = 0

var color = null

var wires_list = []
var pin_neighbors = []

func maintain_tension(): # actual source of tension!
	if enabled && is_source:
		tension = tension_source + 2 * tension_amplitude * sin(tension_phase * PI / 180)

		# update tension phase
		tension_phase += logic.simulation_speed * tension_speed * 400
		while tension_phase >= 360:
			tension_phase -= 360

var tension_neighbors = []
func add_tension_from_neighbor(t, node):
	if enabled:
		tension_neighbors.append([node, t * logic.propagation_dropoff])

func sum_up_neighbor_tensions():
	# calculate overall tension applied to this pin
	var tn = tension_neighbors.size() + 1
	var overall_tension = tension / tn
	for t in tension_neighbors:
		overall_tension += t[1] / tn

	# actual tension reached
	oldtension = tension
	if (tn):
		tension += (overall_tension - tension) * logic.propagation_dropoff
	print(str(self) + " (pin) : sum_up_neighbor_tensions")

func propagate():
	if enabled:
		for p in pin_neighbors:
			p.add_tension_from_neighbor(tension, self)
	print(str(self) + " (pin) : propagate")

func cleanup_tensions():
	# reset tension source/sink
	$Label2.text = str(stepify(tension,0.01))
	$Label3.text = str(tension_neighbors.size())
	tension_neighbors = []
	print(str(self) + " (pin) : cleanup_tensions")

func _process(delta):
	$Label.text = "_/_"
	if enabled:
		$Label.text = "___"
		if tension > 0:
			color = Color(clamp(tension,0,100)/50, 0, 0, 1)
		else:
			color = Color(0, 0, clamp(tension,-100,0)/-50, 1)
	else:
		color = Color("323232")
	if focused:
		color = Color("50a090")
		$Label.visible = true
	else:
		$Label.visible = false

	$Pin.color = color

func _on_Pin_mouse_entered():
	focused = true

func _on_Pin_mouse_exited():
	focused = false

func _input(event):
	if focused:
		if event is InputEventMouseButton && !event.pressed:
			if event.button_index == BUTTON_LEFT:
				enabled = !enabled
			elif event.button_index == BUTTON_RIGHT:
				logic.probe.attach(self)

func _ready():
	add_to_group("pins")
	add_to_group("sources")
