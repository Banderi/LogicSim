extends Line2D

var orig_pin = null
var dest_pin = null
#var dest_circuit = null
#var dest_pin_slot = 0

var speed = 40
var live = false

func attach(orig, dest):
	orig_pin = orig
	dest_pin = dest
	orig_pin.wires_list.append(self)
	dest_pin.wires_list.append(self)
func detach():
	orig_pin.wires_list.erase(self)
	dest_pin.wires_list.erase(self)

# from https://github.com/juddrgledhill/godot-dashed-line/blob/master/line_harness.gd
func draw_dashed_line(from, to, phase, color, width, dash_length = 5, gap = 2.5, antialiased = false):
	var length = (to - from).length()
	var normal = (to - from).normalized()
	var dash_step = normal * dash_length

	# bind phase to length of wire
	while phase > (dash_length + gap):
		phase -= (dash_length + gap)

	# for each step...
	for s in range(-1, (length/(dash_length + gap)) + 1):

		# first, calculate linear values
		var linear_start = s * (dash_length + gap) + phase
		var linear_end = linear_start + dash_length

		# then, get actual 2D positions
		var segment_start = from + normal * min(length, max(0, linear_start))
		var segment_end = from + normal * min(length, max(0, linear_end))

		draw_line(segment_start, segment_end, color, width, antialiased)

func _ready():
	points = [
		orig_pin.get_child(0).global_position + Vector2(10,10),
		dest_pin.get_child(0).global_position + Vector2(10,10)
	]
	set_global_position(Vector2())

var time = 0
func _process(delta):
	time += delta * speed
	update()

func _draw():
	if live:
		draw_dashed_line(
			orig_pin.get_child(0).global_position + Vector2(10,10),
			dest_pin.get_child(0).global_position + Vector2(10,10),
			time, Color(1, 0, 0, 1), 5, 10, 5, false)
