(
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
	// results.do(_.postln);
};
g = { |notes, cs(Post)|
	f.(notes).do { |result|
		cs << "%: %\n".format(result[1],
			result[0].collect { |item| item[0].asMIDINote -> item[1] });
	};
};

{
	var w, in, out;
	w = ResizeFlowWindow("fingerings", Rect(5, 50, 600, 600));
	in = TextField(w, 590@20).action_({ |view|
		var	cs = CollStream.new;
		g.(("[" ++ view.string ++ "]").interpret, cs);
		out.string = cs.collection;
	}).
	string_("59, 62, 68, 69, 73, 74, 76");
	out = TextView(w, 590@450);
	w.recursiveResize.front;
}.value;
)

g.([62, 68, 76]);

1+1

r = fork { f.([62, 64]) };
r = fork { f.([64, 72]) };
r = fork { f.([59, 62, 66, 67, 73, 74, 76]) };
r.stop;

g.([59, 62, 68, 69, 73, 74, 76]); ""

[67, 73, 76].collect(_.asMIDINote);

// lilypond-ify
~fingers4notes.asSortedArray.do { |pair, i|
	var num, fingers, name, oct;
	#num, fingers = pair;
	name = num.asMIDINote.drop(-1).toLower;
	if(name.last == $#) { name[name.size-1] = $s };
	oct = (num div: 12 - 4).reptChar($');
	if(num % 12 == 2) { Post << "\\bar \"|\"\n" };
	Post << name << oct << "4"
		<< if(i.odd) { $^ } { $_ }
		<< "\\markup { \\center-align { "
		<<< fingers.asArray.join("/") << " } }\n"
};

~notes4fingers.asSortedArray.do { |pair|
	var nums, finger, name, oct, coll;
	#finger, nums = pair;
	nums = nums.sort.collect { |num|
		name = num.asMIDINote.drop(-1).toLower;
		if(name.last == $#) { name[name.size-1] = $s };
		oct = (num div: 12 - 4).reptChar($');
		(CollStream.new << name << oct << "4").collection
	};
	Post << "\n\\set Score.measureLength = #(ly:make-moment " << nums.size << " 4)\n";
	nums.do { |num, i|
		Post << num;
		if(i == 0) {
			Post << "_\\markup { \\center-align { "
				<<< finger.asString << " } }"
		};
		Post << Char.nl;
	};
//	Post << "\"|\"\n"
}; ""




f = { |notes|
	var recurse = { |results, chord, remaining|
		var newchord, note = remaining.first, nilremain,
		fingers = ~fingers4notes[note].asArray.reject({ |finger|
			chord.any { |assn| assn.value == finger }
		});
		if(fingers.notEmpty) {
			fingers.do { |finger|
				newchord = chord.copy.add(note -> finger);
				if(remaining.size > 1) {
					recurse.(results, newchord, remaining[1..]);
				} {
					newchord.debug("done with non-nil branch");
					0.1.wait;
					results.add([newchord, newchord.count({ |assn| assn.value.notNil })]);
				};
			};
		} {
			newchord = chord.copy.add(note -> nil);
			newchord.debug("hit nil, newchord");
			0.1.wait;
			if(remaining.size > 1) {
				// finish up with this chord
				recurse.(results, newchord, remaining[1..]);
				// but also check all the other notes
				nilremain = remaining;
				(remaining.size-2).do { |i|
					nilremain = nilremain.rotate(-1);
					nilremain.debug("recursive call with");
					0.1.wait;
					recurse.(results, chord.copy, nilremain);
				};
			} {
				// or, we're done with this branch
				newchord.debug("done with nil branch");
				results.add([newchord, newchord.count({ |assn| assn.value.notNil })]);
			};
		};
	},
	results;
	results = List.new;
	recurse.(results, List.new, notes);
	results.do(_.postln);
};



var results = [[[68, \LT], [76, \R1]]];
x = { |fing|
		(fing.size > 1) and: {
			results.every { |f2|
				// (f2.debug("f2").size != fing.size).debug("size != check") or: {
				// 	f2.any { |x, i| (x.debug("!= left") != fing.wrapAt(i).debug("!= right")).debug("item != check") }.debug("any")
				// }
				f2 != fing
			}.debug("every")
		}
	};

x.([[68, \LT], [76, \R1]]);