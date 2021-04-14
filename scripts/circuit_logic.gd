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
		"circuits": [
			[-99, -100, -250] # single AND gate
		],
		"wires": [
			[ # main inputs
				[ # input A
					[0,0], # single wires coming off of single pin
					[0,1]
				],
				[ # input B
					[0,1]
				]
			],
			[ # circuit 0
				[ # output 1 (only output)
					[99,0] # wire one (only wire)
				]
			]
		]
	}
}
