extends Node

export(bool) var can_interact = true
var node_type = -999
#var node_token = null # inherited from parent?

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
func add_tension_from_neighbor(WIRE_NODE, t, conductance, node, source_t = 0, degree = 0):
#	DebugLogger.logme(self, "Received tension: " + logic.proper(t, "Volts", true))
	if enabled && !tension_neighbors.has(node):
#		DebugLogger.logme(self, "Received tension: " + logic.proper(t, "Volts", true))
		tension_neighbors[node] = [t, conductance, degree, source_t, WIRE_NODE]
func add_tension_drop_from_neighbor(SOURCE_PIN_NODE, WIRE_NODE, voltage):
	if enabled && !tension_neighbors.has(SOURCE_PIN_NODE):
		tension_neighbors[SOURCE_PIN_NODE] = [voltage, WIRE_NODE]
func sum_up_neighbor_tensions_OLD():
	DebugLogger.logme(self, "Summing up all the tensions received...")
	DebugLogger.logme(self, "Neighbors: " + str(tension_neighbors.size()))

	# these (inf conductance sources) have priority over everything else
	var instant_tension = 0
	var instant_tension_neighbors = 0

	# calculate overall tension applied to this pin
#	var overall_tension = 0
	var total_instant_tension = 0
	var total_non_instant_tension = 0

	# calculate total conductance
	var total_neighboring_conductance = 0
	var tn = tension_neighbors.size()
	for t in tension_neighbors:
		var data = tension_neighbors[t]
		DebugLogger.logme(self, "  > Received: " + logic.proper(data[0], "V", true) + " @ " + logic.proper(data[1], "S", true) + " from " + str(t))
		if str(data[1]) == "inf":
#			if t.is_source == true:
			instant_tension += data[0]
			instant_tension_neighbors += 1
#			else:
#				total_neighboring_conductance += 1
#				total_non_instant_tension += data[0]
		else:
			total_neighboring_conductance += data[1]
	DebugLogger.logme(self, "Total conductance: " + logic.proper(total_neighboring_conductance, "S", true))


	if instant_tension_neighbors > 0:
		total_instant_tension = instant_tension / instant_tension_neighbors
	DebugLogger.logme(self, "Instant Tension: " + logic.proper(total_instant_tension, "V", true))

	if total_neighboring_conductance != 0:
		for t in tension_neighbors:
			var data = tension_neighbors[t]
			if str(data[1]) == "inf":
#				if t.is_source != true:
#					total_non_instant_tension += (data[0] * 1.0) / total_neighboring_conductance
#				else:
				break
			else:
				total_non_instant_tension += (data[0] * data[1]) / total_neighboring_conductance
	DebugLogger.logme(self, "Non-Instant Tension: " + logic.proper(total_non_instant_tension, "V", true))

	var overall_tension = total_non_instant_tension + total_instant_tension

	# actual tension reached
	oldtension = tension
	var tension_diff = overall_tension - tension
#	var tension_diff = total_non_instant_tension - 0.5 * (tension - total_instant_tension)
	if (tn > 0):
		tension += tension_diff * 0.5

	cleanup_tensions()
func sum_up_neighbor_tensions():
	DebugLogger.logme(self, "Summing up all the tensions received...")
	DebugLogger.logme(self, "Neighbors: " + str(tension_neighbors.size()))

	var overall_tension_drop = 0
	for t in tension_neighbors:
		var data = tension_neighbors[t]
		overall_tension_drop += data[0]
		DebugLogger.logme(self, "  > Received: " + logic.proper(data[0], "V", true) + " @ " + logic.proper(data[1].conductance, "S", true) + " from " + str(t))
	if (tension_neighbors.size() > 0):
		overall_tension_drop = overall_tension_drop / tension_neighbors.size()

	DebugLogger.logme(self, "Total tension drop: " + logic.proper(overall_tension_drop, "V", true))

	oldtension = tension
	tension += overall_tension_drop
	cleanup_tensions()

func propagate_OLD():
	DebugLogger.clearme(self)
	DebugLogger.logme(self, self)
	if enabled:
		DebugLogger.logme(self, "Propagating tensions...")
#		DebugLogger.logme(self, "Last neighbors:\n" + str(tension_neighbors_lasttime))
		for w in wires_list:
			var target_pin = w.get_B_from_A(self)
			var propagating_tension = tension # start from our total, current, proper tension...

			# reduce tension by the LAST received tension from this pin!
			if tension_neighbors_lasttime.has(target_pin):
				var last_tension_received_from_B = tension_neighbors_lasttime[target_pin][0]
#				propagating_tension -= last_tension_received_from_B
#				DebugLogger.logme(self, "LAST TENSION: " + logic.proper(total_non_instant_tension, "V", true))
				pass
			w.conduct_neighboring_tension(propagating_tension, self)
			pass
	else:
		DebugLogger.logme(self, "Pin is disabled! Sleeping...")
	DebugLogger.logme(self, "")
func propagate():
	DebugLogger.clearme(self)
	DebugLogger.logme(self, self)

	if !enabled:
		DebugLogger.logme(self, "Pin is disabled! Sleeping...\n")
		return

	DebugLogger.logme(self, "Propagating tensions...")
	for w in wires_list:
		if !w.is_enabled():
			DebugLogger.logme(self, "  > Wire is asleep!")
		else:
			var target_pin = w.get_B_from_A(self)

			var tension_A = tension
			var tension_B = target_pin.tension

			var voltage = w.query_tension_drop(self, target_pin, tension_A, tension_B)

			DebugLogger.logme(self, "  > SENDING out " + logic.proper(voltage, "V", true) + " to " + str(target_pin))
			target_pin.add_tension_drop_from_neighbor(self, w, -voltage)
	DebugLogger.logme(self, "")

var tension_neighbors_lasttime = {}
func cleanup_tensions():
	# reset tension source/sink
	var s = "+" if tension > 0.01 else ""
	$L/Label2.text = s + str(stepify(tension,0.01)) + "V"
	tension_neighbors_lasttime = tension_neighbors
	tension_neighbors = {}

func _process(delta):
	$L/Label.text = "_/_"
	if enabled:
		$L/Label.text = "___"
		color = logic.get_tension_color(tension)
	else:
		color = logic.colors_tens[3]
	$L/Label.visible = false
	if !is_source:
		$L/Label2.visible = false
	if focused:
		color = logic.colors_tens[4]
		if can_interact && !logic.main.selection_mode & 1:
			$L/Label.visible = true
		$L/Label2.visible = true

#	$L/Label3.text = ""
	$L/Label3.text = str(focused) + " " + str(soft_focus)

	$Pin.color = color

var orig_position = Vector2()
onready var hover_element = $Pin
func _input(event):

	# check if mouse is ACTUALLY inside the element
	var local_p = hover_element.get_local_mouse_position()
	var local_r = hover_element.get_global_rect()
	var size_r = Rect2(Vector2(0,0), local_r.size)
	if size_r.has_point(local_p) && logic.main.node_selection == null:
		soft_focus = true
		logic.main.node_selection = self
	else:
		soft_focus = false

	if focused:
		if logic.main.edit_moving:
			if Input.is_action_just_pressed("mouse_left"):
				orig_position = owner_node.position
			if event is InputEventMouseMotion && Input.is_action_pressed("mouse_left"):
				owner_node.position = orig_position + (event.position - logic.main.click_origin.left) * logic.main.camera.zoom

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

				# delegate updates to MAIN;
				# ask owner to bundle array of node data, which will then update
				# the correct field in the memory struct by use of their TOKEN
				owner_node.update_node_data(self)
		elif logic.main.buildmode_stage == null:
			if Input.is_action_just_released("mouse_left"):
				enabled = !enabled
			if Input.is_action_just_released("mouse_right"):
				logic.probe.attach(self, 0)

var focused = false
var soft_focus = false
func _on_Pin_mouse_entered():
	focused = true

func _on_Pin_mouse_exited():
	focused = false

func _ready():
	owner_node = get_parent().get_parent()
	add_to_group("pins")
	add_to_group("sources")
