extends Node

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
			[ # main inputs
				[ # input A
					[0,0],	# wire connects to: circuit 0, input 0
					[0,1]	# wire connects to: circuit 0, input 1
				],
				[ # input B
					[0,1]	# wire connects to: circuit 0, input 1
				]
			],
			[ # circuit 0
				[ # output 1 (only output)
					[99,0]	# wire connects to: circuit 99 (OUTPUTS), index 0
				]
			]
		]
	}
}
