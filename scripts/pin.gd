extends Node

export(bool) var input = true

# tension source
export(bool) var is_source = false
export var tension_static = 0.0
export var tension_amplitude = 0.0
export var tension_speed = 0.0
export var tension_phase = 0.0

var init_arr = null

var enabled = true
var focused = false
var oldtension = 0.0
var tension = 0.0

var color = null

var wires_list = []
var pin_neighbors = []

func maintain_tension(): # actual source of tension!
	if enabled && is_source:
		tension = tension_static + 2 * tension_amplitude * sin(tension_phase * PI / 180)

		# update tension phase
		tension_phase += logic.simulation_speed * tension_speed * 400
		while tension_phase >= 360:
			tension_phase -= 360

var tension_neighbors = {}
func add_tension_from_neighbor(t, node, degree):
	if enabled && !tension_neighbors.has(node):
		tension_neighbors[node] = [t * logic.propagation_dropoff, degree]

func sum_up_neighbor_tensions(pure_sum = false):
	var tn = 1
	var overall_tension = tension

	# calculate overall tension applied to this pin
	if pure_sum:
		tn = tension_neighbors.size()
#		overall_tension = tension / tn
		for t in tension_neighbors:
			overall_tension += (tension_neighbors[t][0] - tension) / ((tension_neighbors[t][1] + 1) * tn)
	else:
		tn = tension_neighbors.size() + 1
		overall_tension = tension / tn
		for t in tension_neighbors:
			overall_tension += tension_neighbors[t][0] / tn

	# actual tension reached
	oldtension = tension
	tension = overall_tension
#	if (tn):
#		tension += (overall_tension - tension) * logic.propagation_dropoff

func propagate(instant = false, source_tension = tension, degree = 0, source_node = self):
	if enabled:
		for w in wires_list:
#			w.conduct_neighboring_tension(tension, self)
			if (is_source && degree == 0) || (degree > 0 && source_node != self):
				w.conduct_instant_tension(source_tension, degree, self, source_node)

func cleanup_tensions():
	# reset tension source/sink
	var s = "+" if tension > 0.01 else ""
	$L/Label2.text = s + str(stepify(tension,0.01)) + "V"
	$L/Label3.text = ""
	for t in tension_neighbors:
		$L/Label3.text += "\n" + str(tension_neighbors[t])
	tension_neighbors = {}

func _process(delta):
	$L/Label.text = "_/_"
	if enabled:
		$L/Label.text = "___"
		color = logic.get_tension_color(tension)
	else:
		color = logic.colors_tens[3]
	if focused:
		color = logic.colors_tens[4]
		$L/Label.visible = true
	else:
		$L/Label.visible = false

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
