// DO NOT RUN THE WHOLE FILE - just these next few blocks

"~/share/SC/scd/simple-piano.scd".standardizePath.loadPath;

(
TempoClock.tempo = 100/60;
~tcgui = TempoClock.default.gui;

{
	var c = MIDIPort.at(#[0, omni]).ccAllocator.available.detect { |ctl| ctl.type == \encoder and: ctl.index == 1 };
	var state = false;
	if(c.notNil) {
		~metroCtl.free;
		~metroCtl = BasicMIDIControl(#[0, omni], c.buttonnum, {
			state = state.not;
			topEnvironment[\tcgui].runMetronome(state);
		});
	};
}.value;
)


~fingerctl.set(1)


// spacer-rest summer
z = "1*20
2.
1*9
2.*2
2
2.
1*2
2.
1*2
1*3
2.
2
2.
1
2.*3
1*4
1
2.
1*2
2.
1*2
2.
1*2
2*2
1".split(Char.nl);

z = "1*2
1
4
1*4
1
4
1*9
2.
1*2
1
4
1*2
1
4
1*6
1*13
2.
1*2
2.
1*9".split(Char.nl);

z = "2.*3
1*8
2.
4
16
4
16
1*5
2.
1*18
2.
1*2
2
2.
1*15
1*9
1
4
1*2
2.
1*2
2
1
1
4
1*4".split(Char.nl);

d = Dictionary[
	"1" -> 4, "2" -> 2, "4" -> 1, "8" -> 0.5, "16" -> 0.25,
	"1." -> 6, "2." -> 3, "4." -> 1.5
];

a = 0;
z.do { |line|
	line = line.split($*).postln;
	if(line.size == 1) { line = line.add(1) };
	a = a + (d[line[0]] * line[1].asInteger);
};
a

a * 60 / 88



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



// trying a few chords, can't play by hand
p = Pbind(
	\type, \voicerNote, \voicer, v,
	\root, 2,
	\degree, Pseq([
		15, 11,
		[-2, 1, 7],
		[-1, 3.1, 8],
		[5, 9, 10]
	]),
	\dur, Pseq([0.1, 1, 2/3, 2/3, 2/3]),
	\sustain, Pseq([0.11, 4, 2/3, 2/3, 5/3])
).play(quant: #[1, -0.1]);

(type: \voicerNote, voicer: v, root: 2, degree: [-2, 6, 9, 11], sustain: 2).play
(type: \voicerNote, voicer: v, root: 2, degree: [-3, 3, 5, 14], sustain: 2).play
[-3, 3, 8, 14].degreeToKey(Scale.major) + 62

p = Pbind(
	\type, \voicerNote, \voicer, v,
	\root, 2,
	\degree, Pseq([
		// 10, 11, [7, 1], [9, 6, -2]
		10, 11, [7, -2], [9, 5, -1]
	]),
	\dur, Pseq([1, 0, 1.5, 0.5]),
	\sustain, Pseq([2.5, 2, 1.5, 0.4])
).play(quant: #[1]);


p = Pbind(
	\type, \voicerNote, \voicer, v,
	\root, 2,
	\degree, Pseq([
		10, 14, 10, 14,
		Pn(#[-3, 3, 5], 8),
		#[3.1, 7, 8, 13],
		3, #[-3, 5, 14], #[7, 15]
	]),
	#[dur, sustain], Pseq([
		1, 1, 0.125, 0.125, 0.125, 0.125, 1.5, 4.25,
		0.25, 0.15, 0.5, 0.45, Pseq(#[0.25, 0.15], 5), 2.25, 0.75,
		3, 0.5,
		0, 3, 2, 2, 1, 1
	]).clump(2)
).play(quant: #[1]);


p = Pbind(
	\type, \voicerNote, \voicer, v,
	\midinote, Ptuple([69, 76,
		Pstutter(
			Pseq([5, 3, 2, 1, 2, 1, 1], 1),
			Pseq([66, 68], inf)
		)
	], 1),
	\dur, PdurStutter(Pseq([5, 3, 3, 4], 1), 1),
	\vel, 80
).play;


// 'w' from play-midi.scd
(type: \voicerNote, voicer: w, midinote: #[59, 66, 67, 74, 81, 88], sustain: #[11, 5, 8, 7, 11, 3], releaseTime: 1.5).play;

p = Ppar(
	[
		#[59, 67, 66, 74, 81, 88],
		#[11, 5, 8, 7, 11, 3] - 1
	].flop.collect { |row|
		Pbind(
			\midinote, row[0],
			\dur, Pseq([row[1], Pconst(3.0, Pgeom(0.2, 1.08, inf))], 1),
			\legato, 0.9
		)
	}
).play(protoEvent: (type: \voicerNote, voicer: w));


Pbind(
	\midinote, 88,
	\dur, Pseq([2, Pconst(2.0, Pgeom(0.2, 1.08, inf))], 1).trace,
	\legato, 0.9
).play(protoEvent: (type: \voicerNote, voicer: w));


(
var da = #[74, 81], csgs = #[61, 68], b = 71, e = 64;

p = Pbind(
	\midinote, Pseq([
		[64, 71, 73, 74, 81],
		[68, 74, 76, 81],
		da, b, b, e, e, b,
		b, da, da, b, b, e, e, b, da, b, b, e,
		Pseq([da, b, b, e, csgs], 2),
		da, csgs, da, csgs, da, b, e,
		da, b, e, da, b, 61, da, 68, 61,
		da, [61, 71], da
	]),
	\dur, Pseq([
		1, 1.5, Pn(0.25, 6 + 12 + 10),
		Pn(0.4, 4), 0.5+0.4, Pn(0.25, 11),
		0.5, 0.5, 3
	]),
	\sustain, Pseq([
		0.75, 1.5, Pn(0.2, 6 + 12 + 10),
		Pn(0.4, 4), 0.9, Pn(0.2, 11),
		0.45, 3.5, 3
	])
).play(protoEvent: (type: \voicerNote, voicer: v));
)

p.stop


(
p = Pbind(
	\midinote, Pseq(#[
		[57, 62], 59, 68, 64, 73, 86, 78
	]),
	\dur, Pseq(#[
		3, 2, 1, 1.5, 1.5, 1, 3
	]),
	\sustain1, 16 - Pseries(0, Pkey(\dur), inf),
	\sustainOverride, Pseq(#[[16, 5], -1, -1, -1, 2, -1, -1], 1),
	\sustain, Pif(Pbinop('==', Pkey(\sustainOverride), -1), Pkey(\sustain1), Pkey(\sustainOverride))
).play(quant: 1, protoEvent: (type: \voicerNote, voicer: w));
)




(
var durs;
p = Penvir((), Pbind(
	\type, \voicerNote,
	\voicer, v,
	\root, 2,
	\degree, Pstep(
		Pseq([
			0,
			#[0, 1],
			#[-2, 0],
			#[-1, 0],
			#[-1, 0, 4],
			#[-3, 0, 5],
			#[-2, 1, 6]
		], 1),
		Pseq(durs = [5, 3, 1.5, 4, 1.5, 2.5, 5], 1)
	),
	\dur, Env(#[1.1, 0.2, 1.1], #[0.35, 0.65] * durs.sum, #[-3, 2.5]),
	\vel, Pfunc({ |ev|
		if(ev[\degree] == ~lastChord) { 75 } { 100 }
	}),
	\legato, 0.92
).collect { |ev| ~lastChord = ev[\degree]; ev }).play;
)

p.stop;