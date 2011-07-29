~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);
s.addr = ~debugAddr;
s.addr = ~saveAddr;

TempoClock.default.gui;
TempoClock.default.tempo = 63/60;

BP.loadGui;

~master = MixerChannel(\master, s, 2, 2, level: 1);
~master => MCG(7);
MixingBoard.at(0).refresh;

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
m => MCG(0); n => MCG(1);
)


// drones
(
WrapInstr(\dronetone, { |freq, detuneRatio = 1.003, width = 0.2,
	gate = 1, vsens = 0.8, env, envScaleUp = 1, envScaleDown = 1
	bufbase = 0, numbufs = 8, basefreq = 440, topfreq = 12543|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		// big cpu hit with this
		// sig = Pulse.ar(freq * [1, detuneRatio], width, amp).sum,
		// instead, use my buffer-mapping magic trick
		// detuneRatio should be close to 1.0, no need to calculate multiple mappings
		baselog = log2(basefreq),
		freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
			* (numbufs - 1)).clip(0, numbufs - 1.001),
		freqs = freq * [1, detuneRatio],
		// http://www.musicdsp.org/showone.php?id=8
		saw1 = Osc.ar(bufbase + freqmap, freqs, 0, amp),
		saw2 = DelayL.ar(saw1, maxdelaytime: 0.1, delaytime: width / freqs),
		sig = (saw1 - saw2).sum,
		initTrig = Impulse.kr(0),
		eg_fb = Select.kr(initTrig, [LocalIn.kr(1), 0]),
		// switch timescale when env starts going down
		goingDown = (PulseCount.kr(HPZ1.kr(eg_fb) < 0) >= 1
			+ (gate <= 0)) > 0,
		scale = Select.kr(goingDown, [envScaleUp, envScaleDown]),
		eg = EnvGen.kr(env, gate, timeScale: scale, doneAction: 2);
	LocalOut.kr(eg);
	sig * eg;
}, [\freq, \mydetune, \unipolar,
	\amp, \unipolar, EnvSpec(Env.adsr), #[0.1, 10, \exp], #[0.1, 10, \exp],
	\mybuf, #[1, 16, \lin, 1], \freq, \freq
]);

WrapInstr(\highdrone, { |bpDownRatio = 0.2, rq = 0.08, mix = 0.56,
	lpsrcfreq = 4000, lpfxfreq = 8000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01|
	var	sig = WrapInstr.wrap(\dronetone),
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfxfreq * bpDownRatio, lpfxfreq),
		filts;
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	XFade2.ar(LPF.ar(sig, lpsrcfreq), LPF.ar(filts, lpfxfreq), mix);
}, [#[0.1, 1.0, \exp], \myrq, \bipolar, \freq, \freq,
	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp]
]);

WrapInstr(\droneFiltEnv, { |bpDownRatio = 0.2, rq = 0.08, mix = 0.56,
	lpsrcfreq = 4000, lpfxfreq = 8000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01,
	fenv, gate = 1|
	var	sig = WrapInstr.wrap(\dronetone, [nil, nil, nil, gate]),
	filtenv = fenv.dereference.value,
	feg = EnvGen.kr(filtenv, gate),
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfxfreq * feg * bpDownRatio, lpfxfreq),
		filts;
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	XFade2.ar(LPF.ar(sig, lpsrcfreq * feg), LPF.ar(filts, lpfxfreq), mix);
}, [#[0.1, 1.0, \exp], \myrq, \bipolar, \freq, \freq,
	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp],
	EnvSpec(Env.one), #[0, 1]
]);

(
keys: #[master],
wrapinstr: \highdrone,
voicerargs: {
	[
		env: Env.adsr(0.9, 1.2, 0.8, 1.8), chorusFreq: `0.1, chorusDelay: `0.018,
		chorusWidth: `0.01, vsens: 0.8, lpsrcfreq: 2800, lpfxfreq: 7000,
		bufbase: `(~bufs[0].bufnum), numbufs: `(~bufs.size),
		basefreq: `(48.midicps), topfreq: `16744,
		mix: 0.3
	] ++ ~extraArgs.()
},
extraArgs: nil,
make: { |name|
	var	out;
	~target = MixerChannel(name, s, 2, 2, level: -20.dbamp, outbus: ~master);
	// // KABOOM
	// ~bufs = \makeWavetables.eval(8, s, 1024, 48, { |numharm|
	// 	Array.sawtoothAmps(numharm)
	// });

	~bufs = Buffer.allocConsecutive(8, s, 1024, 1);
//	fork {
		\modWavetables.eval(~bufs, 48, { |numharm|
//			0.1.wait;
			Array.sawtoothAmps(numharm)
		});
//	};
	out = Voicer(20, WrapInstr(~wrapinstr), ~voicerargs.value, target: ~target);
	// out.mapGlobal(\width, nil, 0.2, #[0.02, 0.98]);
	out.mapGlobal(\rq, nil, 0.08, \myrq);
	// out.mapGlobal(\mix, nil, 0.3, \bipolar);
	~widthCtl = GenericGlobalControl(\width, nil, 0.2, #[0.02, 0.98]);
	out
}, free: { [~target, ~widthCtl, ~bufs].free }, type: \voicer) => Fact(\pulseDrone);

PR(\abstractProcess).clone {
	// nextDelta needs to be false by default for use in Pgate
	~event = (eventKey: \voicerNote, nextDelta: false);
	~alwaysReset = true;

	~mode = \d;
	~top = Pfsm([
		#[0, 1],
		Prout({ |ev|
			ev[\nextDelta] = true;  // this is a hack
			Pseq(#[7, 4], 1).embedInStream(ev)
		}), #[0, 1].weight(#[1, 3]),
		Prout({ |ev|
			ev[\nextDelta] = true;
			Pseq(#[7, 8], 1).embedInStream(ev)
		}), #[0, 1, 2, 3].weight(#[3, 2, 1, 11]),
		Pfuncn({ |ev| ev[\nextDelta] = true; 11 }), #[0, 1],
		Pfuncn({ |ev| ev[\nextDelta] = true; 11 }), #[4],
		nil, nil
	]) + 35;
	~degree = Pkey(\top);
	~gate = Pfunc({ |ev| (0.2 ! ev[\freq].size).put(0, 0.5) });
	~delta = Pgate(
		Pif(
			Pkey(\top) < 46,
			Pstutter(Pwrand(#[1, 2, 3], #[6, 3, 1].normalizeSum, inf),
				Pwhite(0.4, 0.7) * Prand(#[0.5, 1], inf)),
			Pwhite(3, 5, inf) * 0.5
		), inf, \nextDelta
	);
	~length = Pkey(\delta) * Pif(Pkey(\delta) < 1, 0.6, 1);
	~width = Pwhite(0.08, 0.18, inf);
	~lpsrcfreq = 2000;
	~lpfxfreq = Pexprand(2000, 6000, inf);  // Pexprand(3000, 12000, inf);
	~mix = Pwhite(0.6, 1.0, inf);
	~bpDownRatio = 0.7;
	~envScaleUp = 0.2;
	~envScaleDown = 0.7;

	~bottoms = (39: 34, 42: 33, 43: 37, 46: 38);

	~degree = Pn(
		(Pfin(1, Pkey(\top)) -.x Paccum(
			start: 0,
			step: Pconst(
				(Pkey(\top) - Pfunc({ |ev| ~bottoms[ev[\top]] })).asStream,
				Pwhite(1, 3, inf)
			),
			length: inf)
		).clump(100),
		inf
	);

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\top, BPStream(\top, resetSource: true),
			\freq, BPStream(\degree, resetSource: true),
			\gate, BPStream(\gate),
			\delta, BPStream(\delta, resetSource: true),
			\length, BPStream(\length),
			\width, BPStream(\width),
			\lpsrcfreq, BPStream(\lpsrcfreq),
			\lpfxfreq, BPStream(\lpfxfreq),
			\mix, BPStream(\mix),
			\bpDownRatio, BPStream(\bpDownRatio),
			\envScaleUp, BPStream(\envScaleUp),
			\envScaleDown, BPStream(\envScaleDown)
		)
	};
} => PR(\brightChords);

\chuckIf.eval(ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 2), Mode, \d);
)

();

VC(\pd).env.bufs.free;

VC(\pd).free;
Fact(\pulseDrone) => VC(\pd);
VC(\pd) => VP(0);
VC(\pd) => MCG(2);

VC(\pd).env.widthCtl.watch.automate({
	LFDNoise1.kr(LFNoise1.kr(0.2).exprange(0.1, 3.0)).range(0.1, 0.8)
}, target: VC(\pd).env.target.synthgroup, addAction: \addToHead);

VC(\pd).env.widthCtl => VP(0);

VC(\pd).env.widthCtl.stopWatching;
VP(0).v.controlProxies[1].gc = nil;

VC(\pdswp).free;
Fact(\pulseDrone).chuck(VC(\pdswp), nil, (
	wrapinstr: \droneFiltEnv,
	extraArgs: [fenv: `{
		var	fAtk = NamedControl.kr(\fAtk, 0.1),
		fDcy = NamedControl.kr(\fDcy, 0.2),
		fSus = NamedControl.kr(\fSus, 0.3),
		fRel = NamedControl.kr(\fRel, 5.0),
		fSens = max(0.01, NamedControl.kr(\fSens, 0.01));
		Env.adsr(fAtk, fDcy, fSus, fRel, peakLevel: fSens, bias: 1 - fSens, curve: \exp)
	}]
));
VC(\pdswp) => VP(0);
VC(\pdswp) => MCG(1);


k.noteOnArgsPat = Pbind(\width, VC(\pd).env.widthCtl.asMap);

VC(\pd).v.trace;

VC(\pd).v.trigger(62.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
VC(\pd).v.trigger(64.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);

VC(\pd).v.release([62, 64].midicps);


BP(\bc).free;
PR(\brightChords) => BP(\bc);
VC(\pd) => BP(\bc);
BP(\bc).quant = 0;

BP(\bc) => MT(1);


BP(\bc).event.nextDelta = false;

// can get stuck in a loop
BP(\bc).top = PnNilSafe(Pfsm([
	#[0, 1],
	Pseq(#[7, 4], 1), #[0, 1].weight(#[1, 3]),
	Pseq(#[7, 8], 1), #[0, 1, 2, 3].weight(#[3, 2, 1, 11]),
	11, #[0, 1],
	11, #[4],
	nil, nil
]), inf) + 35;

BP(\bc).top = //PnNilSafe(
	Pfsm([
		#[0, 1],
		Prout({ |ev|
			ev[\nextDelta] = true;  // this is a hack
			Pseq(#[7, 4], 1).embedInStream(ev)
		}), #[0, 1].weight(#[1, 3]),
		Prout({ |ev|
			ev[\nextDelta] = true;
			Pseq(#[7, 8], 1).embedInStream(ev)
		}), #[0, 1, 2, 3].weight(#[3, 2, 1, 11]),
		Pfuncn({ |ev| ev[\nextDelta] = true; 11 }), #[0, 1],
		Pfuncn({ |ev| ev[\nextDelta] = true; 11 }), #[4],
		nil, nil
	])
//	, inf)
+ 35;

BP(\bc).delta = Pgate(
	Pif(
		Pkey(\top) < 46,
		Pstutter(Pwrand(#[1, 2, 3], #[6, 3, 1].normalizeSum, inf),
			Pwhite(0.4, 0.7) * Prand(#[0.5, 1], inf)),
		Pwhite(3, 5, inf) * 0.5
	), inf, \nextDelta
);

BP(\bc).lpfxfreq = Pexprand(2000, 6000, inf);

BP(\bc).bottoms = (39: 34, 42: 33, 43: 37, 46: 38);

BP(\bc).use {  // use, 'cause Pfunc is a bastard
	~degree = Pn(
		(Pfin(1, Pkey(\top)) -.x Paccum(
			start: 0,
			step: Pconst(
				(Pkey(\top) - Pfunc({ |ev| ~bottoms[ev[\top]] })).asStream,
				Pwhite(1, 3, inf)
			),
			length: inf)
		).clump(100),
		inf
	);
};

BP(\bc).length = Pkey(\delta) * Pif(Pkey(\delta) < 1, 0.6, 1);
BP(\bc).gate = Pfunc({ |ev| ((~topGate * 0.4) ! ev[\freq].size).put(0, ~topGate) });
BP(\bc).topGate = 0.5;

BP(\bc).gateStream.instVarAt(2).listVars

BP(\bc).reset;

8.partition(3)
(39-34).partition(2)

34 + (#[0] ++ #[1, 4].integrate)

~bottoms = (39: 34, 42: 33, 43: 37, 46: 38);

x = Pn(
	(Pfin(1, Pkey(\top)) -.x Paccum(
		start: 0,
		step: Pconst(
			(Pkey(\top) - Pfunc({ |ev| ~bottoms[ev[\top]] })).asStream,
			Pwrand(#[1, 2, 3], #[0.25, 0.4, 0.35], inf)
		),
		length: inf)
	).clump(100),
	inf
).asStream;

x.next((top: 46))


// repeating chords
(
BP(\rpt).free;
PR(\brightChords).chuck(BP(\rpt), nil, (
	topstutter: 100,
	// will always refresh b/c of resetSource: true
	top: Plazy({
		Pstutter(~topstutter, Pxrand(#[46, 47], inf))
	}),
	degstutter: 100,
	degree: Plazy({
		var	chordify = Pn(
			(Pfin(1, Pkey(\top)) -.x Paccum(
				start: 0,
				step: Pconst(
					(Pkey(\top) - Prand((33..40) ++ 38.5, inf)).asStream,
					Pwhite(1, 3, inf)
				),
				length: inf)
			).clump(100),
			inf
		);
		Pswitch1(Pstutter(~degstutter, chordify) ! 2, Pkey(\top) - 46)
	}),
	delta: Pseq([Pstutter(Pwhite(3, 10, 1), Pwhite(0.12, 0.28, inf)), Pwhite(0.7, 1.1, 1)], 1),
	length: Pkey(\delta) * Pif(Pkey(\delta) < 0.7, 0.3, 1)
));
0 => BP(\rpt);
VC(\pd) => BP(\rpt);
)

BP(\rpt).use {
	~degstutter = 100;
	~makeStreamForKey.(\degree);
};

BP(\rpt).use { ~degreeStream.next((top: 46)) };
BP(\rpt).use { ~degreeStream.next((top: 47)) };

p = BP(\rpt);
p.delta = Pseq([Pstutter(Pwhite(3, 10, 1), Pwhite(0.12, 0.28, inf)), Pwhite(0.7, 1.1, 1)], 1);
p.length = Pkey(\delta) * Pif(Pkey(\delta) < 0.7, 0.3, 1);

p.topstutter = Pwhite(1, 3, inf);

			\mode, BPStream(\mode),
			\top, BPStream(\top, resetSource: true),
			\freq, BPStream(\degree, resetSource: true),
			\gate, BPStream(\gate),
			\delta, BPStream(\delta, resetSource: true),
			\length, BPStream(\length),
			\width, BPStream(\width),
			\lpsrcfreq, BPStream(\lpsrcfreq),
			\lpfxfreq, BPStream(\lpfxfreq),
			\mix, BPStream(\mix),
			\bpDownRatio, BPStream(\bpDownRatio),
			\envScaleUp, BPStream(\envScaleUp),
			\envScaleDown, BPStream(\envScaleDown)


// more
t.stop;
(
if(t.isPlaying) { t.stop };
t = TLSequenceIterator([
	Quant(1),
	funcCmd: (
		id: \drone,
		setDoneSignal: { ~doneSignal = true },
		func: {
			VC(\pd).v.setArgDefaults([\vsens, 0.95]);
			VC(\pd).v.trigger([62, 74].midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
		},
		clearDoneSignal: {
			VC(\pd).v.release([62, 74].midicps);
		}
	),
	9,
	funcCmd: (
		id: \drone,
		setDoneSignal: { ~doneSignal = true },
		func: {
			VC(\pd).v.trigger(64.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
		},
		clearDoneSignal: {
			VC(\pd).v.release(64.midicps);
		}
	),
	4,
	funcCmd: (
		id: \drone,
		setDoneSignal: { ~doneSignal = true },
		func: {
			VC(\pd).v.trigger(76.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
		},
		clearDoneSignal: {
			VC(\pd).v.release(76.midicps);
		}
	),
	{ BP(\bc).topGate = 0.25; 5 },
	loopCmd: (
		id: \chords,
		bpStream: \bc,
		waitStream: Pseq([0, Pwhite(2, 5, inf)]).asStream,
		cmds: [
			{ ~waitStream.next },
			{
				var next = ~bpStream.next.debug("next bp");
				if(next.notNil) { PR(\bpCmd).copy.put(\name, next) }
				// else, returns nil and loopCmd will stop
			},
			\cmdSync
		],
		clearDoneSignal: { "loopcmd stopped".debug }
	),
	24,
	funcCmd: (func: {
		~iterator.findActive(\chords).bpStream = Pseq([\rpt, Prand(#[bc, rpt], inf)]).postcs.asStream;
	}),
	10,
	funcCmd: (func: {
		~iterator.findActive(\chords).putAll((bpStream: nil, repeats: 0));
	}),
	funcCmd: (
		doneSignal: true,
		func: {
			"waiting for \\chords to end".debug;
			NotificationCenter.registerOneShot(
				~iterator.findActive(\chords), \done, currentEnvironment, e {
					"got done signal".debug;
					~stop.();
				}
			)
		},
		clearDoneSignal: {
			"stopping drone notes".debug;
			~iterator.activeCmds.copy.do { |cmd|
				if(cmd.id == \drone) { cmd.stop };
			};
		}
	)
]).play;

NotificationCenter.registerOneShot(t, \done, \toplevel, { "seq stopped".debug });
)

t.stop;

VC(\pd).v.setArgDefaults([\vsens, 0.95]);
VC(\pd).v.nodes[0].initArgs;

VC(\pd).env.bufs[0].plotWavetable

BP(\bc).free; VC(\pd).free;

s.quit;
\supernova.eval;
s.boot;


// drones

k.free;
k = VoicerMIDISocket(0, VP(0).v);

k.noteOnArgsPat = Pbind(\envScaleUp, 0.6, \fAtk, 0.3, \fDcy, 0.8, \fSus, 0.0, \fSens, 0.74);

VC(\pdswp).trace;

VC(\pdswp).env.widthCtl.automate({
	LFDNoise1.kr(LFNoise1.kr(0.2).exprange(0.1, 3.0)).range(0.1, 0.8)
}, target: VC(\pdswp).env.target.synthgroup, addAction: \addToHead);

VC(\pdswp).env.widthCtl => VP(0);

VC(\pdswp).env.widthCtl.stopWatching;
VP(0).v.controlProxies[1].gc = nil;


p = Pbind(
	\type, \voicerNote,
	\voicer, VP(0).v,
	\degree, Pn(Pshuf(#[1, 2, 8, 9], 1), inf),
	\dur, Pseq([
		Pwhite(1.8, 3.5, { rrand(3, 7) }),
		Pwhite(0.4, 0.9, { rrand(3, 9) })
	], inf),
	\sustain, Pwhite(7.0, 14.0, inf),  // Pkey(\dur) * Pwhite(1.8, 3.8, inf),
	\envScaleUp, 0.6,
	\fAtk, Pif(Pkey(\dur) >= 1.8, 0.3, 0.1),
	\fDcy, Pkey(\dur) * Pwhite(0.5, 0.75, inf),
	\fSus, 0.0,
	\fSens, 0.9,
	\gate, Pexprand(0.2, 0.7, inf),
	\lpsrcfreq, Pexprand(1800, 3200, inf),
	\lpfxfreq, Pexprand(5000, 10000, inf),
	\width, VC(\pdswp).env.widthCtl.asMap
).play;

p.stop;

(
PR(\abstractProcess).clone {
	~event = (eventKey: \default, type: \voicerNote);

	~root = 2;
	~notes = #[0];
	~degree = Plazy({
		Pindex(
			~notes,
			if(~notes.size > 1) {
				Pseq([0, Pshuf((1 .. ~notes.size-1), 1), Pshuf((0 .. ~notes.size-1), inf)], 1)
			} {
				Pn(0, inf)
			}
		)
	});
	~dur = Pseq([
		Pwhite(1.8, 3.5, { rrand(3, 7) }),
		Pwhite(0.4, 0.9, { rrand(3, 9) })
	], inf);
	~sustain = Pwhite(7.0, 14.0, inf);
	~envScaleUp = 0.6;
	~fAtk = Pif(Pkey(\dur) >= 1.8, 0.3, 0.1);
	~fDcy = Pkey(\dur) * Pwhite(0.5, 0.75, inf);
	~fSus = 0.0;
	~fSens = 0.9;
	~gate = Pexprand(0.2, 0.7, inf);
	~lpsrcfreq = Pexprand(1800, 3200, inf);
	~lpfxfreq = Pexprand(5000, 10000, inf);

	~asPattern = {
		Pbind(
			\root, BPStream(\root),
			\degree, BPStream(\degree),
			\dur, BPStream(\dur),
			\sustain, BPStream(\sustain),
			\envScaleUp, BPStream(\envScaleUp),
			\fAtk, BPStream(\fAtk),
			\fDcy, BPStream(\fDcy),
			\fSus, BPStream(\fSus),
			\fSens, BPStream(\fSens),
			\gate, BPStream(\gate),
			\lpsrcfreq, BPStream(\lpsrcfreq),
			\lpfxfreq, BPStream(\lpfxfreq) //,
			// \width, BPStream(\width)
		)
	};

	~setNotes = { |noteArray(#[0]), quant|
		~notes = noteArray;
		~makeStreamForKey.(\degree);
		if(~isPlaying and: { quant.notNil }) {
			~eventStreamPlayer.stop;
			~eventStreamPlayer = EventStreamPlayer(~eventStream, ~event);
			~eventStreamPlayer.play(~clock, quant: quant);
		};
	};

	~bindVoicer = { |vc|
		~vcKey = VC.keys.detect { |key| VC(key).value === vc };
		~event.put(\width, VC(~vcKey).env.widthCtl.asMap);
		currentEnvironment
	};
} => PR(\dedrone);
)

BP(\dd).free;
PR(\dedrone) => BP(\dd);
VC(\pdswp) => BP(\dd);
1 => BP(\dd);

Pn(Pshuf(#[0, 1, 7, 8], 1), inf);

BP(\dd).put('setNotes', { |noteArray(#[0]), quant|
	~notes = noteArray;
	~makeStreamForKey.(\degree);
	if(~isPlaying and: { quant.notNil }) {
		~eventStreamPlayer.stop;
		~eventStreamPlayer = EventStreamPlayer(~eventStream, ~event);
		~eventStreamPlayer.play(~clock, quant: quant);
	};
});
BP(\dd).degree = Plazy({
	Pindex(
		~notes,
		if(~notes.size > 1) {
			Pseq([0, Pshuf((1 .. ~notes.size-1), 1), Pshuf((0 .. ~notes.size-1), inf)], 1)
		} {
			Pn(0, inf)
		}
	)
});

BP(\dd).setNotes(#[0]);

BP(\dd).setNotes(#[1, 0], 1);
BP(\dd).setNotes(#[7, 1, 0], 1);
BP(\dd).setNotes(#[8, 7, 1, 0], 1);


// bass
VC(\fmb).free;
Fact(\fmbass) => VC(\fmb);

MIDIRecBuf(\ebass, [
	#[40, 45, 35, 40, 38, 43, 42],
	#[3, 1, 3, 1, 1.5, 3, 3.5],
	#[2.9, 1.1, 2.9, 1.1, 1.4, 3.1, 3.5],
	0.5
].asNotes) => MBM(0);

BP(\bass).free;
PR(\mel1) => BP(\bass);
MBM(0)[\ebass] => BP(\bass);
VC(\fmb) => BP(\bass);

PR(\mel1).openFile

BP(\bass).repeats = 1;
BP(\bass).asNotePattern = { 
	// Pfunc is roughly 6.7 times SLOWER than Prout
	Prout({ |inval|
		~repeats.do {
			~index = 0;
			while { ~index < ~sequence.size } {
				inval = ~sequence[~index].postln.embedInStream(inval);  // output
				~index = ~index + 1;
			};
		};
	});
};

0 => BP(\bass);

BP(\bass).sequence.size
.dumpSeq

(
make: { |name|
	BP(name).free;
	PR(\mel1).chuck(BP(name), nil, (
		repeats: 1,
		printStopMsg: false
	));
	1 => BP(name);
	try {
		MBM(0).v[\ebass] => BP(name);
	} { |err|
		if(err.class == DoesNotUnderstandError and: { err.selector == \v }) {
			"MBM(0) doesn't exist; couldn't set melody for BP(%)."
			.format(name.asCompileString).warn;
		} {
			err.throw
		}
	};
	BP(name)
}, type: \bp) => Fact(\ebassBP);

BP(\bass).free;
Fact(\ebassBP) => BP(\bass);
VC(\fmb) => BP(\bass);


ProtoEvent(\voicerNote).copy.make {
	~droneQuant = 1;
	~superPlay = ~play;
	~play = { |server|
		var	notes;
		~superPlay.(server);
		if(~droneBP.notNil) {
			if(~addNotes ? false) {
				notes = BP(~droneBP).notes;
				BP(~droneBP).setNotes(( ++ ~freq).debug("notes"), nil);
			};
			BP(~droneBP).override(\degree, Pn(~freq, 1));
			BP(~droneBP).resetTime(~droneQuant);
		};
	};
} => ProtoEvent(\bellAccent);

(
PR(\abstractProcess).clone {
	~event = (eventKey: \bellAccent, droneBP: \dd);
	~alwaysReset = true;
	~mode = \d;
	~degree = 35;
	~dur = 8;
	~sustain = Pwhite(5.0, 8.0, inf);
	~gate = Pexprand(0.2, 0.7, inf);
	~pan = Pwhite(-0.9, 0.9, inf);
	~mod_lev = 4.13;
	~mod_ratio = 5;
	~addNotes = false;
	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\degree, resetSource: true),
			\dur, BPStream(\dur, resetSource: true),
			\length, BPStream(\sustain),
			\sustain, Pkey(\length),
			\gate, BPStream(\gate),
			\pan, BPStream(\pan),
			\mod_lev, BPStream(\mod_lev), 
			\mod_ratio, BPStream(\mod_ratio),
			\addNotes, BPStream(\addNotes)
		)
	};
} => PR(\bellAccent);
)

BP(\ba).free;
PR(\bellAccent) => BP(\ba);
VC(\fmbell) => BP(\ba);

p = BP(\ba);
p.degree = Pseq(#[[35, 42], 36, 43], 1);
p.dur = Pseq(#[9, 4, 4], 1);
p.leadTime = 0.02;
p.addNotes = true;

(
if(t.isRunning) { t.stop };
t = TLSequenceIterator([
	{
		BP(\dd).setNotes(#[], nil);
		BP(\dd).reset;
		BP(\ba).reset;
		0
	},
	Quant(1, -0.1),
	bpCmd: (name: \ba, quant: 1),
	0.1,
	bpCmd: (name: \dd, quant: 1)
]).play;
)

BP(\dd).notes

(
var upd = Updater(BP(\dd), { |obj, what, more|
	if(what == \free) { upd.remove };
	thisThread.beats.debug(what);
});
)
