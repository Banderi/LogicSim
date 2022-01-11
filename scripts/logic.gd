extends Node

var probe = null
var main = null

#var simulation_speed = 0.5
#var iteration_times = 1
var simulation_go = -1

# temporary solution...
var available_iteration_times_temp = [
	1,
	2,
	4,
	10,
	20,
	40,
	60,
	100,
	200,
	400
]

var colors_tens = [
	Color(0,0,1,1),				# low tension
	Color(0.36,0.36,0.36,1),	# neutral
	Color(1,0,0,1),				# high tension

	Color("000000"),	# disabled
	Color("50a090")		# focused
]
var colors_falloff = 10
func get_tension_color(tension):
	var t = abs(tension / colors_falloff)
	var color
	if tension < 0:
		color = colors_tens[0] * min(1, t)
		color += colors_tens[1] * max(0, 1 - t)
	elif tension > 0:
		color = colors_tens[2] * min(1, t)
		color += colors_tens[1] * max(0, 1 - t)
	else:
		color = colors_tens[1]
	color.a = 1
	return color

var prefixes = {
	"pico":		["p",0.000000000001],
	"nano":		["n",0.000000001],
	"micro":	["µ",0.000001],
	"milli":	["m",0.001],
	"":			["",1.0],
	"kilo":		["k",1000.0],
	"mega":		["M",1000000.0],
	"giga":		["G",1000000000.0],
	"tera":		["T",1000000000000.0],
	"peta":		["P",1000000000000000.0],
}
func proper(v, u, spaced = false, full_units = false, rectify = 1.0, digits = 0.01, absolute = false):
	if str(v) != "inf" && str(v) != "-inf":
		v = v / rectify
		if absolute:
			v = abs(v)
	else:
		if absolute:
			v = "inf"
		var units = " " if spaced else ""
		return v + units + u
	var proper_str = ""
	for pr in prefixes:
		if abs(v) >= prefixes[pr][1] || prefixes[pr][0] == "p":
			var v_corr = stepify(v/prefixes[pr][1], digits)
			var units = " " if spaced else ""
			units += pr if full_units else prefixes[pr][0]
			units += u
			proper_str = str(v_corr) + units
	return proper_str

# wires ALWAYS are laid out cascading from inputs to outputs -
# will be rearranged automatically if a wire connects to INPUTS
var base_circuits = {
	-99: { # AND gate
		"name": "and",
		"inputs": [
			["A"],
			["B"]
		],
		"outputs": [
			["Output"]
		],
		"color": "f4a713"
	},
	-98: { # NOT gate
		"name": "not",
		"inputs": [
			["Input"]
		],
		"outputs": [
			["Output"]
		],
		"color": "b82e2e"
	},
	-200: {
		"name": "DC source",
		"inputs": [["neutral"]],
		"outputs": [["live"]]
	},
	-201: {
		"name": "AC source",
		"inputs": [
			["n1"],
			["n2"],
			["n3"],
		],
		"outputs": [
			["l1"],
			["l2"],
			["l3"]
		]
	}
}
var circuits = {
	0: { # test3
		"name": "test 3",
		"inputs": [],
		"outputs": [],
		"color": "000000",
		"circuits": {
			-999: [ # free floating pins
				[null, Vector2(-400, -200), true, 100],
				[null, Vector2(-400, -100)],
				[null, Vector2(-400, 0), true, -100],

				[null, Vector2(-100, -200), true, 50],
				[null, Vector2(-100, -100)],
				[null, Vector2(-100, 0), true, 0],
			],
			-998: [ # wire-based component
				[null, [0,0], [1,0]], # from circuit 0 (ouput 0) to circuit 1 (input 0)
				[null, [1,0], [2,0]],

				[null, [3,0], [4,0]],
				[null, [4,0], [5,0]],

				[null, [1,0], [4,0], [500, 0]],
			]
		}
	}
}
var prefs_defaults = {
	"lastcircuit": 1,
	"iteration_times": 1,
	"simulation_speed": 0.5
}
var prefs = prefs_defaults
func get_pref(pref):
	if (!pref in prefs):
		prefs[pref] = prefs_defaults[pref]
	return prefs[pref]
func set_pref(pref, v):
	prefs[pref] = v
	main.save_prefs()
