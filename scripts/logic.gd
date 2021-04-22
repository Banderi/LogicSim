extends Node

var probe = null

var simulation_speed = 0.5
var iteration_times = 4
var simulation_go = -1

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
func proper(v, u, spaced = false, full_units = false, rectify = 1.0, digits = 0.01):
	v = v / rectify
	var proper_str = ""
	for pr in prefixes:
		if abs(v) >= prefixes[pr][1] || prefixes[pr][0] == "p":
			var v_corr = stepify(v/prefixes[pr][1], digits)
			var units = " " if spaced else ""
			units += pr if full_units else prefixes[pr][0]
			units += u
			proper_str = str(v_corr) + units
	return proper_str

var circuits = {
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
	},

	###

	1: { # test
		"name": "test",
		"inputs": [
			["Input A", 400],
			["Input B", 500]
		],
		"outputs": [
			["Output A", 400],
			["Output B", 500]
		],
		"color": "b0b0b0",
		"circuits": [ # single AND gate for now...
			[-99,			# circuit ID (negatives are reserved)
			 -100, -250]	# circuit position
		],
		# wires ALWAYS are laid out cascading from inputs to outputs -
		# will be rearranged automatically if a wire connects to INPUTS
		"wires": [



			[ # wire one
				[-99,0], [1,0] # from circuit -99 (ouput 0) to circuit 0 (input 0)
			],
			[ # wire two
				[-99,0], [1,1] # from circuit -99 (ouput 0) to circuit 0 (input 1)
			],
			[ # wire three
				[-99,1], [1,0] # from circuit -99 (ouput 1) to circuit 0 (input 1)
			]
		]
	},

	2: { # test2
		"name": "AC setup",
		"inputs": [],
		"outputs": [],
		"color": "000000",
		"circuits": [
			[-201,			# circuit ID (negatives are reserved)
			 -300, -120],	# circuit position

			[-999,
			 100, -180],		# free floating pin
			[-999,
			 100, 100],		# free floating pin
			[-999,
			 -300, 100],		# free floating pin

#			[-999,
#			 -253, -90],		# free floating pin
		],
		# wires ALWAYS are laid out cascading from inputs to outputs -
		# will be rearranged automatically if a wire connects to INPUTS
		"wires": [
			[ # wire one
				[0,0], [1,0] # from circuit 0 (ouput 0) to circuit 1 (input 0)
			],
			[[1,0], [2,0]],
			[[2,0], [3,0]],
			[[3,0], [0,0]],

			[[0,1], [0,1]]

#			[[0,0], [4,0]],
#			[[0,1], [4,0]],
#			[[0,2], [4,0]],
		]
	},

	3: { # test3
		"name": "test 3",
		"inputs": [],
		"outputs": [],
		"color": "000000",
		"circuits": [
			# free floating pins
			[-999, Vector2(-400, -200), 100],
			[-999, Vector2(-400, -100)],
			[-999, Vector2(-400, 0), -100],

			[-999, Vector2(-100, -200), 50],
			[-999, Vector2(-100, -100)],
			[-999, Vector2(-100, 0), 0],
		],
		"wires": [
			[[0,0], [1,0], 0.25], # from circuit 0 (ouput 0) to circuit 1 (input 0)
			[[1,0], [2,0], 1],

			[[3,0], [4,0], 1],
			[[4,0], [5,0], 1],

			[[1,0], [4,0], 1],
		]
	}
}
