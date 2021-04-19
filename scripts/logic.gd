extends Node

var probe = null

var propagation_dropoff = 1
var simulation_speed = 0.01

var network_resistances = {}
var networks_by_component = {}

var NETWORK_RESET = true

func compute_network_resistances(node, network):
	# only continue if selected node hasn't been computed yet
	if !networks_by_component.has(node):
		networks_by_component[node] = network
		if network_resistances.has(network):
			network_resistances[network] += node.resistance
		else:
			network_resistances[network] = node.resistance

		# propagate down the tree
		for w in node.orig_pin.wires_list:
			compute_network_resistances(w, network)
		for w in node.dest_pin.wires_list:
			compute_network_resistances(w, network)

func get_total_network_resistance(node):
	if NETWORK_RESET:
		network_resistances = {}
		networks_by_component = {}
		compute_network_resistances(node, 0)
		NETWORK_RESET = false
	return network_resistances[networks_by_component[node]]



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
			[-999, Vector2(-300, -100), 100],
			[-999, Vector2(-300, 0)],
			[-999, Vector2(-300, 100), -100],

			[-999, Vector2(0, -100), 50],
			[-999, Vector2(0, 0)],
			[-999, Vector2(0, 100), 0],
		],
		"wires": [
			[[0,0], [1,0], 1], # from circuit 0 (ouput 0) to circuit 1 (input 0)
			[[1,0], [2,0], 1],

			[[3,0], [4,0], 1],
			[[4,0], [5,0], 1],

			[[1,0], [4,0], 1],
		]
	}
}
