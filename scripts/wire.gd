extends Line2D

var orig_pin = null
var dest_pin = null
#var dest_circuit = null
#var dest_pin_slot = 0

#var speed = 40
var voltage = 0
var current = 0

var resistivity = 0.01
var area = 1
var length = 0

var resistance = 0

func attach(orig, dest):
	orig_pin = orig
	dest_pin = dest
	orig_pin.wires_list.append(self)
	dest_pin.wires_list.append(self)
	orig_pin.pin_neighbors.append(dest_pin)
	dest_pin.pin_neighbors.append(orig_pin)
func detach():
	orig_pin.wires_list.erase(self)
	dest_pin.wires_list.erase(self)
	orig_pin.pin_neighbors.erase(dest_pin)
	dest_pin.pin_neighbors.erase(orig_pin)

# from https://github.com/juddrgledhill/godot-dashed-line/blob/master/line_harness.gd
func draw_dashed_line(from, to, phase, color, width, dash_length = 5, gap = 2.5, antialiased = false):
	var length = (to - from).length()
	var normal = (to - from).normalized()
	var dash_step = normal * dash_length

#	# bind phase to length of wire
	while abs(phase) > abs(dash_length + gap):
		phase = abs(phase) - abs(dash_length + gap)

	# for each step...
	for s in range(-1, (length/(dash_length + gap)) + 1):

		# first, calculate linear values
		var linear_start = s * (dash_length + gap) + phase
		var linear_end = linear_start + dash_length

		# then, get actual 2D positions
		var segment_start = from + normal * min(length, max(0, linear_start))
		var segment_end = from + normal * min(length, max(0, linear_end))

		draw_line(segment_start, segment_end, color, width, antialiased)

###

func update_resist():
	resistance = resistivity * length / area

func TICK():
	voltage = 0
#	var voltage_drop = 0
	if dest_pin.enabled && orig_pin.enabled:
		voltage = dest_pin.tension - orig_pin.tension
#	voltage += (voltage_drop - voltage) * logic.propagation_dropoff

#	current = voltage / resistance # WRONG!!!!!



	update()
	print(str(self) + " (wire) : TICK")

var phase = 0
func _process(delta):
	phase += 0.01 * voltage * 4
	if voltage == 0:
		phase = 0

func _draw():
	if (true):
		var d = abs(voltage)/50
		draw_dashed_line(
			orig_pin.global_position,
			dest_pin.global_position,
			-phase, Color(d, d, 0, 1), 5,
			10, 5, false)
	else:
		var red = min(max(0,voltage), 100)/100
		var blue = max(min(0,voltage), -100)/-100
		draw_dashed_line(
			orig_pin.global_position,
			dest_pin.global_position,
			phase, Color(red, 0, blue, 1), 5,
			10, 5, false)

func _ready():
	add_to_group("wires")
	points = [
		orig_pin.global_position,
		dest_pin.global_position
	]
	set_global_position(Vector2())

	length = (orig_pin.global_position - dest_pin.global_position).length()
#	update_resist()
