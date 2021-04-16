extends ColorRect

export(bool) var input = true

var enabled = true
var focused = false
#var applied_tension = 0
var tension = 0

var wires_list = []
var pin_neighbors = []

var tension_sources = []
var tension_sources_delegated = []
func apply_tension(t):
	if enabled:
		tension_sources_delegated.append(t * logic.propagation_dropoff)

func TICK():
	# calculate overall tension applied to this pin
	var tn = tension_sources.size()
	var overall_tension = 0
	for t in tension_sources:
		overall_tension += t/tn

	# actual tension reached
	if (tn):
		tension += (overall_tension - tension) * logic.propagation_dropoff

	if enabled:
		for p in pin_neighbors:
			p.apply_tension(overall_tension)

	# reset tension source/sink
	$Label2.text = str(stepify(tension,0.01))
	$Label3.text = str(tension_sources.size())
	tension_sources = tension_sources_delegated
	tension_sources_delegated = []

func _process(delta):
	$Label.text = "_/_"
	if enabled:
		$Label.text = "___"
		if tension > 0:
			color = Color(clamp(tension,0,100)/100, 0, 0, 1)
		else:
			color = Color(0, 0, clamp(tension,-100,0)/-100, 1)
	else:
		color = Color("50a090")
	if focused:
		color = Color("323232")
		$Label.visible = true
	else:
		$Label.visible = false

	update()

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
	add_to_group("tick")
