
TempoClock.default.gui;


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

(type: \voicerNote, voicer: x, midinote: ~chords[0], sustain: 12, time: 15, lowffreq: 140, hiffreq: 12500).play;

