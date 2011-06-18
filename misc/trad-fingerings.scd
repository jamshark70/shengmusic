
~notes = [57, 59, 61, 62, 64, 66, 67, 68, 69, 71, 72, 73, 74, 76, 78, 79, 80, 81, 83, 85, 86, 88, 90];

// ~notes.collect(_.asMIDINote);  // OK

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
~notes4fingers;


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

