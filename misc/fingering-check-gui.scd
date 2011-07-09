(
var f, g, w, in,
chan, ctl, socket, vsocket, vtranspose,
enabled = false, white = Color.white, pink = Color(1.0, 0.8, 0.8), midistring;

~notes = [57, 59, 61, 62, 64, 66, 67, 68, 69, 71, 72, 73, 74, 76, 78, 79, 80, 81, 83, 85, 86, 88, 90];

~fingers4notes = (
	57: \L2,
	59: \L1,
	61: \R2,
	62: \R1,
	64: #[\RT, \LT],
	66: \RT,
	67: \R1,
	68: \LT,
	69: \R3,
	71: \LT,
	72: #[\LT, \R3],
	73: #[\RT, \R1],
	74: \R3,
	76: \R1,
	78: \R1,
	79: \RT,
//	80: ,
	81: \L2,
	83: \L1,
	85: \L1,
	86: \L3,
	88: \LT,
	90: \R3
);

~notes4fingers = IdentityDictionary.new;
~fingers4notes.keysValuesDo { |num, fingers|
	fingers.do { |finger|
		~notes4fingers[finger] = ~notes4fingers[finger].add(num); 
	};
};

f = { |notes|
	var results = List.new;
	var fingers4remain = { |chord, remaining|  // must run in a routine
		var newchord, note = remaining.first,
		fingers = ~fingers4notes[note].asArray.reject({ |finger|
			chord.any { |assn| assn[1] == finger }
		});
		if(fingers.notEmpty) {
			fingers.do { |finger|
				newchord = chord.copy.add([note, finger]);
				if(remaining.size > 1) {
					fingers4remain.(newchord, remaining[1..]);
				} {
					newchord.yield;
				};
			};
		} {
			newchord = chord.copy.add([note, nil]);
			if(remaining.size > 1) {
				// finish up with this chord
				fingers4remain.(newchord, remaining[1..]);
			} {
				// or, we're done with this branch
				newchord.yield;
			};
		};
	},
	score = { |fing| fing.size - (2 * fing.count { |assn| assn[1].isNil }) },
	isNotDup = { |fing| results.every { |f2| f2[0] != fing } },
	recurse = { |argnotes|
		var	shouldRecurse = true;
		block { |break|
			Routine({ fingers4remain.(List.new, argnotes) }).do { |fingering|
				if(fingering.any { |assn| assn[1].isNil }) {
					if(shouldRecurse) {
						argnotes.size.do { |i|
							// retry notes in different order
							recurse.(argnotes.rotate(i.neg).drop(1));
						};
					};
				} {
					// add to results only if unique, and no failures
					fingering = fingering.sort { |a, b| a[0] < b[0] };
					if(isNotDup.(fingering)) {
						results.add([fingering, fingering.size /*score.(fingering)*/]);
					};
					// if there was a perfect solution, no need to try partial ones
					// partial ones may still result from notes that have multiple fingerings
					// one fingering may conflict while the other doesn't
					if(results.last[1] == notes.size) { shouldRecurse = false };
				};
			};
			results;
		};
	};

	recurse.(notes);
	results = results.sort({ |a, b| a[1] > b[1] });
};
g = { |notes, cs(Post)|
	f.(notes).do { |result|
		cs << "%: %\n".format(result[1],
			result[0].collect { |item| item[0].asMIDINote -> item[1] });
	};
};

{
	var out;
	w = ResizeFlowWindow("fingerings", Rect(5, 50, 600, 600));
	in = TextField(w, 590@20).action_({ |view|
		var	cs = CollStream.new;
		g.(("[" ++ view.string ++ "]").interpret, cs);
		out.string = cs.collection;
	}).string_("59, 62, 68, 69, 73, 74, 76");
	out = TextView(w, 590@450)
		.hasVerticalScroller_(true)
		.autohidesScrollers_(true);
	w.recursiveResize.front;
	w.onClose = {
		ctl.free; socket.free;
	};
}.value;

if(MIDIClient.initialized) {
	chan = MIDIPort.at(\omni) ?? { MIDIChannel(\omni) };
	if(chan.notNil) {
		ctl = chan.ccAllocator.available
			.detect { |cc| cc.type == \encoder and: { cc.index == 0 } };
		if(ctl.notNil) {
			vsocket = chan.sockets.detect { |sk| sk.isKindOf(VoicerMIDISocket) };
			if(vsocket.tryPerform(\active) ? false) {
				vtranspose = vsocket.destination.globalControls[\transpose];
			} {
				vtranspose = 0;
			};
			ctl = BasicMIDIControl(\omni, ctl.buttonnum, {
				enabled = enabled.not;
				if(enabled) {
					socket.enable;
					midistring = "";
					defer {
						w.front;
						in.background = pink;
						in.string = midistring;
					};
				} {
					socket.disable;
					defer {
						in.background = white;
					};
				};
			});
			socket = BasicMIDISocket(\omni, { |num, vel|
				num = num + vtranspose;
				if(midistring.size == 0) {
					midistring = num.asString;
				} {
					midistring = midistring ++ ", " ++ num;
				};
				defer {
					in.string = midistring;
				};
			}, { |num, vel|
				if(midistring.size > 0) {
					defer {
						in.string;
						in.doAction;
					};
				};
				midistring = "";
			});
			socket.disable;
		};
	};
};
)
