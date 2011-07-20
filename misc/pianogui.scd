(
var	win, kbd, voicer;

Proto {
	~whiteKeyWidth = 35;
	~blackKeyRatio = 0.32;
	~numWhiteKeys = 21;
	~height = 100;
	~blackHeightRatio = 0.64;
	~blackKeyIndices = #[0, 1, 3, 4, 5];
	~blackKeyOffsets = [-1/8, 1/8, -1/8, 0, 1/8];

	~prep = { |parent, bounds|
		bounds = bounds.resizeTo(~whiteKeyWidth * ~numWhiteKeys, ~height);
		~view = UserView(parent, bounds)
		.background_(Color.white)
		.drawFunc_(e { |view|
			var	blackKeyHeight = ~height * ~blackHeightRatio;
			Pen.color = Color.black;
			~numWhiteKeys.do { |i|
				Pen	.moveTo((~whiteKeyWidth * (i+1)) @ 0)
					.lineTo((~whiteKeyWidth * (i+1)) @ ~height)
			};
			Pen.stroke;
			(~numWhiteKeys * 5 div: 7).do { |i|
				var	oct = i div: 5, wstep = ~blackKeyIndices.wrapAt(i);
				Pen.fillRect(Rect(
					~whiteKeyWidth * (7 * oct + wstep + ~blackKeyOffsets.wrapAt(i) + 1 - ~blackKeyRatio),
					0,
					~whiteKeyWidth * ~blackKeyRatio * 2,
					blackKeyHeight
				));
			};
			~userDraw.(view);
		});

		~userprep.();
		~view.refresh;
		currentEnvironment
	};
} => PR(\pianoGui);

PR(\pianoGui).clone {
	~blackKeyIndices = #[0, 2, 3, 5, 6];
	~blackKeyOffsets = PR(\pianoGui).blackKeyOffsets.rotate(1);
	~whiteKeyPCs = #[0, 2, 3, 5, 7, 8, 10];
	~blackKeyPCs = #[1, 4, 6, 9, 11];
	~midibase = 57;
	~notes = #[57, 59, 61, 62, 64, 66, 67, 68,
		69, 71, 72, 73, 74, 76, 78, 79, //80,
		81, 83, 85, 86, 88, 90
	];
	~keys = #["z", "v", "w", "m", "b", "x", "k", "K",
		"s", "n", "t", "T", "h", "d", "i", "u", //"U",
		"l", "r", "c", "g", "f", "y"
	];
	~nodePlaying = nil ! ~notes.size;
	~textElev = 18;

	~userprep = {
		~view.keyDownAction = e { |view, char ...rest|
			var cs = char.asString,
				i, vnode, upd,
				killed = false;
			case
			{ cs == " " } {
				if(topEnvironment[\fingEnabled]) {
					topEnvironment[\fingersocket].noteOff(60, 0);
				} {
					topEnvironment[\fingerctl].set(64, 127, 0);
				};
			}
			{ (i = ~keys.detectIndex({ |key| key.compare(cs, false) == 0 })).notNil } {
				if(~nodePlaying[i].notNil) {
					~nodePlaying[i].release;
					// ~voicer !? { ~voicer.release(~notes[i].midicps) };
				};
				~voicer !? {
					vnode = ~voicer.trigger(~notes[i].midicps, gate: 0.5);
					~nodePlaying[i] = vnode;
					upd = SimpleController(vnode.synth)
					.put(\n_end, e {
						upd.remove;
						if(vnode === ~nodePlaying[i]) {
							~nodePlaying[i] = nil;
							defer { view.refresh };
						};
					});
				};
				// ~notePlaying[i] = ~notePlaying[i].not;
				view.refresh;
				if(topEnvironment[\fingEnabled]) {
					topEnvironment[\fingersocket].dump.noteOn(~notes[i], 64);
				};
			};
		};
	};

	~userDraw = {
		var	pc, oct, j, strBounds, playing,
			black = Color.black,
			white = Color.white,
			red = Color.red;
		~notes.do { |midi, i|
			pc = (midi - ~midibase) % 12;
			oct = (midi - ~midibase) div: 12;
			strBounds = ~keys[i].bounds;
			playing = ~nodePlaying[i].notNil;
			if((j = ~whiteKeyPCs.indexOf(pc)).notNil) {
				Pen.stringAtPoint(
					~keys[i],
					Point(
						~whiteKeyWidth * (oct * 7 + j + 0.5) - (strBounds.width * 0.5),
						~height - ~textElev
					),
					nil,
					if(playing) { red/*.blend(black, 0.5)*/ } { black }
				);
			} {
				j = ~blackKeyPCs.indexOf(pc);
				Pen.stringAtPoint(
					~keys[i],
					Point(
						(~whiteKeyWidth * (7 * oct + ~blackKeyIndices.wrapAt(j) + ~blackKeyOffsets.wrapAt(j) + 1)) - (strBounds.width * 0.5),
						~height * ~blackHeightRatio - ~textElev
					),
					nil,
					if(playing) { red/*.blend(white, 0.5)*/ } { white }
				);
			};
		};
	};
} => PR(\tradShengKbd);

win = ResizeFlowWindow(\test, Rect(500, 50, 800, 150));
kbd = PR(\tradShengKbd).copy.prep(win, (0@0).asRect);
win.recursiveResize.front;

voicer = MIDIPort.at(\omni).tryPerform(\sockets).tryPerform(\detect, { |sock|
	sock.destination.tryPerform(\nodes).tryPerform(\first).tryPerform(\defname)
	.asString == "pf"
});
voicer !? {
	voicer = voicer.destination;
	kbd.voicer = voicer;
};
)

/*
tests:

w = 35;
b = 0.73;
n = 21;
h = 100;
k = (h * 0.64).asInteger;
a = [0, 1, 3, 4, 5];

u = UserView(nil, Rect(500, 50, n*w, h));
u.front;

u.background_(Color.white);

u.drawFunc = {
	Pen.color = Color.black;
	n.do { |i|
		Pen.moveTo((w * (i+1)) @ 0)
		.lineTo((w * (i+1)) @ h)
	};
	Pen.stroke;
	(n * 5 div: 7).do { |i|
		var	oct = i div: 5, wstep = a.wrapAt(i);
		Pen.fillRect(Rect(w * (7 * oct + wstep + b), 0, w * (1.0 - b) * 2, k));
	};
};

u.refresh;

~w = ResizeFlowWindow("b", Rect(500, 50, 250, 100));
~sl = EZSlider(~w, 240@20, "b", nil, { |view| b = view.value; u.refresh }, b);
~w.recursiveResize.front;
*/