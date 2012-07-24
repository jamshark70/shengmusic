(thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;
// (thisProcess.nowExecutingPath.dirname +/+ "../common/common-defs.scd").loadPath;

BP(\shengShared).free;
PR(\shengShared) => BP(\shengShared);

MixingBoard.at(0).postSettings;

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);

s.addr = ~debugAddr;
s.addr = ~saveAddr;

#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
	Mode(\default).v.copy.root_(i) => Mode(key);
	Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
};



// Klinks --> karplus-strong pitches

// timescale is not applied to the trig freq env

(
WrapInstr("osc.ks_retrig", { |freq = 440, amp = 0.1, ffreq = 2000, 
	excratio = 0.5, excamp = 1, excAtk = 0.005, excDcy = 0.03, retrigProb = 1,
	fbamp = 1, pan = 0,
	env, timeScale = 1,
	bufselect, firstbuf = 1, numbufs = 2, detectSilence|
	var frq = freq.dereference.value(),
	delayt = max(0, frq.reciprocal - ControlDur.ir),
	excfreq = frq * excratio.dereference.value(),
	firstbufnum = firstbuf.asUGenInput,  // .bufnum if a Buffer, 'this' if a number
	// exciter retriggering
	trigFreqEnv = NamedControl.kr(
		\trigFreqEnv, 
		(0 ! 40).overWrite(Env().asArray)
	),
	trig = Impulse.ar(EnvGen.kr(trigFreqEnv, timeScale: timeScale)),
	mask = TRand.ar(0, 1, trig) < retrigProb,
	excEnv = min(1.0, Decay2.ar(trig * mask, excAtk, excDcy)),
	exc = VOsc.ar(
		bufselect.dereference.value().range(firstbufnum, firstbufnum + numbufs - 1.01),
		excfreq, 0,
		excamp.dereference.value()
	) * excEnv,
	feedback = LocalIn.ar(1),
	gate = 1, eg, gatedEnv;
	// the delay doubles the number of end-to-beginning buffer transitions
	// helps to blur the glitchiness somewhat
	exc = exc + DelayL.ar(exc, 0.05, (excfreq * 2).reciprocal);
	feedback = feedback + exc;
	feedback = LPF.ar(feedback, ffreq);
	feedback = DelayL.ar(feedback, 0.11, delayt, mul: fbamp);
	feedback = LeakDC.ar(feedback);
	LocalOut.ar(feedback);
	env = env.dereference.value();
	gatedEnv = try { env.isSustained } { |err|
		if(env.isKindOf(SequenceableCollection)) { true }
		{ err.throw }
	};
	if(gatedEnv) { gate = NamedControl.kr(\gate, 1) };
	eg = EnvGen.kr(env, gate, timeScale: timeScale, doneAction: 2);
	if(detectSilence == true) {
		DetectSilence.ar(feedback, 0.003, doneAction: 2);
	};
	Pan2.ar(feedback, pan, eg * amp)
}, [
	\freq, \amp, \freq,
	#[0.1, 1, \exp], \amp, #[0.001, 0.2, \exp], #[0.001, 0.2, \exp], nil,
	\amp, \bipolar,
	EnvSpec(Env.adsr), #[0.01, 100, \exp],
	ObjectSpec({ SinOsc.kr(Rand(0.08, 0.14)) }), \mybuf, StaticSpec(2, 16, \lin, 1, 2),
	ObjectSpec(false)
]);

(keys: #[master, rvbmc],
initLevel: 0.75,
make: { |name|
	var out;
	~target = MixerChannel(name, s, 2, 2, ~initLevel, outbus: ~master, completionFunc: { |chan|
		if(~rvbmc.notNil) { chan.newPostSend(~rvbmc, 0.4) };
	});
	out = Voicer(25, WrapInstr("osc.ks_retrig"), [
		env: `{ NamedControl.kr(\env, (0 ! 20).overWrite(Env.asr.asArray)) },
		firstbuf: `(BP(\shengShared).noiseBufs[0].bufnum),
		numbufs: `(BP(\shengShared).noiseBufs.size),
		amp: 1
	], target: ~target);
	out.mapGlobal(\retrigProb, nil, 0.12, #[0, 1]);
	out
}, free: { ~target.free }, type: \voicer) => Fact(\pizz);
)

();

WrapInstr("osc.ks_retrig").listArgs

p = WrapPatch("osc.ks_retrig", [
	nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
	`{ NamedControl.kr(\env, (0 ! 20).overWrite(Env.asr.asArray)) },
	nil, nil, BP(\shengShared).noiseBufs[0].bufnum, BP(\shengShared).noiseBufs.size
]);

d = p.asSynthDef;
d.allControlNames.do(_.postln); ""

d.add;

a = n.play(d.name, [freq: 440, amp: 1, ffreq: 4000, excratio: 0.5, excamp: 20.dbamp, fbamp: 1, trigFreqEnv: Env(#[1.2, 6.0, 0.8], #[3, 3], \sin)]);

a.trace;
a.release;

q = PbindProxy(
	\instrument, d.name,
	\root, 2,
	\degree, \patRejectLastN.eval(Prand(#[-14, -10, -7, -5, -3, 0, 2, 3, 4, 6, 7, 8], inf), 3),
	\dur, Pwhite(2, 6, inf),
	\sustain, Pkey(\dur) * Pwhite(1.8, 3.6, inf),
	\amp, 1,
	\ffreq, Pexprand(1400, 9000, inf),
	\excratio, Pwhite(0.4, 0.65, inf),
	\excamp, 1, // 20.dbamp,
	\fbamp, 0.98,
	\trigFreqEnv, Pfunc({
		var atk = rrand(0.35, 0.5);
		Env(
			[rrand(0.9, 1.25), rrand(8.0, 12.5), rrand(0.9, 1.25)]
			, //++ Array.fill(6, { rrand(0.7, 1.6) }),
			// ([rrand(1.5, 3.0), rrand(2.5, 5.0)] // ++ Array.fill(6, { rrand(0.7, 2.1) })
			// ).normalizeSum,
			[atk, 1 - atk],
			\exp
		)
	}),
	\timeScale, Pkey(\sustain)
);

z = n.play(q);

z.stop;

q.set(\excamp, 1);
q.set(\pan, Pwhite(0.4, 1.0, inf) * Pseq(#[-1, 1], inf));

q.set(\sustain, Pkey(\dur) * Pwhite(1.6, 3.7, inf));

q.set(\dur, Pwhite(0.6, 2.4, inf));
q.set(\sustain, Pwhite(4.2, 9.8, inf));

q.set(\ffreq, (Pfunc({ |ev| ev.use { ~detunedFreq.value } }) * Pexprand(4.0, 18.0, inf)).clip(1000, 12000));

q.set(\excAtk, 0.1); q.set(\excDcy, 0.2);

q.set(\excAtk, Pexprand(0.005, 0.02, inf));
q.set(\excDcy, Pkey(\excAtk) * Pwhite(2.0, 5.0, inf));

g = GenericGlobalControl(\prob, nil, 0.2, #[0, 1]); g => VP(0);

q.set(\retrigProb, g.asMap);

e = n.play(q.asStream.next(()));
s.sendMsg(\n_trace, *e.id);

q.postcs

PbindProxy(
	\instrument, "-vwS4",
	\root, 2,
	\degree, \patRejectLastN.eval(Prand(#[-14, -10, -7, -5, -3, 0, 2, 3, 4, 6, 7, 8], inf), 3),
	\dur, Pwhite(0.6, 2.4),
	\sustain, Pwhite(4.2, 9.8),
	\amp, 1,
	\ffreq, (Pfunc({ |ev| ev.use { ~detunedFreq.value } }) * Pexprand(4.0, 18.0)).clip(1000, 12000),
	\excratio, Pwhite(0.4, 0.65),
	\excamp, 1,
	\fbamp, 0.98,
	\trigFreqEnv, Pfunc({
		var atk = rrand(0.35, 0.5);
		Env(
			[rrand(0.9, 1.25), rrand(8.0, 12.5), rrand(0.9, 1.25)]
			, //++ Array.fill(6, { rrand(0.7, 1.6) }),
			// ([rrand(1.5, 3.0), rrand(2.5, 5.0)] // ++ Array.fill(6, { rrand(0.7, 2.1) })
			// ).normalizeSum,
			[atk, 1 - atk],
			\exp
		)
	}),
	\timeScale, Pkey(\sustain),
	\excAtk, Pexprand(0.005, 0.02),
	\excDcy, (Pkey(\excAtk) * Pwhite(2.0, 5.0)),
	\retrigProb, 0.6,
	\pan, (Pwhite(0.4) * Pseq([ -1, 1 ], inf))
)



// pizz: chord process

VC(\pz).free;
Fact(\pizz) => VC(\pz);
VC(\pz) => VP(0);

Pwhite(0.6, 2.4, inf) * Ptuple([1, Pwhite(4.2, 9.8, inf), 0.5], inf) => MicRh(\pizzes);

MIDIRecBuf(\pzch, [
	[	38, 45, 50, 54, 55, 59, 61, 64,
		40, 49, 50, 54, 57, 61, 64, 71,
		42, 50, 52, 57, 59, 62, 66, 67,
		43, 47, 49, 52, 54, 57, 62, 67
	],
	Array.fill(4, (0.1 ! 8).put(7, 1)).flat,
	1 ! 32,
	0.5 ! 32
].asNotes, (type: \ch, mode: \d)) => MBM(0);

(
(
make: { |name|
	var new;
	BP(name).free;
	new = \newCh.eval(name, \arpeg1, \macroRh, MBM(0)[\pzch], nil, Pwhite(14, 24, inf), \pizzes, \shuf1, nil, \d);
	new.quant = 0;
	new.topNote = PR(\patternTop).copy.make {
		~deg = 'patRejectLastN'.eval(Pseries(
			{ rrand(36, 43) },
			Pwrand(#[1, 2, 3], #[0.5, 0.3, 0.2], inf),
			inf
		).fold(36, 43), 1);
		~mode = \d;
	};
	new.child.use {
		~fitFunc = \chordFitNotes;

		~ffreq = (Pfunc({ |ev| ev[\mode].asMode.cps(ev[\freq] ?? { ev[\note].freq }).asArray.maxItem }) * Pexprand(4.0, 18.0)).clip(1000, 12000);
		~excratio = Pwhite(0.4, 0.65);
		~excamp = 1;
		~fbamp = Pwhite(0.98, 0.998, inf);
		~trigFreqEnv = Pfunc({
			var atk = rrand(0.35, 0.5);
			[Env(
				[rrand(0.9, 1.25), rrand(8.0, 12.5), rrand(0.9, 1.25)],
				[atk, 1 - atk],
				\exp
			)].asArray
		});
		~timeScale = Pkey(\length);
		~excAtk = Pexprand(0.005, 0.02);
		~excDcy = (Pkey(\excAtk) * Pwhite(2.0, 5.0));
		~retrigProb = 0.6;
		~pan = (Pwhite(0.4) * Pseq([ -1, 1 ], inf));
		~amp = 1;

		~argPairs = Pbind(
			\ffreq, BPStream(\ffreq),
			\excratio, BPStream(\excratio),
			\excamp, BPStream(\excamp),
			\fbamp, BPStream(\fbamp),
			\trigFreqEnv, BPStream(\trigFreqEnv),
			\timeScale, BPStream(\timeScale),
			\excAtk, BPStream(\excAtk),
			\excDcy, BPStream(\excDcy),
			\retrigProb, BPStream(\retrigProb),
			\pan, BPStream(\pan),
			\amp, BPStream(\amp)
		);
	};
	new
}, type: \bp) => Fact(\pzBP);

PR(\abstractProcess).clone {
	~resetChild = false;
	~rest = Pwhite(7.0, 14.0, inf);

	~event = (eventKey: \hang);
	~alwaysReset = true;
	~prep = { |bpname|
		~bp = bpname ?? { ~bp };
		~cond = Condition.new;
		~event.put(\cond, ~cond);
		currentEnvironment
	};
	~preparePlay = {
		case
		{ BP.exists(~bp).not } { "BP(%) doesn't exists".format(~bp.asCompileString).warn }
		{ BP(~bp).v[\eventStream].isNil } { BP(~bp).prepareForPlay }
		{ ~resetChild } { BP(~bp).reset };

		if(~stopWatcher.isNil) {
			~stopWatcher = NotificationCenter.register(BP(~bp).child, \childStop, ~collIndex, e {
				~cond.unhang
			});
		};
	};
	~asPattern = {
		if(~restStream.isNil) { ~makeStreamForKey.(\rest) };
		Prout({ |inevent|
			loop {
				BP(~bp).triggerOneEvent(0);
				// hang first, then wait 'delta' beats
				inevent = inevent.copy.put(\delta, ~restStream.next(inevent)).yield;
			}
		})
	};
	~stopCleanup = {
		~stopWatcher.remove;
		~stopWatcher = nil;
	};
} => PR(\chordRunner);
)

BP(\pz).free;
Fact(\pzBP) => BP(\pz);
VC(\pz) => BP(\pz);

BP(\pzr).free;
PR(\chordRunner).chuck(BP(\pzr), nil, (bp: \pz));

Library.put(\currentBassNote, Penvir(
	(lastTime: 0),
	Pclutch(
		Pwhite(0, 6, inf).trace,
		Pfunc({ (thisThread.beats - ~lastTime > 1).value(~lastTime = thisThread.beats) })
	)
).asStream);

BP(\pz).child.fitFunc = \chordFitInt;
BP(\pz).child.fitFunc = \chordFitNotes;


PR(\arpeg1) => BP(\pz);
PR(\macroRh) => BP(\pz);

BP(\pz).child.use {
	~ffreq = (Pfunc({ |ev| ev[\mode].asMode.cps(ev[\freq] ?? { ev[\note].freq }).asArray.maxItem }) * Pexprand(4.0, 18.0)).clip(1000, 12000);
	~excratio = Pwhite(0.4, 0.65);
	~excamp = 1;
	~fbamp = Pwhite(0.98, 0.998, inf);
	~trigFreqEnv = Pfunc({
		var atk = rrand(0.35, 0.5);
		[Env(
			[rrand(0.9, 1.25), rrand(8.0, 12.5), rrand(0.9, 1.25)]
			, //++ Array.fill(6, { rrand(0.7, 1.6) }),
			// ([rrand(1.5, 3.0), rrand(2.5, 5.0)] // ++ Array.fill(6, { rrand(0.7, 2.1) })
			// ).normalizeSum,
			[atk, 1 - atk],
			\exp
		)].asArray
	});
	~timeScale = Pkey(\length);
	~excAtk = Pexprand(0.005, 0.02);
	~excDcy = (Pkey(\excAtk) * Pwhite(2.0, 5.0));
	~retrigProb = 0.6;
	~pan = (Pwhite(0.4) * Pseq([ -1, 1 ], inf));

	~argPairs = Pbind(
		\ffreq, BPStream(\ffreq),
		\excratio, BPStream(\excratio),
		\excamp, BPStream(\excamp),
		\fbamp, BPStream(\fbamp),
		\trigFreqEnv, BPStream(\trigFreqEnv),
		\timeScale, BPStream(\timeScale),
		\excAtk, BPStream(\excAtk),
		\excDcy, BPStream(\excDcy),
		\retrigProb, BPStream(\retrigProb),
		\pan, BPStream(\pan)
	);
};

BP(\pz).quant = 0;


Pwhite(14, 24, inf) =>.macro BP(\pz);

\shuf1 =>.arpeg BP(\pz);
\pizzes =>.micro BP(\pz);

BP(\pz).topNote = PR(\patternTop).copy.make {
	// ~deg = Pwhite(36, 43, inf);
	~deg = 'patRejectLastN'.eval(Pseries(
		{ rrand(36, 43) },
		Pwrand(#[1, 2, 3], #[0.5, 0.3, 0.2], inf),
		inf
	).fold(36, 43), 1);
	~mode = \d;
};

BP(\pz).child.fitFunc = \chordFitInt;

BP(\pz).mode = \d;


// [21, 25, 28, 30, 31, 33, 34, 36].unmapMode(\d)


// Voicer(25, d.name.asSymbol, target: n) => VC(\pizz);

VC(\pz) => BP(\pz);


BP(\pz).child.trigFreqEnv = Pfunc({
		var atk = rrand(0.35, 0.5);
		[Env(
			[rrand(0.9, 1.25), rrand(8.0, 12.5), rrand(0.9, 1.25)]
			, //++ Array.fill(6, { rrand(0.7, 1.6) }),
			// ([rrand(1.5, 3.0), rrand(2.5, 5.0)] // ++ Array.fill(6, { rrand(0.7, 2.1) })
			// ).normalizeSum,
			[atk, 1 - atk],
			\exp
		).asArray]
	});

BP(\pz).child.event.amp = 1;
n.level = 0.75;

a = NotificationCenter.register(BP(\pz).child, \runChild, \test, { |... args| args.debug("run") });
b = NotificationCenter.register(BP(\pz).child, \childStop, \test, { |... args| args.debug("stop") });

a.remove; b.remove;


BP(\pz).prepareForPlay;

p = Pfset(
	{
		~cond = Condition.new;
		~hangEvent = (play: { ~cond.hang(\hang) }, cond: ~cond, delta: 0);
		~stopWatcher = NotificationCenter.register(BP(\pz).child, \childStop, \test, e { ~cond.unhang });
	},
	Prout({ |inevent|
		loop {
			BP(\pz).triggerOneEvent(0);
			inevent = inevent[\hangEvent].yield;
			inevent = Event.silent(rrand(7.0, 14.0)).yield;
		}
	}),
	{
		~stopWatcher.asCompileString.debug("removing").remove;
	}
).play;

p.stop;


Library.put(\currentBassNote, Pwhite(0, 6, inf).trace.asStream);

BP(\pz).child.fitFunc = \chordFitNotes;

fork {
	var cond = Condition.new,
	stopWatcher = NotificationCenter.register(BP(\pz).child, \childStop, \test, { "waking".debug; cond.unhang });
	loop {
		BP(\pz).debug("going").triggerOneEvent(0);
		cond.hang;
		rrand(7.0, 14.0).debug("resting").wait;
	};
};

r.stop;

// if 'g' is still there
BP(\pz).child.retrigProb = g.asMap;

BP(\pz).child.fbamp = Pwhite(0.98, 0.998, inf);





// modify this for triplet-chord gesture

SynthDef(\tri, { |out, freq = 440, det = 1.003, width = 0.5, ffreq = -1, rq = 1, gate = 1, amp = 0.1, releaseTime = 0.12, pan|
	var sig = VarSaw.ar(freq * [1, det], 0, width).sum * amp,
	eg = EnvGen.kr(Env.adsr(0.07, 0.12, 0.4, releaseTime), gate, doneAction: 2);
	ffreq = Select.kr(ffreq <= 0, [ffreq, ExpRand(2000, 5000)]);
	Out.ar(out, Pan2.ar(RLPF.ar(sig, ffreq, rq, eg), pan))
}).add;


WrapInstr("osc2.v3mappan", { |pan, holdtime = 1|
	var sig = WrapInstr.wrap("osc2.vosc3mapfilt");
	Line.kr(0, 1, holdtime + 0.15, doneAction: 2);  // zombie killer
	Pan2.ar(sig, pan);
}, [\bipolar, #[0.01, 10], \amp]);

WrapInstr("osc2.v3mappan").listArgs;

(
(
keys: #[master, rvbmc],
make: { |name|
	var out;
	~target = MixerChannel(name, s, 2, 2, level: ~initLevel ? 0.75, outbus: ~master,
		completionFunc: { |chan|
			~eq = MultiEQ(2, \loshelf, 1266.303, -7.669.dbamp, 1).play(chan);
			~chorus = chan.playfx(Instr("busfx.chorus2"), [
				0, 2, 2, 3,
				0.017377393674649, 0.1, 0.0071613988449721,
				1.6669675304762, 0.61054022965853]
			);
		};
	);
	out = Voicer(20, WrapInstr("osc2.v3mappan"), [
		bufbase: `(BP(\shengShared).oscBufs.first.bufnum),
		numbufs: `(BP(\shengShared).oscBufs.size),
		basefreq: `(48.midicps),
		topfreq: `(132.midicps),
		env: Env.adsr(0.07, 0.12, 0.4, 0.12),
		vsens: `1,
		detune: 1.003
	], target: ~target);
	out
},
free: { ~target.free },
type: \voicer) => Fact(\triVC);
)

VC(\tri).free;
Fact(\triVC) => VC(\tri);


a = VC(\tri).env.target.playfx(Instr("busfx.chorus2"), [0, 2, 2, 3]); a.gui;

FxPatch(
	[ 'busfx', 'chorus2' ], [ 22, 2, 2, 3, 0.017377393674649, 0.1, 0.0071613988449721, 1.6669675304762, 0.61054022965853 ]
)

MultiEQ(2).edit(VC(\tri).env.target);
MultiEQ.new(2, \loshelf, 1266.303, -7.669.dbamp, 1)

// triplet process

~clock88 = TempoClock(88/60);

{ |notes, event| Pn(event[\length] / 3, 3).collect { |x| [x, x * 0.7, 0.5] } } => MicRh(\triplet);

// { |notes, event| Ptuple([Pn(event[\length] / 3, 3), Pseq([event[\length] * 0.16, 0.1, 0.1], 1), 0.5]) } => MicRh(\trpOverlap);

{ |notes, event| Ptuple([Pn(event[\length] / 3, 3), event[\length] * 0.22, 0.5]) } => MicRh(\trpOverlap);

Pwhite(0.8, 1.6, { rrand(5, 11) }) => MacRh(\triplet);

Pwhite(0.5, 0.75, { rrand(2, 4) }) => MacRh(\tshort);
Pwhite(1.0, 1.25, { rrand(1, 2) }) => MacRh(\tmid);
Pwhite(1.8, 2.2, 1) => MacRh(\tlong);

// IMPORTANT: this assumes MicRh will stop the arpeggiation
{ |notes|
	if(notes.isArray) {
		Pn(notes.asChord, inf)
	} {
		Pn(notes, inf)
	};
} => ArpegPat(\blocks);

MIDIRecBuf(\tripletCh, [
	[	62, 67, 69,
		62, 66, 71,
		62, 64, 71,
		62, 67, 71,
		62, 66, 76
	],
	(0.1 ! 15).putSeries(2, 5, 15, 1),
	0.1,
	0.5
].asNotes, (mode: \d, type: \ch)) => MBM(0);

(
(
keys: #[clock88],
make: { |name|
	var p;
	BP(name).free;
	p = \newCh.eval(name, \arpeg1, \macroRh, MBM(0)[\tripletCh], nil, MacRh(\triplet), \triplet, \blocks, nil, \d);

	p.topNote = PR(\patternTop).clone {
		~deg = Pxrand((33..44), inf);
		~mode = \d;
	};

	p.quant = 0;
	p.clock = ~clock88;
	p.printStopMsg = false;
	p.alwaysReset = true;

	// make sure each child pattern stays on the same chord
	// especially for overlap
	p.child.nextNoteStream = #{ |inEvent|
		~nextNotePattern.value(inEvent);
		~updateNoteStream.value(inEvent);
		Pn(~noteStream.next(inEvent), inf);
	};
	p.child.makeChordPattern = { Pxrand(~chords, inf) };
	p.child.fitFunc = \chordFitNotes;

	p.child.panWidth = Pwhite(0.7, 1.0, inf);
	p.child.panSide = Pseq(#[-1, 1], inf);
	p.child.argPairs = [
		gate: Pseq(#[0.17, 0.1, 0.1]),
		pan: Plazy({ |ev| (~panWidthStream.next(ev) * ~panSideStream.next(ev)).loop }),
		width: Pstutter(10, Pwhite(0.05, 0.15, 1)),
		ffreq: Pgeom({ exprand(8000, 12000) }, Pstutter(10, Pwhite(0.15, 0.22, 1)), 3),
		rq: Pseq(#[0.1, 0.4, 1.0], inf),
		holdtime: Pkey(\length) / Ptempo()
	];

	p.overlapCtl = GenericGlobalControl(\tpOverlap, nil, 1, #[0.3, 10, \exp]);
	p.useGui = { |vpi| ~overlapCtl => VP(vpi) };
	p.userfree = { ~overlapCtl.free };
	p.event.stopChild = false;

	p
}, type: \bp) => Fact(\tripletBP);
)

BP(\tri).free;
Fact(\tripletBP) => BP(\tri);
p = BP(\tri);
VC(\tri) => p;

p.child.argPairs[0] = \gate;

p.lastEvent.associationsDo(_.postln); ""

e = p.lastEvent;

e === p.lastEvent;

f = p.eventStream.next(p.event.copy);

p.lastEvent.copy.play;

// p.child.argPairs = [amp: Pseq(#[0.2, 0.08, 0.08], 1)];
// p.child.argPairs = [amp: Pgeom(0.2, Pstutter(3, Pwhite(0.45, 0.7, 1)), 3)];


p.play;
p.printStopMsg = false;

Pwhite(0.4, 1.4, { rrand(5, 11) }) => MacRh(\triplet);

Pgeom({ rrand(0.3, 0.6) }, Plazy({ Pn(rrand(1.5, 2.3), inf) }), { rrand(5, 11) }).wrap(0.3, 2.0) => MacRh(\triplet);
MacRh(\triplet) => p;

Pswitch1(
	[Pwhite(0.5, 0.75), Pwhite(1.0, 1.25), Pwhite(1.8, 2.2)],
	// Pfin({ rrand(8, 15) },
		Psmartstutter(
			// Pfunc({ |i| if(i == 0) { rrand(2, 3) } { 1 } }),
			Pfunc({ |i| max(1, rrand(2, 3) - i) }),
			// Pxrand((0..2), inf)
			Pn(Pshuf((0..2), 1).trace, { rrand(8, 15) } /*inf*/)
		)
	// ).trace
) => MacRh(\triplet);
MacRh(\triplet) => p;


// macrorhythm gestures

q = Pseq([MacRh(\tlong), MacRh(\tshort)], 1).asStream;
q.next;

Prand(MacRh(#[tshort, tmid, tlong]), 10) =>.macro p;

// try overlap :->

(Pwhite(1.6, 2.4, inf) * Ptuple([Pwhite(0.15, 0.35, inf), 1], inf)) => MacRh(\overlap);
MacRh(\overlap) => p;

g = GenericGlobalControl(\overlap, nil, 1, #[1, 8]); g => VP(0);

(Pstutter(Pwhite(3, 5, inf), Pwhite(2.0, 3.5, inf)) / Ptuple([g, 1], inf)) => MacRh(\overlap);
MacRh(\overlap) => p;

// non-g version
p.use { ~bindPattern.(Pstutter(Pwhite(3, 5, inf), Pwhite(2.0, 3.5, inf)) / Ptuple([~overlapCtl, 1], inf), \macro) };

\trpOverlap =>.micro p;

g = BP(\tri).overlapCtl;

p.play;
g.watch.automate { EnvGen.kr(Env(#[3, 8.2, 4.4, 3], #[8, 12, 6], #[2, 5, -3]), doneAction: 2) };
g.autoSynth.onFree({ p.stop; });

g.stopAuto;

g.watch.automate {
	DemandEnvGen.kr(
		Dseq([1, 4, Dwhite(3.3, 5.2, inf)]),
		Dseq([25, Dwhite(3.7, 5.1, inf)])
	)
};

p.event.stopChild = false;

g.stopWatching.stopAuto;

KrBusWatcher.newFrom(s).updateFreq = 4;


Pn(#[1, 2], 2) =>.macro p;

(Pwhite(1.6, 2.4, inf) * Ptuple([Pwhite(0.5, 0.8, inf), 1], inf)) => MacRh(\overlap);
MacRh(\overlap) => p;

MacRh(\tlong) => p;

/*
x = List.new;
p.child.argPairs = [amp: Pgeom(0.2, Pstutter(3, Pwhite(0.65, 0.8, 1)), 3), counter: Pseries(0, 1, inf).collect { |c| x.add(c); c }];

p.child.argPairs = [amp: Pgeom(0.2, Pstutter(3, Pwhite(0.65, 0.8, 1)), 3), pan: Pstutter(3, Pwhite(0.7, 1.0, 1) * Prand(#[-1, 1], 1)) * Pseq(#[0, -1, 1], 1)];

x.histo(3, 0, 2);
*/

p.child.argPairs = [amp: Pgeom(0.2, Pstutter(3, Pwhite(0.75, 0.9, 1)), 3), pan: Pseries(0, Pstutter(10, Pwhite(0.34, 0.5, 1) * Prand(#[-1, 1], 1)), 3), width: Pseq([Pwhite(0.1, 0.25, 1), 0.5, 0.5], 1)];

p.child.argPairs = [amp: 0.1, pan: Pseries(0, Pstutter(10, Pwhite(0.34, 0.5, 1) * Prand(#[-1, 1], 1)), 3), width: /*Pseq([0.25, */Pstutter(10, Pwhite(0.05, 0.15, 1))/*])*/, ffreq: Pgeom({ exprand(8000, 12000) }, Pstutter(10, Pwhite(0.25, 0.4, 1)), 3), rq: 0.1];

x = Pseq(#[-1, 1], inf).asStream;
p.child.argPairs = [amp: Pseq(#[0.17, 0.1, 0.1]), pan: Plazy({ (rrand(0.7, 1.0) * x.next).loop }), width: /*Pseq([0.25, */Pstutter(10, Pwhite(0.05, 0.15, 1))/*])*/, ffreq: Pgeom({ exprand(8000, 12000) }, Pstutter(10, Pwhite(0.15, 0.22, 1)), 3), rq: Pseq(#[0.1, 0.4, 1.0], inf)];

p.reset;
e = p.eventStream.next(p.event.copy);

e.copy.play;

e = (instrument: \tri, degree: 1, sustain: 2, width: 0.5, ffreq: 10000).play;
{ s.sendMsg(\n_trace, e.id[0]) }.defer(0.25);

VarSaw.ar( freq: 440, iphase: 0, width: 0.5, mul: 1, add: 0 )


// triplet driver
Prand(MacRh(#[tshort, tmid, tlong]), 3) => MacRh(\triPrand);
MacRh(\triPrand) => BP(\tri);

// PR(\collectEmbed).copy.prep(Pstutter(Pwhite(1, 2, inf), Pseq(#[tlong, tmid, tshort, tmid, tlong])), MacRh(_)) => MacRh(\accelrit);

(
PR(\abstractProcess).clone {
	~event = (eventKey: \hang);
	// ~bp = nil;  // name of bp
	~playMode = \default;

	~alwaysReset = true;

	~prep = { |bpname|
		~cond = Condition.new;
		~event.put(\cond, ~cond);
		~modes = ~modes.value;
		~bp_.(bpname ?? ~bp);
		currentEnvironment
	};
	~freeCleanup = { ~resp.remove };

	~bp_ = { |bpname|
		if(bpname != ~bp or: { ~resp.isNil }) {
			~resp.remove;
			~bp = bpname;
			// wrong, we want to wait for the parent to stop, not each arpeg
			// ~resp = NotificationCenter.register(BP(~bp).child, \childStop, ~collIndex, e {
			// 	~cond.unhang;
			// });
			~resp = Updater(BP(~bp), e { |obj, what, more|
				if(more == \stopped) { ~cond.debug("unhang").unhang };
			});
		};
		currentEnvironment
	};

	~dftRest = Pwhite(6.0, 10.0, inf);

	~modes = { (
		default: (
			stopChild: false,
			prepare: {
				MacRh(\tlong) => BP(~bp);
			},
			asPattern: {
				Pbind(
					\action, e { BP(~bp).play(0) },
					\delta, BPStream(\dftRest)
				)
			},
		),
		overlap: (
			// prepare: {
			// },
			asPattern: {
			},
			stopChild: false
		),
		at2: { |me, subKey ... keys|
			var k = keys.detect { |key| me[key][subKey].notNil };
			me[k ?? { \default }][subKey]
		}
	) };

	~preparePlay = {
		~modes.at2(\prepare, ~playMode).value;
	};

	~asPattern = {
		~modes.at2(\asPattern, ~playMode).value;
	};

	~stopCleanup = {
		if(~modes.at2(\stopChild, ~playMode)) { BP(~bp).stopNow };
	};
} => PR(\triDriver);
)

BP(\td).free;
PR(\triDriver).chuck(BP(\td), nil, (bp: \tri));

q = BP(\td);
q.quant = 0;
q.clock = ~clock88;

q.modes[\accelrit] = (prepare: { MacRh(\accelrit) => BP(~bp) });

Plazy({
	var dur = rrand(9.0, 16.0), proportion = rrand(0.3, 0.7);
	Plimitsum(dur, Pexprand(0.8, 1.25, inf)
		// * Env([2.0, 0.8, 2.0], [proportion, 1 - proportion] * dur, \exp).postcs);
		* Env(rrand(#[1.5, 0.56, 1.8], #[2.2, 0.75, 2.4]), [proportion, 1 - proportion] * dur, \sin));
}) => MacRh(\accelrit);
MacRh(\accelrit) => BP(\tri);

BP(\td).triggerOneEvent;  // careful, must be in a routine to do this b/c of hang

{ |env, timeScale = 1, lo = 0.8, hi = 1.25|
	var times = env.times * timeScale;
	Plimitsum(times.sum, Pexprand(0.8, 1.25, inf) * env.copy.times_(times))
} => Func(\envRandWrap);

Plazy({
	\envRandWrap.eval(Env([rrand(0.4, 0.6), rrand(2.0, 2.5)], #[1], \exp), rrand(6.0, 11.0))
}) => MacRh(\decel);
MacRh(\decel) => BP(\tri);

Plazy({
	var ratio = rrand(0.6, 0.75);
	\envRandWrap.eval(Env([rrand(2.0, 2.5), rrand(0.4, 0.6), rrand(0.4, 0.6), rrand(1.4, 1.7)], [ratio, 0.9 - ratio, 0.1], \exp), rrand(11.0, 16.0))
}) => MacRh(\accel);
MacRh(\accel) => BP(\tri);

Library.put(\currentBassNote, SequenceNote(0, 1, 1, 1));

x = Penvir((time: 0), Pclutch(Pstutter(Pwhite(3, 9, inf), Pwhite(0, 6, inf)), Pfunc({ (thisThread.beats - ~time > 0).value(~time = thisThread.beats) })));
Library.put(\currentBassNote, x.asStream);


q.playMode = \accelrit;
MacRh(\accelrit).v.asPattern

MacRh(\triplet) => BP(\tri);
MacRh(\accelrit) => BP(\tri);


Pstutter(Pwhite(3, 5, inf), Pwhite(2.0, 3.5, inf)) / Ptuple([Plazy({ BP(\tri).overlapCtl.asPattern }), 1], inf) => MacRh(\tpOverlap);

SynthDef(\overlapEnv, { |out|
	Out.kr(out, EnvGen.kr(
		Env(
			[Rand(3.0, 3.2), Rand(8.0, 8.5), Rand(3.7, 4.2), 3],
			[Rand(7, 9), Rand(10, 14), Rand(5, 7)], 
			#[2, 5, -3]
		),
		doneAction: 2
	))
}).add;

// overlap
q.modes[\overlap] = (
	prepare: {
		MacRh(\tpOverlap) => BP(~bp);
	},
	asPattern: {
		Pbind(
			\action, e {
				BP(~bp).overlapCtl
				.watch
				.automate(\overlapEnv)
				.onFree(e { BP(~bp).stopNow });
				BP(~bp).play(0);
			},
			\delta, BPStream(\dftRest)
		)
	}
);

q.playMode = \overlap;

q.cond = Condition.new; q.event.cond = q.cond;

p.macro

q.modes.at2(\asPattern, \accelrit).postcs
q.modes.at2(\asPattern, \default) === q.modes.at2(\asPattern, \default)

q.modes[\default][\asPattern] = {
	Pbind(
		\action, e { BP(~bp).debug("NOW PLAYING").play(0) },
		\delta, BPStream(\dftRest)
	).trace
};

q.cond.dump

q.cond.unhang

~not = NotificationCenter.register(BP(\tri).child, \childStop, \test, e {
	"childStop notification".debug;
});
~not.remove;

q.freeCleanup = nil;