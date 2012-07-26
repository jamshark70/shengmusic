forkIfNeeded {
var cond = Condition.new;

if(PR.exists(\shengShared).not) {
	loadPath(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd");
};

if(BP.exists(\shengShared).not) {
	PR(\shengShared) => BP(\shengShared);
	NotificationCenter.registerOneShot(BP(\shengShared).v, \sharedReady, \longch, {
		cond.unhang;
	});
	cond.hang;
};


// RAPID PIZZES

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



// TRIPLET GESTURE

WrapInstr("osc2.v3mappan", { |pan, holdtime = 1|
	var sig = WrapInstr.wrap("osc2.vosc3mapfilt");
	Line.kr(0, 1, holdtime + 0.15, doneAction: 2);  // zombie killer
	Pan2.ar(sig, pan);
}, [\bipolar, #[0.01, 10], \amp]);

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
keys: #[clock88],
childProc: \arpeg1,
oneChordPerArpeg: true,
argPairs: [
	gate: Pseq(#[0.17, 0.1, 0.1]),
	pan: Plazy({ |ev| (~panWidthStream.next(ev) * ~panSideStream.next(ev)).loop }),
	width: Pstutter(10, Pwhite(0.05, 0.15, 1)),
	ffreq: Pgeom({ exprand(8000, 12000) }, Pstutter(10, Pwhite(0.15, 0.22, 1)), 3),
	rq: Pseq(#[0.1, 0.4, 1.0], inf),
	holdtime: Pkey(\length) / Ptempo()
],
make: { |name|
	var p;
	BP(name).free;
	p = \newCh.eval(name, ~childProc, \macroRh, MBM(0)[\tripletCh], nil, MacRh(\triplet), \triplet, \blocks, nil, \d);

	p.topNote = PR(\patternTop).copy.make {
		~deg = Pxrand((33..44), inf);
		~mode = \d;
	};

	p.quant = 0;
	p.clock = ~clock88;
	p.printStopMsg = false;
	p.alwaysReset = true;

	if(~oneChordPerArpeg ? false) {
		// make sure each child pattern stays on the same chord
		// especially for overlap
		p.child.nextNoteStream = #{ |inEvent|
			~nextNotePattern.value(inEvent);
			~updateNoteStream.value(inEvent);
			Pn(~noteStream.next(inEvent), inf);
		};
	};
	p.child.makeChordPattern = { Pxrand(~chords, inf) };
	p.child.fitFunc = \chordFitNotes;

	p.child.panWidth = Pwhite(0.7, 1.0, inf);
	p.child.panSide = Pseq(#[-1, 1], inf);
	p.child.argPairs = ~argPairs;

	p.overlapCtl = GenericGlobalControl(\tpOverlap, nil, 1, #[0.3, 10, \exp]);
	p.useGui = { |vpi| ~overlapCtl => VP(vpi) };
	p.userfree = { ~overlapCtl.free };
	p.event.stopChild = false;

	p
}, type: \bp) => Fact(\tripletBP);


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



{ |source, inEvent, fitFactors, eventValues|
	var	transposeStats,  // [[xpose1, fitness1], [xpose2, fitness2]...]
		xposeBy, mode, topEvent, top, topMode, root, notes;

	#mode, topEvent, top, topMode, root, notes = eventValues;

		// transpose and evaluate for each note
	transposeStats = notes.collect({ |n|
		[xposeBy = (top - n).asFloat,
		 Func(\chPitchFit).doAction(notes + xposeBy, top, root, mode, fitFactors)];
	}).sort({ |a, b| a[1] > b[1] });  // sort fitnesses descending
		// transpose the whole chord
	Func(\fixNotesAboveTop).doAction(notes + transposeStats[0][0], top, mode);
} => Func(\chordFitNotesCustomValues);

{ |source, inEvent, fitFactors|
	var eventValues = Func(\getValuesFromEvent).doAction(source, inEvent),
	evcopy = eventValues.copy,
	top = eventValues[2];

	top.asFloat.asArray.collect { |aTop|
		\chordFitNotesCustomValues.eval(source, inEvent, fitFactors,
			evcopy.put(2, aTop)
		)
	}
} => Func(\chordFitNotesMulti);

{ |notes|
	notes = notes.collect { |item|
		if(item.isArray) {
			item.asChord
		} {
			item
		};
	};
	Pseq(notes, inf)
} => ArpegPat(\blocksMulti);


{ |notes, event| var d = rrand(3, 7); Ptuple([Pn(event[\length] / d, d), event[\length] * 0.7 / d, 0.5]) } => MicRh(\tup);



(
oneChordPerArpeg: false,
argPairs: [
	gate: Pseq([0.17, Pn(0.1, inf)]),
	pan: Plazy({ |ev| (~panWidthStream.next(ev) * ~panSideStream.next(ev)).loop }),
	width: Pstutter(10, Pwhite(0.05, 0.15, 1)),
	ffreq: Pgeom({ exprand(8000, 12000) }, Pstutter(10, Pwhite(0.5, 0.7, 1)), inf),
	rq: Pseq([0.1, min(1, Pgeom(0.4, 0.97, inf))]),
	holdtime: Pkey(\length) / Ptempo()
],
childProc: \arpeg1,
make: { |name|
	var r;
	BP(name).free;
	// you may not chuck a Fact while make-ing a different Fact
	r = Fact(\tripletBP).v[\make].value(name);

	// r.topNote.deg = (Pxrand((33..44), inf) - Ptuple([0, Pwhite(-6, -2, inf)], inf));
	r.topNote.deg = 'patRejectLastN'.eval(Pseries(
		{ rrand(36, 43) },
		Pwrand(#[1, 2, 3], #[0.5, 0.3, 0.2], inf),
		inf
	).fold(36, 43), 1) - Ptuple([0, Pwhite(-6, -2, inf)], inf);
	Pwhite(1, 3, inf) =>.macro r;

	r.child.fitFunc = \chordFitNotesMulti;
	\blocksMulti =>.arpeg r;
	\tup =>.micro r;

	r
},
type: \bp) => Fact(\tupletBP);

};