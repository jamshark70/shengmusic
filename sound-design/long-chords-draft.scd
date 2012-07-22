(thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;

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

(
play: {
	if(~cond.notNil) { ~cond.hang }
	{ "No ~cond, ProtoEvent(\\hang) can't hang".warn }
}, delta: 0
) => ProtoEvent(\hang);

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