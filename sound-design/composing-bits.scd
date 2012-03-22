
"~/share/SC/scd/simple-piano.scd".standardizePath.loadPath;

TempoClock.tempo = 88/60;
~tcgui = TempoClock.default.gui;

(
var c = MIDIPort.at(#[0, omni]).ccAllocator.available.detect { |ctl| ctl.type == \encoder and: ctl.index == 1 };
var state = false;
if(c.debug("control").notNil) {
	~metroCtl.free;
	~metroCtl = BasicMIDIControl(#[0, omni], c.buttonnum, {
		state = state.not;
		topEnvironment[\tcgui].runMetronome(state);
	});
};
)



// get v from simple-piano voicer
f = { |midi, sustain = 3|
	(type: \voicerNote, voicer: v, midinote: midi, sustain: sustain).play;
};

f.(85)


// d-e-a chords
f.(#[43, 50, 57, 59, 66, 74, 76, 81, 85])

f.(#[42, 52, 59, 68, 74, 76, 81])

f.(#[40, 50, 56, 61, 66, 69, 71, 74, 76, 81])

f.(#[38, 50, 57, 59, 66, 67, 74, 76, 81])


// d-g-a chords
f.(#[47, 54, 61, 64, 71, 74, 79, 81])

f.(#[38, 50, 56, 59, 64, 66, 69, 74, 79, 81])

f.(#[41, 48, 57, 62, 64, 71, 74, 79, 81])

f.(#[41, 50, 59, 64, 66, 69, 74, 79, 81])
f.(#[41, 50, 59, 61, 64, 66, 69, 74, 79, 81])


~chords = [
	#[43, 50, 57, 59, 66, 74, 76, 81, 85],
	#[42, 52, 59, 68, 74, 76, 81],
	#[40, 50, 56, 61, 66, 69, 71, 74, 76, 81],
	#[38, 50, 57, 59, 66, 67, 74, 76, 81],

	#[47, 54, 61, 64, 71, 74, 79, 81],
	#[38, 50, 56, 59, 64, 66, 69, 74, 79, 81],
	#[41, 48, 57, 62, 64, 71, 74, 79, 81],
	#[41, 50, 59, 64, 66, 69, 74, 79, 81],
	#[41, 50, 59, 61, 64, 66, 69, 74, 79, 81]
];

(
p = Pbind(
	\type, \voicerNote,
	\voicer, v,
	\chordIndex, Penvir(
		(weights: (1 ! ~chords.size).normalizeSum),
		Pwrand(
			(0 .. ~chords.size - 1),
			Pfunc({ ~weights }),
			inf
		).collect { |i|
			~weights[i] = ~weights[i] * 0.4;
			~weights = ~weights.normalizeSum;
			i
		},
		// Pxrand(~chords, inf)
	),
	\midinote, Pindex(~chords, Pkey(\chordIndex), inf),
	\dur, Pwhite(1, 3, inf),
	\sustain, Pkey(\dur) - 0.25
).collect { |ev| ev[\midinote].collect(_.asMIDINote).postln; ev }
.play;
)

p.stop;



// print
~chords.clumps(#[4, 5]).do { |group, i|
	"\n\ngroup %\n".postf(i+1);
	group.do { |chord|
		Post <<* chord.collect(_.asMIDINote) << Char.nl;
	};
}; ""



// quicky swell pad
(
WrapInstr(\quickypad, { |freq = 440, gate = 1, det = 1, amp = 0.1, env, pan = 0,
	lowffreq = 600, hiffreq = 8000, rq = 0.4, time = 1, upRatio = 0.32, fenv|
	var sig = Saw.ar(freq * [1, det]).sum * amp,
	eg = EnvGen.kr(env, gate, doneAction: 2),
	filt_env = (
		fenv ? { |lo, hi, upRatio|
			Env([lo, hi, lo], [upRatio, 1 - upRatio], \exp)
		}
	).value(lowffreq, hiffreq, upRatio),
	feg = EnvGen.kr(filt_env, gate, timeScale: time);
	sig = RLPF.ar(sig, feg, rq);
	Pan2.ar(sig, pan, eg);
}, [\freq, \unipolar, \mydetune, \amp, EnvSpec(Env.adsr), \bipolar,
	\freq, \freq, \myrq, #[0.1, 10, \exp], nil, ObjectSpec(nil)
]);
)

MixingBoard.at(0).mixers[0].mixer  // reuse?

// x = WrapInstr(\quickypad).miditest(1, [], target: MixingBoard.at(0).mixers[0].mixer);
// det: 1.0028311897235, amp: 0.1, pan: 0, lowffreq: 600, hiffreq: 8000, rq: 0.88031496062992, time: 1, upRatio: 0.32

x.free;
x = Voicer(30, WrapInstr(\quickypad), [det: 1.0028311897235, rq: 0.88031496062992, env: Env.adsr(1.5, 1.5, 0.6, 3.0)], target: MixingBoard.at(0).mixers[0].mixer);

f = { |i = 0, sus = 12|
	(type: \voicerNote, voicer: x, midinote: ~chords[i], sustain: sus, time: sus + 3, lowffreq: 140, hiffreq: 12500).play;
};

~chords[1] = ~chords[1].copy.add(~chords[1][0] - 12);
~chords[8] = ~chords[8].copy.add(~chords[8][0] - 12);

~chords[1] = [42, 49, 57, 59, 68, 74, 76, 81];

group 1
G2, D3, A3, B3, F#4, D5, E5, A5, C#6
F#2, C#3, A3, B3, G#4, D5, E5, A5
E2, D3, G#3, C#4, F#4, A4, B4, D5, E5, A5
D2, D3, A3, B3, F#4, G4, D5, E5, A5


group 2
B2, F#3, C#4, E4, B4, D5, G5, A5
D2, D3, G#3, B3, E4, F#4, A4, D5, G5, A5
F2, C3, A3, D4, E4, B4, D5, G5, A5
F2, D3, B3, E4, F#4, A4, D5, G5, A5
F2, D3, B3, C#4, E4, F#4, A4, D5, G5, A5

f.(6, 18); ""
f.(4); ""

p = Penvir(
	(
		notes: Pseq(#[
			// [59, 61, 64, 69], [66, 73, 74], [64, 71, 73, 81], [74, 79, 81, 85]  // 4
			// [59, 62, 64, 66, 69], [64, 69, 71, 78], [68, 74, 76, 79, 81], [74, 79, 81, 88]  // 5
			// [57, 62, 64, 71], [59, 67, 73, 74], [69, 74, 76, 79], [74, 79, 81, 83, 88], [79, 81, 86, 90],  // 6
			[59, 64, 66, 69], [64, 69, 71, 78], [67, 69, 73, 83], [74, 79, 81, 85]  // 8
		], 1).asStream
	),
	Pbind(
		\type, \voicerNote,
		\voicer, v,
		\midinote, Pn(Plazy({
			var n = ~notes.next;
			if(n.notNil) { Pseq(n ++ [Rest], 1) } { Pseq([nil], 1) }
		}, inf)),
		\dur, Pexprand(0.3, 0.8, inf),
		\sustain, 4
	)
).play;

p.stop;		

