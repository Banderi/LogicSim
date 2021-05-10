extends Node

export(bool) var can_interact = true
var node_type = -999

export(bool) var input = true

# tension source
export(bool) var is_source = false
export var tension_static = 0.0
export var tension_amplitude = 0.0
export var tension_speed = 0.0
export var tension_phase = 0.0

var owner_node = null

var init_arr = null

var enabled = true
var focused = false
var oldtension = 0.0
var tension = 0.0

var color = null

var wires_list = []
var pin_neighbors = []

func maintain_tension(): # actual source of tension!
	if is_source:
		tension = tension_static + 2 * tension_amplitude * sin(tension_phase * PI / 180)

		# update tension phase
		tension_phase += logic.simulation_speed * tension_speed * 4
		while tension_phase >= 360:
			tension_phase -= 360

var tension_neighbors = {}
func add_tension_from_neighbor(t, conductance, node, source_t = 0, degree = 0):
	if enabled && !tension_neighbors.has(node):
		tension_neighbors[node] = [t, conductance, degree, source_t]

func sum_up_neighbor_tensions():

	# these (inf conductance sources) have priority over everything else
	var instant_tension = 0
	var instant_tension_neighbors = 0

	# calculate total conductance
	var total_neighboring_conductance = 0
	var tn = tension_neighbors.size()
	for t in tension_neighbors:
		var data = tension_neighbors[t]
		if str(data[1]) == "inf":
			instant_tension += data[0]
			instant_tension_neighbors += 1
		else:
			total_neighboring_conductance += data[1]

	# calculate overall tension applied to this pin
	var overall_tension = 0
	if instant_tension_neighbors > 0:
		overall_tension = instant_tension / instant_tension_neighbors
	elif total_neighboring_conductance != 0:
		for t in tension_neighbors:
			var data = tension_neighbors[t]
			if str(data[1]) == "inf":
				break
			else:
				overall_tension += (data[0] * data[1]) / total_neighboring_conductance

	# actual tension reached
	oldtension = tension
	var tension_diff = overall_tension - tension
	if (tn > 0):
		tension += tension_diff

	cleanup_tensions()

func propagate():
	if enabled:
		for w in wires_list:
			w.conduct_neighboring_tension(tension, self)

func cleanup_tensions():
	# reset tension source/sink
	var s = "+" if tension > 0.01 else ""
	$L/Label2.text = s + str(stepify(tension,0.01)) + "V"
	tension_neighbors = {}

func _process(delta):
	$L/Label.text = "_/_"
	if enabled:
		$L/Label.text = "___"
		color = logic.get_tension_color(tension)
	else:
		color = logic.colors_tens[3]
	$L/Label.visible = false
	if focused:
		color = logic.colors_tens[4]
		if can_interact && !logic.main.selection_mode & 1:
			$L/Label.visible = true

	$Pin.color = color

func _on_Pin_mouse_entered():
	focused = true
	logic.main.node_selection = self

func _on_Pin_mouse_exited():
	focused = false

var orig_position = Vector2()
func _input(event):
	if focused:
		if logic.main.selection_mode & 1:
			if Input.is_action_just_pressed("mouse_left"):
				orig_position = owner_node.position
			if event is InputEventMouseMotion && Input.is_action_pressed("mouse_left"):
				owner_node.position = orig_position + (event.position - logic.main.orig_drag_point) * logic.main.camera.zoom

				# grid snapping!
				if logic.main.selection_mode & 2:
					var rx = round(owner_node.position.x / 50.0) * 50.0
					var ry = round(owner_node.position.y / 50.0) * 50.0
					owner_node.position = Vector2(rx, ry)

				for i in owner_node.get_child(0).get_children():
					for w in i.wires_list:
						w.redraw()
				for o in owner_node.get_child(1).get_children():
					for w in o.wires_list:
						w.redraw()
		elif logic.main.buildmode_stage == null:
			if Input.is_action_just_released("mouse_left"):
				enabled = !enabled
			if Input.is_action_just_released("mouse_right"):
				logic.probe.attach(self, 0)

func _ready():
	owner_node = get_parent().get_parent()
	add_to_group("pins")
	add_to_group("sources")
