extends Node

export(bool) var input = true

var enabled = true
var focused = false
var tension = 0

var color = null

var wires_list = []
var pin_neighbors = []

func maintain_tension(t, node): # actual source of tension!
	if enabled:
		tension = t

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
			color = Color(clamp(tension,0,100)/100, 0, 0, 1)
		else:
			color = Color(0, 0, clamp(tension,-100,0)/-100, 1)
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
