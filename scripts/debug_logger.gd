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
func logme(node, txt, color = Color(1,1,1)):
	if debug_logger == null:
		debug_logger = logic.main.debug_logger

	if logic.probe.probing == null || logic.probe.probing != node:
		return
	if node != last_node:
		clear()
	last_node = node

	debug_logger.push_color(color)
	debug_logger.append_bbcode("\n")
	debug_logger.append_bbcode(str(txt))
	debug_logger.pop()
