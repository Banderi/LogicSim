extends Node

var debug_logger = null
var last_node = null

func clear():
	if debug_logger == null:
		debug_logger = logic.main.debug_logger
	debug_logger.clear()
func clearme(node):
	if debug_logger == null:
		debug_logger = logic.main.debug_logger
	if logic.probe.probing == null || logic.probe.probing != node:
		return
	clear()
	last_node = node
func logchunk(txt, color):
	debug_logger.push_color(color)
	debug_logger.append_bbcode(str(txt))
	debug_logger.pop()
func logme(node, array):
	if debug_logger == null:
		debug_logger = logic.main.debug_logger

	if logic.probe.probing == null || logic.probe.probing != node:
		return
	if node != last_node:
		clear()
	last_node = node

	debug_logger.append_bbcode("\n")

	if array is Array:
		var r = ceil(float(array.size()) / 2.0)
		for t in range(r):
			var txt = array[2 * t]
			var color = array[2 * t + 1] if array.size() > (2 * t + 1) else Color(1,1,1)
#			var chunk = array[t]
#			var txt = chunk[0] if chunk is Array else chunk
#			var color = chunk[1] if (chunk is Array && chunk.size() > 0) else Color(1,1,1)
			logchunk(txt, color)
	else:
		logchunk(array, Color(1,1,1))
