(thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;
// (thisProcess.nowExecutingPath.dirname +/+ "../common/common-defs.scd").loadPath;

(thisProcess.nowExecutingPath.dirname +/+ "../processes/drones-and-clicks.scd").loadPath;
(thisProcess.nowExecutingPath.dirname +/+ "../processes/long-ch-procs.scd").loadPath;
(thisProcess.nowExecutingPath.dirname +/+ "../processes/mid-fast-procs.scd").loadPath;
(thisProcess.nowExecutingPath.dirname +/+ "../processes/climax-procs.scd").loadPath;

TempoClock.tempo = 100/60;
TempoClock.default.gui;

BP(\shengShared).free;
PR(\shengShared) => BP(\shengShared);

MixingBoard.at(0).postSettings;

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);

s.addr = ~debugAddr;
s.addr = ~saveAddr;

// SynthDescLib.global.browse;


// metered rhythm blows up at giant chord

// bass
BP(\sd).free;
PR(\shengDrone) => BP(\sd);
0 => BP(\sd);
p = BP(\sd);

p.gst = \midRest;

p.gestures[\bmin] = Pbind(
	\totalDur, 6,
	\dur, Pn(0.5, 12),
	\sustain, 0.4, // max(0.5, Pkey(\totalDur) - Ptime()),
	\octave, 3,
	\deg, Pseq([-2, 2, 5, 9, 11, 15, Pxrand(#[5, 9, 11, 15], inf)]),
	\amp, 0.25
);

p.gesture.postcs;

p.gst = Pn(\bmin, 1);
p.gestureNow(Pn(\bmin, 1));  // perfect, starts with rests, plays, then re-rests

p.gestures[\gmaj] = Pfindur(32, Pbind(
	\dur, Pseq([
		Pn(0.5, 8),
		Pexprand(0.8, 1.25, inf) * Pseg(
			Pseq([0.3, 0.9], inf),
			Pwhite(2.5, 6.0, inf),
			\exp
		)
	]),
	\sustain, Pwhite(0.25, 0.5, inf),
	\octave, 3,
	\deg, Pseq([-4, 0, 3, 7, 11, 12,
		Pseq([
			Pxrand(#[16, 18, 22, 11, 13, 7], { rrand(3, 7, inf) }),
			Pseq(#[-4, 0, 3], 1)
		], inf)
	]),
	\amp, 0.25
));

p.gestures[\emaj] = Pfindur(11.5, Pbind(
	\dur, Pexprand(0.8, 1.25, inf) * Pseg(
		Pseq([0.3, 0.9], inf),
		Pwhite(2.5, 6.0, inf),
		\exp
	),
	\sustain, Pwhite(0.25, 0.5, inf),
	\octave, 3,
	\deg, Pseq([1, 5, 8, 12, 14, 18,
		Pseq([
			Pxrand(#[12, 14, 17.5, 18, 20, 21], { rrand(3, 7, inf) }),
			Pseq(#[1, 5, 8], 1)
		], inf)
	]),
	\amp, 0.25
));

p.gestures[\csmin] = /*Pfindur(32,*/ Pbind(
	\dur, Pexprand(0.8, 1.25, inf) * Pseg(
		Pseq([0.3, 0.9], inf),
		Pwhite(2.5, 6.0, inf),
		\exp
	),
	\sustain, Pwhite(0.25, 0.5, inf),
	\octave, 3,
	\deg, Pseq([-1, 3.5, 6, 10.5, 12,
		Pseq([
			Pxrand(#[12, 13, 17.5, 18, 22], { rrand(3, 7, inf) }),
			Pseq(#[-1, 3.5, 6], 1)
		], inf)
	]),
	\amp, 0.25
)/*)*/;

p.gst = \midRest;
p.setGstNow(Pn(\midRest, inf));

p.setGstNow(Pseq(#[bmin, gmaj]));

p.setGstNow(\emaj);
p.setGstNow(\csmin);

p.setGstNow(Pseq(#[bmin, gmaj, emaj, csmin]));


p.gestures[\gmaj].asStream.next(())

p.makeStreamForKey(\gesture);




// rhythmic, then a-rhythm pizzes
(
VC(\pzrhy).free;
Fact(\pizz).chuck(VC(\pzrhy), nil, (
	trigFunc: `{
		var beatsPerSec = NamedControl.kr(\beatsPerSec, 100/60),
		baseValue = NamedControl.kr(\baseValue, 0.25),
		lfoDepth = NamedControl.kr(\lfoDepth, 1),
		baseFreq = beatsPerSec / baseValue,
		lfo = LFDNoise1.kr(LFNoise1.kr(Rand(0.05, 0.09)).exprange(0.3, 1.4))
		.exprange(lfoDepth.reciprocal, lfoDepth),
		trig = Impulse.ar(baseFreq * lfo);
		trig
	}
));
)

(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98).play;

(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1.8, sustain: 5, amp: 1).play;

(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1.8, sustain: 5, amp: 1, degree: #[0, 1, 3, 4]).play;

// promising

Pseq([
	(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1, sustain: 5, amp: 1, degree: #[0, 1, 3, 4], dur: 5, retrigProb: 0.8),
	(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1.8, sustain: 5, amp: 1, degree: #[0, 1, 3, 4], retrigProb: 0.8)
]).play;

// should slide lfoDepth: use global control?

(
e = (parent: ProtoEvent(\voicerNoteKrBusLock).parent,
	voicer: VC(\pzrhy).v, fbamp: 0.98,
	note: SequenceNote(#[24, 28, 32, 33, 37, 38, 42, 43], 5, 10, 0.5), mode: \d,
	ffreq: Mode(\d).cps(#[24, 28, 32, 33, 37, 38, 42, 43]) * 7,
	amp: 1, retrigProb: 0.8,
	lfoDepth: { ~lock.bus.asMap },
	numCh: 1,
	lpcEv: (
		instrument: \ctlEnv, connect: 0,
		env: Env(#[1, 1, 1.8], #[5, 5], \exp)
	)
).play;
)

// Rhythmic notes at ends of 3/4 bars leading to climax - w/ cresc

MIDIRecBuf(\pzclimax, [
	[
		47, 54, 57, 62, 64, 69, 74,
		43, 50, 57, 59, 66, 67, 74, 76,
		40, 47, 52, 57, 59, 62, 68, 69, 76,
		49, 56, 57, 64, 69, 71, 76
	],
	(0.1 ! 31).put(6, 1).put(14, 1).put(23, 1).put(30, 1),
	0.5, 0.5
].asNotes, (mode: \d, type: \ch)) => MBM(0);

Pseq([Rest(1.5), 1.5, Rest(1.5), 1.5, 32, 11.5, 20], 1) => MacRh(\pzclimax);



(
BP(\pzclimax).free;
\newCh.eval(\pzclimax, \arpeg1, \macroRh, MBM(0)[\pzclimax], nil, MacRh(\pzclimax), \blockFollow, \block, nil, \d);
)

p = BP(\pzclimax);
VC(\pzrhy) => p;
1 => p;

VC(\pzrhy).v.set([retrigProb: 0.6]);

p[\freeCleanup].postcs

p.userfree = { "userfree".debug; ~lfoDepthCtl.free };
p.lfoDepthCtl = GenericGlobalControl(\lfoDepth, nil, 1, #[1, 3, \exp]);
p.useGui = { |vpi| ~lfoDepthCtl => VP(vpi) };

// tuning: sounds flat depending on ratio between filter frequency and sounding frequency
// Pkey(\fratio).linlin(4, 23, 0.6, 0.051)
// I'm using a constant ratio, 7

7.linlin(4, 23, 0.6, 0.051)  // 0.51331578947368

p.child.argPairs = { |parentEvent|
	[
		fbamp: 0.98,
		ffreq: Pfunc({ |ev| ev[\mode].asMode.cps(ev[\note].asFloat) * 7 }),
		amp: 1,
		lfoDepth: BP(\pzclimax).lfoDepthCtl.asMap,
		beatsPerSec: Ptempo(),
		baseValue: 0.25,
		ctranspose: 0.51331578947368,   // sweet, in tune now!
		env: [Env(
			#[0, 0.2, 1, 0],
			#[0.01, 0.94, 0.05] * parentEvent[\length] / thisThread.clock.tempo,
			-4, 2
		)]
	]
};

p.child.listVars

MacRh(\pzclimax) => p;
MBM(0)[\pzclimax] =>.ch p;

p.child.chords.do({ |ch| ch.notes.asFloat.postln }); ""

BP(\pzclimax).child.makeChordPattern = { Pstutter(Pseq(#[2, 1, 1, 1000]), Pseq(~chords, 1)) };

p.alwaysReset = true;

VC(\pzrhy).v.playingNodes.collect { |node| node.frequency.cpsmidi.round };

Mode(\d).cps(43).cpsmidi

// it's ok
// sd approx 2dB less than pzclimax
(
if(t.isPlaying) { t.stop };
t = TLSequenceIterator([
	{	BP(\pzclimax).lfoDepthCtl.value = 1;
		VC(\pzrhy).v.globalControls[\retrigProb].value = 0.6;
		0
	},
	Quant(1),
	[
		bpCmd: (name: \gcl, dur: 15),
		\cmdSync,
		bpCmd: (name: \decelCl, prepareBP: { |q|
			q.makeStreamForKey(\waitTime);
			q.reset;
		})
	],
	bpCmd: (name: \pzclimax, prepareBP: (_.reset),
		clearDoneSignal: { { t.stop }.defer(0.05); }
	),
	bpCmd: (name: \sd, prepareBP: { |p|
		p.setGstNow(Pseq(#[bmin, gmaj, emaj, csmin]).trace);
		p.reset;
	}),
	15,
	{ thisThread.clock.beats.debug("gcautosynth"); 0 },
	gcAutoSynthCmd: (
		gc: BP(\pzclimax).lfoDepthCtl,
		name: \ctlEnv, outName: \outbus,
		connect: 0,
		env: Env(#[1.2, 1.9], #[8] / thisThread.clock.tempo)
	),
	(12*4) + 3 + 2.5 + 1 - 6,
	// not really effective
	{ thisThread.clock.beats.debug("reduce"); VC(\pzrhy).v.globalControls[\retrigProb].value = 0.1; 0 }
]).play;
)

p.lfoDepthCtl.stopWatching

t.isPlaying;
t.stop;

BusDict

q = BP(\sd);

q.setGstNow(Pseq(#[bmin, gmaj, emaj, csmin]));
q.reset;

q.play;
q.stop;


// break up clinks rhythm: deceleration
// must make this first, to send synthdefs
PR(\clicks).chuck(BP(\cl), nil, (master: ~master));

BP(\gcl).free;
PR(\gridClicks).chuck(BP(\gcl), nil, (master: ~master));
1 => BP(\gcl);

p = BP(\gcl);

p.gridDur = p.dur;
p.decelDur = Plazy({ Env([rrand(0.08, 0.12), rrand(0.35, 0.5)], [~latestPhraseDur], \exp).postcs });

p.dur = p.decelDur;

0.1 / TempoClock.tempo

(
BP(\decelCl).free;
// gridClicks has the kick-ass accents
PR(\gridClicks).chuck(BP(\decelCl), nil, (
	master: ~master,
	dur: Plazy({ Env([rrand(0.08, 0.12), rrand(0.35, 0.5)], [~latestPhraseDur], \exp) })
));
)

BP(\decelCl).maxPoly.value = 3;
BP(\decelCl).chan.level = -9.2.dbamp;
1 => BP(\decelCl);

q = BP(\decelCl);

q.waitTime.postcs;
q.waitTime = Pwhite(1.0, 4.0) * Env(#[0.2, 0.2, 1], #[7, 14], \exp);

(
if(t.isPlaying) { t.stop };
t = TLSequenceIterator([
	Quant(1),
	bpCmd: (name: \gcl, dur: 9),
	\cmdSync,
	bpCmd: (name: \decelCl, prepareBP: { |q|
		q.makeStreamForKey(\waitTime);
		q.reset;
	})
]).play;
)

t.stop;



// adapt pizzrhy
p = BP(\pzclimax);

p.listVars;

p.lfoDepthCtl.value = 1;

MBM(0)[\pzch] =>.ch p;

p.child[\argPairs].postcs;

Pwhite(2, 4, inf) =>.macro p;
((Pwhite(4, 10, inf) * Ptuple([1, Pwhite(0.4, 0.75, inf)])).roundUp - #[0, 0.1]).trace(prefix: "macro: ") =>.macro p;

p.child[\makeChordPattern].postcs;

p.child.makeChordPattern = { Pxrand(~chords, inf) };
p.child.fitFunc = \chordFitNotes;
p.topNote = PR(\patternTop).copy.make {
	~mode = \d;
	~deg = Pwhite(35, 43, inf);
};

// for actual climax
p.child.ampEnv = Env(
	#[0, 0.2, 1, 0],
	#[0.01, 0.94, 0.05],
	-4, 2
);

// but here, I want decays
p.child.ampEnv = Env(
	#[0, 1, 0.1, 0],
	#[0.01, 0.94, 0.05],
	-4, 2
);

p.child.argPairs = { |parentEvent|
	var e = ~ampEnv.copy;
	e.times = e.times * (parentEvent[\length] / thisThread.clock.tempo);
	[
		fbamp: 0.98,
		ffreq: Pfunc({ |ev| ev[\mode].asMode.cps(ev[\note].asFloat) * rrand(6.0, 10.0) }),
		amp: 1,
		lfoDepth: BP(\pzclimax).lfoDepthCtl.asMap,
		beatsPerSec: Ptempo(),
		baseValue: 0.25,
		ctranspose: 0.51331578947368,   // sweet, in tune now!
		env: [e]
	]
};

p.recvNotify = NotificationCenter.register(BP(\un), \accent, \pzclimax, {
	BP(~collIndex).triggerOneEvent(0);
}.inEnvir(p.env));

Pwhite(3, 6, inf) * 0.25 =>.macro p;





e = BP(\sd).eventStream.next(BP(\sd).event.copy);

(type: \voicerNote, voicer: VC(\onePizz).v, amp: 1, degree: #[-14, -7, -4, -3, -1, 1, 2, 5], root: 2, ffreq: 600 * 9, excAtk: 4, excDcy: 10, sustain: 30, fbamp: 0.998).play;
VC(\onePizz).v.trace;

VC(\onePizz).v.panic;

VC(\onePizz).v.nodes.size

(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, gate: 0.5);
	~prep = {
		~makeStreamForKey.(\bass);
	};
	~freeCleanup = { ~removeNotification.() };

	~mode = \d0;

	~bass = Pseries({ rrand(20, 27) }, Pwhite(1, 3, inf), inf).fold(20, 28);
	~freq = PnNilSafe(
		Pwhile1(
			{ |ev, next| next <= 44 },
			Pseries(
				{ |ev| ~bassStream.next(ev) },
				Pseq([Prand(#[4, 5], 1), Prand(#[2, 3], 1), Pwrand(#[1, 2, 3], #[0.1, 0.5, 0.4], inf)])
			),
			inf
		).clump(100),
		inf
	);
	~ffreq = Pfunc({ |ev|
		var top = ev[\freq].asArray.maxItem;
		ev[\mode].asMode.cps(top) * rrand(7.0, 11.0)
	});
	~excAtk = Pwhite(2.5, 4.5, inf);
	~excDcy = Pwhite(8.0, 11.0, inf);
	~fbamp = 0.998;
	~pan = Pfunc({ |ev|
		var n = ev[\freq].asArray.size;
		if(n <= 1) { 0 } {
			Array.series(n, -1, 2 / (n-1)).scramble
		}
	});
	~amp = 1;
	~dur = 4;
	~length = 16 * Ptempo();

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\freq),
			\ffreq, BPStream(\ffreq),
			\dur, BPStream(\dur),
			\length, BPStream(\length),
			\excAtk, BPStream(\excAtk),
			\excDcy, BPStream(\excDcy),
			\fbamp, BPStream(\fbamp),
			\pan, BPStream(\pan),
			\amp, BPStream(\amp),
		)
	};
	~addNotification = {
		~recvNotify = NotificationCenter.register(BP(~bp), \accent, ~collIndex, e {
			BP(~collIndex).triggerOneEvent(0);
		});
	};
	~removeNotification = { ~recvNotify.remove };
} => PR(\sdSwells);
)

BP(\sdSwells).free;
PR(\sdSwells) => BP(\sdSwells);
VC(\onePizz) => BP(\sdSwells);

p = BP(\sdSwells);

p.prepareForPlay;

p.amp = 0.3;

p.amp = Pseries(0.18, 0.02, inf);

p.amp = Pseries.fromEndpoints(0.12, 0.3, 5) ++ Pn(0.5, inf);
p.excAtk = Pn(3, 5) ++ Pn(10, inf);
p.excDcy = Pn(7, 5) ++ Pn(18, inf);

p.amp = 0.5;
p.excAtk = 10;
p.excDcy = 18;

p.triggerOneEvent(0);

p.reset = {
	#[bass, amp, excAtk, excDcy].do { |key|
		~makeStreamForKey.(key)
	};
};


p.mode = \a0;

a = { SinOsc.ar(440, 0, 0.05) ! 2 }.play;
a.free;