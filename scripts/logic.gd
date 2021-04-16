extends Node

var probe = null

var propagation_dropoff = 1

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
		"name": "DC motor",
		"inputs": [["neutral"]],
		"outputs": [["live"]]
	},
	-201: {
		"name": "AC motor",
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
		"name": "AC Motor setup",
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

			[-999,
			 -253, -90],		# free floating pin
		],
		# wires ALWAYS are laid out cascading from inputs to outputs -
		# will be rearranged automatically if a wire connects to INPUTS
		"wires": [
#			[ # wire one
#				[0,0], [1,0] # from circuit 0 (ouput 0) to circuit 1 (input 0)
#			],
#			[[1,0], [2,0]],
#			[[2,0], [3,0]],
#			[[3,0], [0,0]],

#			[[0,1], [0,1]]

			[[0,0], [4,0]],
			[[0,1], [4,0]],
			[[0,2], [4,0]],
		]
	}
}
