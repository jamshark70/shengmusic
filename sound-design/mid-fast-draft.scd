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


// fluttertongue attack

Fact(\triVC) => VC(\tri);

k = VoicerMIDISocket(0, VC(\tri).v);

k.addControl(nil, \ffreq, 2000, \freq);
k.addControl(nil, \rq, 0.7, \myrq);

k.noteOnArgsEvent = ();
k.noteOnArgsPat = Pbind(\holdtime, 1000);

VC(\tri).v.trace;

k.free; VC(\tri).free;


{ VarSaw.ar(440, width: 0.1) }.plot(duration: 0.01); // , server, bounds, minval, maxval )

WrapInstr("osc2.vosc3mapfilt").openFile //.listArgs
WrapInstr("osc2.vosc3").listArgs

// really need to pass the envelope through, so copy/paste time...
WrapInstr("osc2.v3mappanflzg", { |freq, bufbase, numbufs, basefreq, topfreq,
	ffreq = 2000, rq = 1,
	pan, holdtime = 1, env,
	/*flzgtime = 0.15,*/ flzgrate = 12, flzgratio = 0.7, flzgdepth = 0.8|
	var baselog = log2(basefreq),
	freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
		* (numbufs - 1)).clip(0, numbufs - 1.001);
	var flzgtime = NamedControl.kr(\flzgtime, 0.15),
	sig = WrapInstr.wrap("osc2.vosc3", [freq, nil, bufbase, freqmap, env.dereference.value]),
	flzgspeed = Line.kr(flzgrate * flzgratio, flzgrate, flzgtime),
	flzglow = XLine.kr(max(0.001, 1 - flzgdepth), 1, flzgtime),
	flzgamp = VarSaw.ar(flzgspeed, width: 0.2).range(flzglow, 1);
	Line.kr(0, 1, holdtime + 0.15, doneAction: 2);  // zombie killer
	Pan2.ar(RLPF.ar(sig, ffreq, rq), pan, flzgamp);
	}, [
		\freq, #[0, 1000, \linear, 1, 0], #[0, 20, \lin, 1, 0], \freq, \freq,
		\freq, \rq,
		\bipolar, #[0.01, 10], EnvSpec(Env.adsr),
		/*#[0, 0.5],*/ #[1, 30], #[0.25, 4, \exp], nil
]);

WrapInstr("osc2.v3mappanflzg").listArgs;

k.free; VC(\flzg).free;

Fact(\triVC).chuck(VC(\flzg), nil, (
	instrName: "osc2.v3mappanflzg",
	env: `{ Env.adsr(NamedControl.kr(\flzgtime) * 0.4, 0.15, 0.5, 0.3, curve: #[2, -3, -4]) },
	// voicerArgs: { [
	// 	bufbase: `(~oscBufs.first.bufnum),
	// 	numbufs: `(~oscBufs.size),
	// 	basefreq: `(48.midicps),
	// 	topfreq: `(132.midicps),
	// 	env: ~env,
	// 	vsens: `1,
	// 	detune: 1.003
	// ] }
));

VC(\flzg) => VP(0);
VC(\flzg).mapGlobal(\ffreq, nil, 3400, \freq);
VC(\flzg).mapGlobal(\rq, nil, 0.7, \myrq);

k = VoicerMIDISocket(0, VC(\flzg).v);
k.noteOnArgsPat = Pbind(\holdtime, 1000, \flzgtime, 0.8, \flzgrate, 28, \flzgratio, 0.4, \flzgdepth, 0.9);

k.noteOnArgsPat = Pbind(\holdtime, 1000, \gate, 1, \flzgtime, Pkey(\velocity) / 158, \flzgrate, 28, \flzgratio, 0.4, \flzgdepth, 0.9);

VC(\flzg).v.trace;

o.free; o = OSCFunc({ |msg| { s.sendMsg(\n_trace, msg[1]) }.defer(0.1) }, '/n_go', s.addr).oneShot;


// test factory
\makeflzgVC.eval(\flzg);

(type: \voicerNote, voicer: VC(\flzg).v, ffreq: 4000, rq: 0.4, holdtime: 1000, flzgrate: 28, flzgratio: 0.4, flzgdepth: 0.9, flzgtime: 0.8, sustain: 2, root: 2, degree: #[0, 1, 4, 6]).play;


// ok, that's got some more physicality

(
SynthDef(\ffreqpan, { |outbus, time = 1/*, pan1 = 0, pan2 = 0*/|
	var ffreqenv = NamedControl.kr(\fenv, Env(#[4000, 4000], #[1]).asArray.extend(40, 0)),
	ffreq = EnvGen.kr(ffreqenv, 1, 1, 0, time, 2),
	panenv = NamedControl.kr(\panenv, Env.zero(1).asArray.extend(20, 0)),
	pan = EnvGen.kr(panenv, timeScale: time); // Line.kr(pan1, pan2, time);
	Out.kr(outbus, [ffreq, pan]);
}).add
)

(
var e = Env(#[0, 0.3, 1, 0.4, 0], #[0.5, 0.02, 0.08, 1.5] * 3, #[1, 1, 1, -6]), p;

(parent: ProtoEvent(\voicerNoteKrBusLock).parent, voicer: VC(\flzg).v,
ffreq: { ~lock.bus.asMap }, pan: { ("c" ++ (~lock.bus.index+1)).asSymbol }, rq: 0.6, holdtime: 1000,
flzgrate: 28, flzgratio: 0.4, flzgdepth: 0.9, flzgtime: 0.8,
dur: 2, gate: 0.8, length: 1, mode: \d, freq: 35 + #[0, 1, 4, 6], amp: 1,
// env: [Env.perc(0.5, 0.8, curve: #[1, -6])],
env: [e],
numCh: 2,
lpcEv: (
	instrument: \ffreqpan,
	fenv: e.copy.levels_(#[1200, 4000, 12000, 6000, 2000])/*.curves_()*/,
	time: 1,
	// pan1: p = /*rrand(0.7, 1.0) * */ #[-1, 1].choose, pan2: /*rrand(0.7, 1.0) * */ p.sign.neg
	panenv: Env(#[-1, 1].rotate(2.rand), [e.times.sum], \sin)
)
).play;
)

VC(\flzg).env.chorus.synth.run(false);
VC(\flzg).env.chorus.synth.run(true);


// omg it was SO HARD to tune this effect

(
var e = Env(#[0, 0.3, 1, 0.4, 0], #[0.5, 0.02, 0.08, 1.5] * 3, #[1, 1, 1, -6]), p;

(parent: ProtoEvent(\voicerNoteKrBusLock).parent, voicer: VC(\flzg).v,
ffreq: { ~lock.bus.asMap }, pan: { ("c" ++ (~lock.bus.index+1)).asSymbol }, rq: 0.6, holdtime: 1000,
flzgrate: 25, flzgratio: 0.4, flzgdepth: 0.9, flzgtime: 0.7*3,
dur: 2, gate: 0.8, length: 1, mode: \d, freq: 35 + #[0, 1, 4, 6],
// env: [Env.perc(0.5, 0.8, curve: #[1, -6])],
env: [e],
numCh: 2,
lpcEv: (
	instrument: \ffreqpan,
	fenv: e.copy.levels_(#[1200, 4000, 12000, 6000, 2000])/*.curves_()*/,
	time: 1,
	// pan1: p = /*rrand(0.7, 1.0) * */ #[-1, 1].choose, pan2: /*rrand(0.7, 1.0) * */ p.sign.neg
	panenv: Env(p = #[-1, 1].rotate(2.rand).insert(1, 0), [1.5, e.times.sum - 1.5], #[-4, 4] * p[0].sign).postcs
)
).play;

// { VC(\flzg).v.playingNodes.choose.trace }.defer(0.5);
)

ProtoEvent.composite(#[voicerNote, voicerNoteKrBusLock, dummy]) => ProtoEvent(\flzg);

(Pwhite(2, 5, inf) * Ptuple([0.5, Pwhite(0.7, 1.6, inf)], inf)) => MacRh(\flzg);

(
BP(\flz).free;
Func(\newCh).value(\flz, \arpegMultiVoicer, \macroRh, MBM(0)[\pzch], nil, MacRh(\flzg).v, \blockFollow, \block, nil, \d);
)
;

p = BP(\flz);

MacRh(\flzg) => p;
VC(\flzg) => p;

p.child.event.eventKey = \voicerNoteKrBusLock;

(
p.child.argPairs = Pbind(
	\ffreq, { ~lock.bus.asMap },
	\pan, { ("c" ++ (~lock.bus.index+1)).asSymbol },
	\rq, 0.6,
	\holdtime, 1000,
	\env, Pfunc({ |ev|
		// above envelope, but times array is normalizeSum'med
		[Env(#[0, 0.3, 1, 0.4, 0], #[0.23809523809524, 0.0095238095238095, 0.038095238095238, 0.71428571428571] * ev[\length], #[1, 1, 1, -6])]
	}),
	\flzgrate, 25, \flzgratio, 0.4, \flzgdepth, 0.9,
	\flzgtime, Pfunc({ |ev| 1.4 * ev[\env][0].times[0] }),
	\gate, 0.8,
	\numCh, 2,
	\lpcEv, Pbind(
		\instrument, \ffreqpan,
		\env, Pfunc({ |ev| [ev[\env][0].copy.levels_(#[1200, 4000, 12000, 6000, 2000])/*.curves_()*/] }),
		\time, 1,
		// pan1: p = /*rrand(0.7, 1.0) * */ #[-1, 1].choose, pan2: /*rrand(0.7, 1.0) * */ p.sign.neg
		\panenv, Pfunc({ |ev|
			var p, e = ev[\env][0];
			[Env(p = #[-1, 1].rotate(2.rand).insert(1, 0), [e.times[0], e.times.sum - e.times[0]], #[-4, 4] * p[0].sign)]
		})
	)
);
)

p.prepareForPlay;

p.reset;
p.triggerOneEvent(0);

p.topNote = PR(\patternTop).copy.make {
	~mode = \d;
	~deg = Pwhite(38, 50, inf);
};

p.topNote.deg = Pwhite(40, 55, inf);

p.child.fitFunc = \chordFitInt;

VC(\flzg).nodes.do(_.steal = false);

BP(\flz).free;
Fact(\flzgBP) => BP(\flz);

0 => BP(\flz);
VC(\flzg) => BP(\flz);

p = BP(\flz);

/* HOW IS THIS POSSIBLE? All the same node?

made 1050: Bus(control, 17, 2, localhost)
added node 1050: Synth("-qjq3t1035" : 16602)
added node 1050: Synth("-qjq3t1035" : 16602)
added node 1050: Synth("-qjq3t1035" : 16602)
added node 1050: Synth("-qjq3t1035" : 16602)
added node 1050: Synth("-qjq3t1035" : 16602)
added node 1050: Synth("-qjq3t1035" : 16602)
added node 1050: Synth("-qjq3t1035" : 16602)
added node 1050: Synth("-qjq3t1035" : 16602)

prGetNodes collects results of "stealer" method
preferEarly uses nonplaying
if no nodes are available, nonplaying returns [theEarliestNode]
in an event, nodes are reserved but not triggered
hence lastTrigger doesn't change and the same node is always earliest
maybe set trigger time when the node is reserved?
*/


// fast stuff: need a bunch of sounds
// some very pitched, some quasi- or un-pitched
// FM can run that gamut

// added 'pan' in the procs file
WrapInstr("osc2.fm_monster", { arg freq, gate, car_env, mod_env, mod_lev,
	freqInitRatio = 1, mod_ratio1 = 1, mod_ratio2 = 1, slideTime = 1,
	detune, car_detune,
	car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale;
	var sig, mod, mod_ratio, car_amp, mod_amp;
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
	* EnvGen.kr(mod_env.dereference.value(slideTime), gate);
	freq = freq * XLine.kr(max(0.001, freqInitRatio), 1.0, slideTime);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod_ratio = Line.kr(mod_ratio1, mod_ratio2, slideTime);
	mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];
	sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
	* EnvGen.kr(car_env.dereference.value(slideTime), gate, doneAction:2)
	}, [
		\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential],
		#[0.05, 20, \exp], [1, 12, \linear, 0, 1], [1, 12, \linear, 0, 1], #[0, 2],
		[-5, 5, \linear, 0, 0], \mydetune,
		\mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp]
]);

WrapInstr("osc2.fm_monster").listArgs;

~bufs.free;
~bufs = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
	var amps;
	i = i + 3;
	amps = Array.fill(i+1, 0).put(0, 1).put(i, 1);
	Pfin(i div: 2, Pshuf((1 .. i-2), 1)).do { |randIndex|
		amps[randIndex] = rrand(0.2, 0.7);
	};
	buf.sine1Msg(amps.debug)
}); ""

// next: variable envelopes
v = Voicer(15, WrapInstr("osc2.fm_monster"), [basefreq: `440, car_vs: `0.8, mod_vs: `0.8, car_env: `{ NamedControl.kr(\car_env, (0 ! 40).overWrite(Env.adsr.asArray)) }, mod_env: `{ NamedControl.kr(\mod_env, (0 ! 40).overWrite(Env.adsr.asArray)) }], target: m);
v => VP(0);

k.free;

k = VoicerMIDISocket(0, v);

v.mapGlobal(\mod_lev, nil, 3, #[1, 50, \exp]);

v.globalControls[\mod_lev].spec = #[1, 150, \exp];

k.mapGlobal(\mod_ratio1, 1, #[0.5, 12.5]);
k.mapGlobal(\mod_ratio2, 1, #[1, 12, \lin, 1]);

VP(0).v.controlProxies.do { |gcp| gcp.midiControl = nil };

v.unmapGlobal(\mod_lev);

k.noteOnArgsPat = Pbind(
	\car_buf, Prand(~bufs, inf),
	\mod_buf, Prand(~bufs, inf),
	\car_detune, 1.006,
	\car_env, [Env.adsr(0.01, 0.8, 0.1, 0.2)],
	\mod_env, [Env.adsr(0.01, 0.8, 0.6, 0.2)],
	// \mod_ratio2, Pwhite(2, 7, inf),
	\mod_ratio2, Pwhite(2, 7, inf) * (Pwhite(1.08, 1.26, inf) ** Prand(#[-1, 1], inf)),
	\mod_ratio1, Pkey(\mod_ratio2), // * (Pwhite(1.08, 1.26, inf) ** Prand(#[-1, 1], inf)),
	\slideTime, Pwhite(0.07, 0.34, inf) //,
	// \mod_lev, Pswitch1([
	// 	Pwhite(3.0, 11.0, inf),
	// 	Pwhite(19.0, 42.0, inf)
	// ], Pwrand(#[0, 1], #[0.9, 0.1] ,inf)).trace
);


k.free;
VC(\fm).free;
Fact(\madfmVC) => VC(\fm);

(type: \voicerNote, voicer: VC(\fm).v, freq: 440, sustain: 2, mod_ratio1: 3, mod_ratio2: 3, car_detune: 1.003, car_buf: VC(\fm).env.bufs.choose, mod_buf: VC(\fm).env.bufs.choose, car_env: [Env.adsr(0.01, 0.8, 0.1, 0.2)], mod_env: [Env.adsr(0.01, 0.8, 0.6, 0.2)]).play;


// can I coax a splashy sound out of it?
// not bad, maybe too obviously synthy
// would like harder attack

(type: \voicerNote, voicer: VC(\fm).v, freq: 440, sustain: 1, mod_ratio1: 3, mod_ratio2: 3, car_detune: 1.003, car_buf: VC(\fm).env.bufs[2], mod_buf: VC(\fm).env.bufs.last, car_env: [Env(#[0, 1, 0.5, 0, 0], #[0.01, 0.14, 8.0, 0.15], -4, releaseNode: 3)], mod_env: [Env(#[0, 1, 0.4, 0.1, 0], #[0.01, 0.1, 3.0, 10.0], -4)], mod_lev: 5).play;

k = VoicerMIDISocket(0, VC(\fm).v);

b = Buffer.alloc(s, 2048, 1, completionMessage: { |buf| buf.sine1Msg(#[1]) });

VC(\fm).v.mapGlobal(\mod_lev, nil, 9, #[2, 40, \exp]);
VC(\fm).v.mapGlobal(\mod_env_time, nil, 1, #[0.1, 10, \exp]);
VC(\fm).v.mapGlobal(\mod_ratio2, nil, 3, #[1, 12, \lin, 0.05]);
VC(\fm).v.mapGlobal(\keyscale, nil, 0.001, #[0.001, 1, \exp]);

VC(\fm).globalControls[\keyscale].spec = #[0.1, 20, \exp];

VC(\fm).trace

VC(\fm).v.unmapGlobal(\mod_ratio2);
VC(\fm).v.unmapGlobal(\keyscale);

q = PbindProxy(\mod_ratio2, 3, \mod_ratio1, Pwhite(3.01, 3.07, inf));
k.noteOnArgsPat = q <> (slideTime: 2.5, car_detune: 1.006, car_buf: b /* VC(\fm).env.bufs[2] */, mod_buf: VC(\fm).env.bufs.last, car_env: [Env(#[0, 1, 0.5, 0, 0], #[0.01, 0.14, 8.0, 0.15], -4, releaseNode: 3)], mod_env: [Env(#[0, 1, 0.25, 0.1, 0], #[0.01, 0.3, 1.0, 10.0], -4)], mod_lev: 9);

q.set(\mod_ratio1, Pwhite(4, 4.5, inf));

q.set(\mod_ratio1, Pkey(\mod_ratio2) + Pkey(\velocity).linlin(30, 127, 0.07, 0.2));

q.set(\mod_ratio2, VC(\fm).globalControls[\mod_ratio2].asMap, \mod_ratio1, VC(\fm).globalControls[\mod_ratio2].asMap);

q.set(\mod_ratio2, Pwhite(2, 6, inf) + (Pwhite(0.12, 0.3, inf) * Prand(#[-1, 1], inf)), \mod_ratio1, Pkey(\mod_ratio2));

q.set(\mod_ratio2, 3.8);

q.set(\mod_buf, Prand(VC(\fm).env.bufs, inf));

o.free; o = OSCFunc({ |msg| { s.sendMsg(\n_trace, msg[1]) }.defer(0.1) }, '/n_go', s.addr).oneShot;


// how's the above for fast, low notes?

(VC(\fmlow).free;
Fact(\madfmVC).chuck(VC(\fmlow), nil, (
	makeBufs: {
		Fact(\madfmVC).v[\makeBufs].value;  // I want the usual bufs
		~sineBuf = Buffer.alloc(s, 2048, 1, { |buf| buf.sine1Msg(#[1]) });
	},
	defaultCarrierBuf: { ~sineBuf.bufnum },  // and another buf
	free: Fact(\madfmVC).v[\free].addFunc({ ~sineBuf.free })  // make a functionlist
)));

(PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);

	~mode = Pxrand(Mode.keys.select { |key| key.asString.last == $0 }.asArray, inf);
	~seed = Pwhite(0, 0x7FFFFFFF, inf);
	~topnote = \patRejectLastN.eval(
		Pseries({ rrand(24, 30) }, Pwhite(1, 3, inf) * Prand(#[-1, 1], inf), inf).fold(24, 30),
		1
	);
	~car_env = [Env(#[0, 1, 0.5, 0, 0], #[0.01, 0.14, 8.0, 0.15], -4, releaseNode: 3)];
	~mod_env = [Env(#[0, 1, 0.25, 0.1, 0], #[0.01, 0.3, 1.0, 10.0], -4)];
	~gate = 0.5;

	~freq = Pseed(
		Pfin({ rrand(3, 6) }, Pkey(\seed)),
		Pwhile1(
			{ |in, next| next >= 18 },
			Pseries(
				{ |inevent| inevent[\topnote] },
				Pwrand(#[-1, -2, -3], #[0.5, 0.4, 0.1], { rrand(4, 8) })
			)
		)
	);
	~dur = 0.25;
	~car_detune = 1.006;
	~mod_buf = Prand(VC(\fmlow).env.bufs, inf);
	~mod_lev = Pif(Pdiff(Pkey(\freq)) > 0, Pwhite(25.0, 40.0, inf), Pwhite(8.0, 19.0, inf));
	~legato = Pif(Pdiff(Pkey(\freq)) > 0, Pwhite(2.5, 10.0, inf), 0.8);
	~length = Pkey(\dur) * Pkey(\legato);

	~outerPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\seed, BPStream(\seed),
			\topnote, BPStream(\topnote),
			\car_env, BPStream(\car_env),
			\mod_env, BPStream(\mod_env),
			\gate, BPStream(\gate)
		)
	};

	~innerPattern = {
		Pbind(
			\freq, Plazy({ ~freq }),
			\dur, BPStream(\dur),
			\car_detune, BPStream(\car_detune),
			\mod_buf, BPStream(\mod_buf),
			\mod_lev, BPStream(\mod_lev),
			\legato, BPStream(\legato),
			\length, BPStream(\length)
		)
	};

	~asPattern = {
		PR(\psetp2).copy.prep(~outerPattern.(), ~innerPattern.(), currentEnvironment)
		.outerOverridesInner_(false)
	};
} => PR(\fastlow));

BP(\fastlow).free;
PR(\fastlow) => BP(\fastlow);
BP(\fastlow) => VC(\fmlow);

p = BP(\fastlow);
1 => p;

p.car_detune = 0.15.midiratio;

// this snip assumes global controls above and 'b' (single sine partial)
p = PbindProxy(
	\type, \voicerNote,
	\voicer, VC(\fmlow).v,
	\midinote, Pseed(Pstutter(Pwhite(1, 3, inf), Pwhite(0, 0x7FFFFFFF, inf)),
		Pseries({ rrand(48, 55) }, Pwrand(#[-1, -2, -3, -4], #[0.2, 0.4, 0.3, 0.1], { rrand(4, 8) }))),
	\dur, 0.15,
	\car_detune, 1.006,
	// \car_buf, b /* VC(\fm).env.bufs[2] */,
	\mod_buf, Prand(VC(\fmlow).env.bufs, inf),
	\car_env, [Env(#[0, 1, 0.5, 0, 0], #[0.01, 0.14, 8.0, 0.15], -4, releaseNode: 3)],
	\mod_env, [Env(#[0, 1, 0.25, 0.1, 0], #[0.01, 0.3, 1.0, 10.0], -4)]
);

q = p.play;
q.stop;

VC(\fm).unmapGlobal(\mod_lev);
p.set(\mod_lev, Pif(Pdiff(Pkey(\midinote)) > 0, Pwhite(25.0, 40.0, inf), Pwhite(8.0, 19.0, inf)));

p.set(\legato, Pif(Pdiff(Pkey(\midinote)) > 0, Pwhite(2.5, 10.0, inf), 0.8));

VC(\fm).playingNodes;

VC(\fm).unmapGlobal(\mod_env_time);
p.set(\mod_env_time, Pif(Pdiff(Pkey(\midinote)) > 0, Pwhite(2.0, 4.0, inf), Pwhite(0.5, 0.8, inf)));

// don't care for this
p.set(\mod_ratio2, Pwhite(1, 3, inf) * 2 + 1 + (Pwhite(0.12, 0.3, inf) * Prand(#[-1, 1], inf)), \mod_ratio1, Pkey(\mod_ratio2));

p.removeAt(\mod_ratio1); p.removeAt(\mod_ratio2);

p.set(\mod_ratio2, nil);


// modal?
(o = PbindProxy(
	\mode, Pxrand(Mode.keys.select { |key| key.asString.last == $0 }.asArray, inf),
	\seed, Pwhite(0, 0x7FFFFFFF, inf),
	\topnote, \patRejectLastN.eval(
		Pseries({ rrand(24, 30) }, Pwhite(1, 3, inf) * Prand(#[-1, 1], inf), inf).fold(24, 30),
		1
	),
	\car_env, [Env(#[0, 1, 0.5, 0, 0], #[0.01, 0.14, 8.0, 0.15], -4, releaseNode: 3)],
	\mod_env, [Env(#[0, 1, 0.25, 0.1, 0], #[0.01, 0.3, 1.0, 10.0], -4)],
	\gate, 0.5
);

p = PbindProxy(
	// \type, \voicerNote,
	\voicer, VC(\fmlow).v,
	\freq, Pseed(
		Pfin({ rrand(3, 6) }, Pkey(\seed)),
		Pwhile1(
			{ |in, next| next >= 18 },
			Pseries(
				{ |inevent| inevent[\topnote] },
				Pwrand(#[-1, -2, -3], #[0.5, 0.4, 0.1], { rrand(4, 8) })
			)
		)
	),
	// Pseed(Pfin({ rrand(3, 6) }, Pkey(\seed)),
	// Pseries({ rrand(29, 36) }, Pwrand(#[-1, -2, -3, -4], #[0.2, 0.4, 0.3, 0.1], { rrand(4, 8) }))),
	\dur, 0.25,
	\car_detune, 1.006,
	\mod_buf, Prand(VC(\fmlow).env.bufs, inf),
	\mod_lev, Pif(Pdiff(Pkey(\freq)) > 0, Pwhite(25.0, 40.0, inf), Pwhite(8.0, 19.0, inf)),
	\legato, Pif(Pdiff(Pkey(\freq)) > 0, Pwhite(2.5, 10.0, inf), 0.8),
	\length, Pkey(\dur) * Pkey(\legato)
);

a = PR(\psetp2).copy.prep(o, p);
a.outerOverridesInner = false;
);

q = a.asPattern.play(protoEvent: ProtoEvent(\voicerNote).copy);
q.stop;

o.set(\topnote, o[\topnote].source.pattern.fold(24, 30).trace(prefix: "top: "));

o.set(\topnote, \patRejectLastN.eval(Pseries({ rrand(24, 30) }, Pwhite(1, 3, inf) * Prand(#[-1, 1], inf), inf).fold(24, 30), 1));

o[\topnote].source.asStream.nextN(15);

\patRejectLastN.eval(Pseries({ rrand(24, 30) }, Pwhite(1, 3, inf) * Prand(#[-1, 1], inf), inf).fold(24, 30), 1).asStream.nextN(15)

\d0.asMode.cps((18..21))

(p.set(\freq, Pseed(
	Pfin({ rrand(3, 6) }, Pkey(\seed)),
	Pwhile1(
		{ |in, next| next >= 18 },
		Pseries(
			.asStream
			Pwrand(#[-1, -2, -3], #[0.5, 0.4, 0.1], { rrand(4, 8) })
		)
	)
)));


q.isPlaying

// smooth melody
(
SynthDef(\noiselet2, { |freq = 440, noisefreq = 60, beats = 0.5, noisebuf,
	filtAttack = 0.02, filtDecay = 0.3,
	attack = 1, decay = 0, susLevel = 1, release = 1, gate = 1,
	// workaround: MonoPortaVoicer can't override freqlag per note
	// so, call it something else
	pan = 0, amp = 0.1, out = 0, freqLag = 0, freqratio = 1.003|
	var sig = COsc.ar(noisebuf, noisefreq, beats, amp),
	eg = EnvGen.kr(Env.adsr(attack, decay, susLevel, release), gate, doneAction: 2);
	sig = Formlet.ar(sig, Lag.kr(freq, freqLag) * [1, freqratio], filtAttack, filtDecay).sum;
	sig = Limiter.ar(sig, 1, 0.006);  // harmonics can spike the level
	Out.ar(out, Pan2.ar(sig, pan, eg));
}).add;
)

k.free; VC(\nletmel).free;

Fact(\noiseletVC).chuck(VC(\nletmel), nil, (
	voicerClass: MonoPortaVoicer,
	initLevel: -3.2.dbamp,
	rvbLevel: -12.dbamp,
	numVoices: 1,
	defname: \noiselet2,
	gcSpecs: [
		\filtAttack -> #[0.01, 0.28, \exp, 0, 0.19],
		\filtDecay -> #[0.1, 0.5, \exp, 0, 0.4],
		\noisefreq -> #[30, 120, \exp, 0, 60]
	],
	customize: { |voicer|
		voicer.portaTime = 0.2;
		voicer.setArgDefaults([attack: 0.15, decay: 0.1, susLevel: 0.6, release: 0.2, freqratio: 0.5015]);
	}
));

VC(\nletmel) => VP(0);

v = VC(\nletmel).v;

v.globalControls[\noisefreq].watch;
v.globalControls[\noisefreq].stopWatching;

k = VoicerMIDISocket(0, v);

v.setArgDefaults([attack: 0.15, decay: 0.1, susLevel: 0.6, release: 0.2]);

v.globalControls[\filtAttack].spec_(#[0.01, 0.28, \exp]);

v.mapGlobal(\filtDecay, nil, 0.3, #[0.1, 0.5, \exp]);

VC(\nletmel).env.target.postSettings;


(
var t = 1/3, d, sl = 0.05, ns = -0.05, g = 0.11 / 2;
MIDIRecBuf(\shMel,
	[
		[	79, 81, 79, 81, 79,// #[],
			79, 81, 78, 79, 81, 83, 81, // #[],
			/*#[],*/ 88, 81,  83, 81, 78, 79, 81,  71, 88,  85, 86, 79,
			79, 81, 79, // #[],
			/*#[],*/ 79, 81, 79, 83, 81, 79, 78, 76, 74, 76, 78, 71, 74, 76,  74, 78, 76
		],
		d = [1, 1.5, 0.5, 1.5, 0.5, // + 3,
			1, 1, 0.5, 0.5, 0.5, 1, 0.5, // + 1 + 0.5,
			g, 2-g,  0.5 + (t*2), t, t, t, t+1, g, 1.5-g, 1, 0.5, 1.5,
			0.5, 2, 0.75, // + 2.25 + 0.5,
			0.5, 1+t, t, t, 1 + (t*2), t, t, t, t, 0.25, 0.25, 0.25, 0.25, 2, g, g, 2-(2*g)
		] * 2,
		(d + [sl, ns, sl, sl, 0,
			sl, ns, sl, sl, ns, sl, 0,
			sl, ns, sl, ns, sl, sl, ns, sl, ns, sl, ns, ns - 0.5,
			sl, sl, 0,
			sl, ns, sl, sl, sl, sl, sl, sl, ns, sl, sl, sl, sl, ns, sl, sl, ns
		]).putEach(#[4, 11, 25], #[0.7, 0.7, 0.9]),
		0.5
	].asNotes, (
		mode: \d, type: \mel, splitFunc: \userSplit, segFunc: \noSplit,
		phrSplits: #[5, 7, 10, 3, 17]
	)
).parse(0.19, 0.19) => MBM(0);
)

MBM(0)[\shMelb].dumpSeq;

Event.default[\eventTypes].keys.select { |key| key.asString.containsi("voicer") };

b = MBM(0)[\shMelb];

c = b.notes.select(_.isKindOf(SequenceItem));

c[0].inspect;

[c[0].graceNotes[0].tryPerform(\args)].tryPerform(\flatten, 1)

b.notes.do { |note|
	note.args = #[gate, 0.5, freqLag, 0.2];
	if(note.isKindOf(SequenceItem)) {
		note.graceNotes.do { |gn| gn.args = #[gate, 0.5, freqLag, 0.06] }
	};
}; ""

c[0].asPattern.asStream.all.do(_.postcs); ""

Pdrop(14, Pseq(MBM(0)[\shMelb].notes, 1)).asStream.nextN(5).do(_.postcs); ""

// ok now I have really f*cking had it with these arguments getting lost
// FINE. F*CKING FINE. I'll regenerate them in the pattern.

(p = Pbind(
	// \type, \voicerNote,
	\voicer, v,
	\midi, true,
	// \clock, TempoClock.default,
	// \debug, true,
	\note, Pdrop(14, Pseq(MBM(0)[\shMelb].notes, 1)),
	// damn it's stupid I have to do this
	\freqLag, Pfunc({ |ev|
		if(ev[\note].dur < 0.2) { 0.06 } { 0.2 }
	}).trace
	// \freqLag, Pfunc({ |ev|
	// 	var note = ev[\note], argi;
	// 	if(note.postcs.args.debug("args").size > 0) {
	// 		argi = note.args.indexOf(\freqLag).debug("argi");
	// 		if(argi.notNil) { note.args[argi+1] } { 0.06 }
	// 	} { 0.2 };
	// }).trace
).play(protoEvent: ProtoEvent(\voicerNote)));

p.stop;


// so... having done that, I can work on melody adaptations

BP(\m).free;
PR(\aiMel) => BP(\m);

p = BP(\m);
p => VC(\nletmel);
0 => p;

MBM(0)[\shMelb] => p;
MBM(0)[\shMelb] =>.adapt p;

Prand([\absSplice, \intSplice, \delete], inf).trace(prefix: "adaptfunc: ") =>.adapt p;

Pwrand([\absSplice, \intSplice, \delete], #[0.2, 0.5, 0.3], inf).trace(prefix: "adaptfunc: ") =>.adapt p;

p.eugTest = \dummyEugTest;

p.listVars
p.mel.listVars

p.listMethods
p[\bindPattern].postcs

p.mel[\makePhrPattern].postcs;
p.mel[\makePhrPattern] = { |passIn|
	passIn = passIn ?? { ~passInValue };
	~phrPattern = Pxrand(~mel, passIn[\repeats] ? inf);
};

p.mel[\makePhrPattern] = { |passIn|
	passIn = passIn ?? { ~passInValue };
	~phrPattern = Pseq(~mel, passIn[\repeats] ? inf);
};

p.args = Pbind(
	\freqLag, Pfunc({ |ev|
		if(ev[\note].notNil and: { ev[\note].dur < 0.2 }) { 0.06 } { 0.2 }
	}),
	\ctranspose, 12
);

(#{ |source, cross|	// absolute splice
	var	s1, s2, newSeg, splice, spl2size, spl2;
	s1 = source.notes;		// not worrying about weighting b/c poor adaptations
	s2 = cross.notes;		// will die after a few generations
	splice = ((s1.size-2).rand + 1).max(1);	// splice coordinates
	spl2size = rrand(3, (s2.size * 0.7).roundUp.asInteger);
	spl2 = (s2.size - spl2size).rand;
	newSeg = s1.copyRange(0, splice-1);
	newSeg = newSeg ++ s2.copyRange(spl2, spl2 + spl2size - 1);
	"\n\nabssplice result".postln;
	(newSeg ++ s1.copyRange(splice, s1.size - 1)).do(_.postcs);
} => Func(\absSplice);

#{ |source, cross|
	// diatonic splice -- take part of s1 as is, insert intervals from part of s2,
	// and finish with s1
	var s1, s2, temp, s1ang, splice, current, new, spl2, spl2size;
	splice = ((source.notes.size-2).rand + 1).max(1);
	spl2size = rrand(3, (cross.notes.size * 0.7).round.asInteger);
	spl2 = (cross.notes.size - spl2size).rand.max(1);
	(spl2size + spl2 >= cross.notes.size).if({ spl2size = cross.notes.size - spl2 });

	(spl2size >= 2).if({
		new = source.notes.copyRange(0, splice-1);
		// last diatonically mapped note + first spliced interval - s2 dia map note
		current = (source.notes[splice-1] + cross.intervals[spl2 - 1] -
			cross.notes[spl2].freq).asFloat;
		new = new ++ (cross.notes.copyRange(spl2, spl2 + spl2size - 1) + current);
		// last note copied + transposition + next interval from source - next note (source)
		// algebraically simplifies to last note(s2) + transposition - last note (source)
		current = cross.notes[spl2 + spl2size - 1].freq + current - source.notes[splice-1].freq;
		"\n\nintsplice result".postln;
		(new ++ (source.notes.copyRange(splice, source.notes.size - 1) + current)).do(_.postcs);
	});
} => Func(\intSplice));

p.clearAdapt; MBM(0)[\shMelb] =>.adapt p;
p.macro = Pwhite(3, 6, inf) * 0.5;

p.reset;
p.play;
p.stop;

p.listMethods

p.dumpSegments;



p.event[\debug] = false;

p =>.adapt

// multiple voicer problem
(
PR(\arpeg1).clone {
	~initVoicerArgs = {
		~voicerArgs = Proto.new.putAction_(e { |key, value, me|
			~voicerArgStreams ?? { ~voicerArgStreams = IdentityDictionary.new };
			~voicerArgStreams.put(key, value.asStream);
		});
		currentEnvironment
	};
	~voicerArgs_ = { |envir|
		~voicerArgs.env.keys.do { |key| ~voicerArgs.removeAt(key) };
		~voicerArgStreams = IdentityDictionary.new;
		envir.keysValuesDo { |key, value|
			~voicerArgs[key] = value;
			~voicerArgStreams[key] = value.asStream;
		};
		currentEnvironment
	};
	~superAsPattern = ~asPattern;
	~asPattern = { |inEvent|
		~superAsPattern.(inEvent).collect { |ev|
			var extraArgs;
			if(ev[\vckey].notNil and: { VC.exists(ev[\vckey]) }) {
				ev[\voicer] = VC(ev[\vckey]).v;
				if(~voicerArgStreams[ev[\vckey]].notNil) {
					ev = ~voicerArgStreams[ev[\vckey]].next(ev);
				} {
					ev = VC(ev[\vckey]).argStreams.next(ev);
				};
			};
			ev
		};
	};
} => PR(\arpegMultiVoicer);
)

BP(\t).free;
Func('newCh').value(\t, \arpegMultiVoicer, \macroRh, MBM(0)[\pzch], nil, Pwhite(3, 6, inf), '16th', \xrand, nil, \d);

Fact(\triVC) => VC(\tri);
Fact(\madfmVC) => VC(\fm);

p = BP(\t);

p.child.argPairs = Pbind(\vckey, Prand(#[tri, fm], inf).trace(prefix: "vckey: "));
p.child.initVoicerArgs;
0 => p;

(
p.child.voicerArgs.put(
	\tri, Pbind(
		\holdtime, Pkey(\length) + 1,
		\ffreq, Pexprand(1500, 8000, inf),
		\rq, Pwhite(0.1, 0.6, inf)
	)
);
p.child.voicerArgs.put(
	\fm, Pbind(
		\car_buf, Prand(VC(\fm).env.bufs, inf),
		\mod_buf, Prand(VC(\fm).env.bufs, inf),
		\car_detune, 1.006,
		\car_env, [Env.adsr(0.01, 0.8, 0.1, 0.2)],
		\mod_env, [Env.adsr(0.01, 0.8, 0.6, 0.2)],
		\mod_ratio2, Pwhite(2, 7, inf) * (Pwhite(1.08, 1.26, inf) ** Prand(#[-1, 1], inf)),
		\mod_ratio1, Pkey(\mod_ratio2), // * (Pwhite(1.08, 1.26, inf) ** Prand(#[-1, 1], inf)),
		\slideTime, Pwhite(0.07, 0.34, inf),
	)
);
)

p.child.voicerArgStreams.dump;

p.child.voicerArgs.listVars
p.child.voicerArgStreams;



// oscillating notes
// oscillate not only notes, but chords


VC(\oscil).free;
Fact(\triVC).chuck(VC(\oscil), nil, (
	env: Env(#[0, 1, 0.4, 0.05, 0], #[0.07, 0.12, 3, 0.12], #[-4, -4, -6.5, -4], releaseNode: 3),
	customize: {
		~target.doWhenReady { ~target.newPostSend(~rvbmc, -7.5.dbamp) };
	}
));

Fact(\oscilBP) => BP(\oscil);
p = BP(\oscil);
VC(\oscil) => p;

p => MT(1);

p.child.notePct = GenericGlobalControl(\notePct, nil, 0.2, #[0.1, 1.0]);
p.useGui = { |vpIndex| ~child.notePct => VP(vpIndex) };
p[\userfree] = { ~child.notePct.free };

p.event


p.event.collIndex = p.collIndex;

p.prepareForPlay;

p.triggerOneEvent(0);

p.child.fitFunc = \chordFitNotes;
p.child.fitFunc = \chordFitInt;


Pwhite(3, 6, inf) * 0.5 =>.macro p;
\hold16th =>.micro p;

Pseq([Pwhite(3, 6, { rrand(2, 6) }) * 0.5, Pn(1, { 2.rand + 1 })], inf) =>.macro p;
Pif(Pkey(\delta) <= 1, \hold6tuplet, \hold16th) =>.micro p;


'16th' =>.micro p;

\highLow =>.arpeg p;
\up =>.arpeg p;
\interleave =>.arpeg p;


VC(\oscil).v.mapGlobal(\ffreq, nil, 3000, \freq);
VC(\oscil).v.mapGlobal(\rq, nil, 1, \myrq);

VC(\oscil).v.unmapGlobal(\ffreq);
VC(\oscil).v.unmapGlobal(\rq);

p.child.argPairs[1] = Ppatlace([Pexprand(3000, 9000, inf), Pexprand(800, 2500, inf)], inf);
p.child.argPairs = p.child.argPairs ++ [rq: Pwhite(0.2, 0.8, inf)];



// 16ths with accents

\makeOnePizzVC.eval;
Fact(\triVC) => VC(\tri);
Fact(\madfmVC) => VC(\fm);
\makeflzgVC.eval(\flzg);

VC(#[onePizz, tri, fm, flzg]).do { |vc, i| vc => MCG(i+2) };

VC(\tri).v.set([lpfreq: 3000]);
VC(\flzg).v.set([lpfreq: 2540]);


Fact(\rpt16BP) => BP(\rp);

// Pwrand((1..5), #[0.5, 3, 3, 2, 1.5].normalizeSum, inf) =>.macro BP(\rp);

MacRh(\rpt16syncop) => BP(\rp);

Pseq([
	Pwhite(5, 11, { rrand(5, 11) }) * 0.25,
	Pwrand([
		Pseq(#[0.5, 0.75, 0.75, 1], 1),
		Pseq([0.75, 0.5, 0.75, Prand(#[1, 2], 1)], 1),
		Pseq(#[0.25, 0.25, 0.25, 0.5, 0.75], 1)
	], #[3, 3, 1].normalizeSum, 1)
], inf) =>.macro p;

p.child.gestures.postcs

p.child.argPairs = { |ev|
	[vckey: Plazy({
		~gestures.wchoose(
			if(ev.delta > 1) {
				#[0.33333333333333, 0.16666666666667, 0.33333333333333, 0.16666666666667]
			} {
				#[0.5, 0, 0.5, 0]
			}
		)
	})]
};


p = BP(\rp);

p.rptProb = GenericGlobalControl(\rptProb, nil, 1); p.rptProb => VP(2);

{ |notes, inEvent|
	Pseq([
		notes.asChord,
		Pn(inEvent[\top][\repeatNotes] ?? { 62.mapMode(inEvent[\mode]) }, inf).collect { |notes, ev|
			if(BP(inEvent[\collIndex]).rptProb.coin.not) { ev[\isRest] = true };
			notes
		}
	], 1)
} => ArpegPat(\rpt16prob);



\rpt16prob =>.arpeg p;
\rpt16 =>.arpeg p;

p.child.event

x = ArpegPat(\rpt16prob).asPattern([SequenceNote(#[0, 2, 4], 1, 1, 1)], (top: (repeatNotes: #[0, 1], mode: \d), mode: \d));
x.postcs
y = Pbind(\x, x).asStream;
y.next(());


p.topNote.mode = Pxrand(Mode.keys.asArray.select { |key| key.asString.last == $0 }, inf);

// #1 and #3 repeat the same basic voicer
p.child.argPairs = [vckey: Plazy({ ~gestures.wchoose(#[0.33333333333333, 0.16666666666667, 0.33333333333333, 0.16666666666667]) })];

p.child.argPairs = [vckey: \fm];

x = Pseq(#[fm, tri, onePizz, flzg], inf).asStream;
p.child.argPairs = [vckey: Plazy({ x.next.loop })];

p.child.argPairs = [vckey: Plazy({ ~gestures[2] })];

x = Pseq([0, 1, 2, 3], inf).asStream;

x = Pseq([0, 1, 2], inf).asStream;
p.child.argPairs = [vckey: Plazy({ ~gestures[x.next] })];

// this is also pretty badass
(p.child.argPairs = [
	vckey: Pseq([
		Prand([Pseq(#[flzg, dummy]), \onePizz, \tri, \fm], 1),
		Prand(#[onePizz, tri, fm], inf)
	], 1)
])
;

p.macro = 4;

// level fixing
q.set(\gate, 0.5);

(q.set(\gate, Pfunc({ |ev|
	if(ev[\note].asFloat.size > 2) { 0.4 } { 0.22 }
})))
;

q.set(\mod_lev, Pwhite(5.0, 8.0, inf));

/*
MixerChannel(onePizz, localhost, 2, 2)
 Synthgroup: Group(19)
Effectgroup: Group(20)
Fader synth: Synth("mixers/Mxb2x2" : 21)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.141 (-17 dB)
            pan: 0
Post-fader sends:
	 Send synth: Synth("mixers/Send2" : 34)
	Destination: MixerChannel(rvb, localhost, 2, 2)
	      Level: 0.4 (-7.959 dB)


MixerChannel(tri, localhost, 2, 2)
 Synthgroup: Group(23)
Effectgroup: Group(24)
Fader synth: Synth("mixers/Mxb2x2" : 25)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.75 (-2.499 dB)
            pan: 0
Post-fader sends:
	 Send synth: Synth("mixers/Send2" : 36)
	Destination: MixerChannel(rvb, localhost, 2, 2)
	      Level: 0.371 (-8.624 dB)


MixerChannel(fm, localhost, 2, 2)
 Synthgroup: Group(27)
Effectgroup: Group(28)
Fader synth: Synth("mixers/Mxb2x2" : 29)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.278 (-11.109 dB)
            pan: 0
Post-fader sends:
	 Send synth: Synth("mixers/Send2" : 37)
	Destination: MixerChannel(rvb, localhost, 2, 2)
	      Level: 0.25 (-12.041 dB)


MixerChannel(flzg, localhost, 2, 2)
 Synthgroup: Group(31)
Effectgroup: Group(32)
Fader synth: Synth("mixers/Mxb2x2" : 33)
Destination: MixerChannel(master, localhost, 2, 2)
          level: 0.75 (-2.499 dB)
            pan: 0
Post-fader sends:
	 Send synth: Synth("mixers/Send2" : 38)
	Destination: MixerChannel(rvb, localhost, 2, 2)
	      Level: 0.612 (-4.258 dB)
*/

// development

Pwhite(5, 11) * 0.25 => MacRh(\rpt16);

{ |notes, inEvent|
	Pseq([notes.asChord, Pn(inEvent[\top][\repeatNotes] ?? { 62.mapMode(inEvent[\mode]) }, inf)], 1)
} => ArpegPat(\rpt16);


(
BP(\rp).free;
Func('newCh').value(\rp, /* \arpeg1 */ \arpegMultiVoicer, \macroRh, MBM(0)[\pzch], nil, MacRh(\rpt16), '16th', \rpt16, nil, \d);
1 => BP(\rp);
)

p = BP(\rp);

(p.topNote = PR(\patternTop).copy.make {
	~mode = \d0;
	~deg = Pwhite(35, 42, inf);
	~rpt = Pn(Pwhile1(
		{ |in, next| next.unmapMode(in[\mode]) <= 74 },
		Pseries({ rrand(-6, -2) }, Pwrand(#[1, 2, 3], #[0.5, 0.45, 0.05], inf), { rrand(3, 7) })
	), inf);
	// above may be 0: ensure a unique array
	~repeatNotes = Pfunc({ |ev| 62.mapMode(ev[\mode]) }) + Ptuple([0, BPStream(\rpt)]).collect({ |pair|
		if(pair[0] == pair[1]) { pair[0] } { pair }
	});
	~asPattern = {
		// don't like copy/paste programming
		// but I stupidly don't let you choose a mode per top event
		Pbind(
			\freq, BPStream(\deg),
			\delta, BPStream(\delta),
			\length, BPStream(\length),
			\mode, BPStream(\mode),
			\gate, BPStream(\gate),
			\repeatNotes, BPStream(\repeatNotes)
		)
	};
})
;

// p.topNote.asPattern = {
// 	(Pbind(\repeatNotes, BPStream(\repeatNotes)) <> ~superPattern.())
// };

// maybe a disaster -- um, NO! IT'S COOL!!!
p.topNote.mode = Pxrand(Mode.keys.asArray.select { |key| key.asString.last == $0 }, inf);

p.topNote.mode = \d;

// p.topNote.rpt = Pfunc({ |ev| 62.mapMode(ev[\mode]) }) + Ptuple([
// 	0,
// 	Pwhite(1, 4, inf) * Prand(#[-1, 1], inf)
// ]);

{ |top, topMode, mode, topEvent|
	// crappo workaround b/c this gets called multiple times
	if(topEvent[\origRepeatNotes].isNil) {
		topEvent[\origRepeatNotes] = topEvent[\repeatNotes];
	};
	topEvent[\repeatNotes] = \convertMode.eval(topEvent[\origRepeatNotes], topMode, mode);
	\convertMode.eval(top, topMode, mode)
} => Func(\convertModeRpt);

p.convertTopFunc = \convertModeRpt;

p.child.initVoicerArgs;

p.child.voicerArgs = (
	onePizz: Pbind(
		\ffreq, Pseq([Pexprand(6000, 9400, 1), Pexprand(4000, 7000, inf)]),
		\amp, 4
	),
	tri: Pbind(
		\holdtime, Pkey(\length) + 1,
		\ffreq, Pseq([Pexprand(5000, 9000, 1), Pexprand(1500, 8000, inf)]),
		\rq, Pwhite(0.1, 0.6, inf),
		\gate, Pseq([0.23, Pn(0.18, inf)]),
		\detune, Pwhite(1.002, 1.02, inf)
	),
	fm: Pbind(
		\mod_lev, Pwhite(7.0, 11.0, inf),
		\mod_ratio1, Pwhite(1, 4, inf),
		\mod_ratio2, Pkey(\mod_ratio1),
		\car_detune, Pwhite(1.002, 1.02, inf),
		\car_buf, Prand(VC(\fm).env.bufs, inf),
		\mod_buf, Prand(VC(\fm).env.bufs, inf),
		\mod_env, Plazy({
			[Env.adsr(0.01, rrand(0.07, 0.9), rrand(0.1, 0.3), 1.0)].loop
		}),
		\car_env, [Env.adsr(0.01, 0.7, 0, 0.2)]
	)
);

p.child.event;

(
var e = Env(#[0, 0.3, 1, 0.4, 0], #[0.15, 0.02, 0.08, 0.7], #[1, 1, 1, -6]);
p.child.voicerArgs[\flzg] = Pbind(
	\protoEvent, \voicerNoteKrBusLock, // Pseq([\voicerNoteKrBusLock, Pn(\voicerNote, inf)], 1),
	\ffreq, { ~lock.bus.asMap },
	\rq, 0.6,
	\holdtime, 1000,
	\flzgrate, Pwhite(24.0, 31.0, inf),
	\flzgratio, 0.4,
	\flzgdepth, 0.9,
	\flzgtime, 0.3,
	// \dur, 2,
	// \gate, 0.5,
	// \length, 1,
	// \mode, \d,
	// \freq, 35 + #[0, 1, 4, 6],
	\env, [e],
	\numCh, 1,
	\lpcEv, (instrument: \ctlEnv, connect: 0, env: e.copy.levels_(#[1200, 4000, 12000, 6000, 2000]))
))
;

p.child.voicerArgs[\dummy] = Pbind(\eventKey, \dummy);

p.child.event[\eventKey] = \flzg;
p.reset;

// test flzg
p.child.argPairs = [vckey: Pseq([\flzg, \dummy, Pn(\tri, inf)], 1)];

p.child.gestures = [
	\onePizz.loop, \tri.loop, \fm.loop,
	Pseq([\flzg, \dummy, Pn(\tri, inf)], 1)
];

Plazy({ p.child.gestures.choose.asStream }).asStream.nextN(3)

Symbol.findRespondingMethodFor(\asStream);

p.child.argPairs = [vckey: Plazy({ ~gestures.choose })];

p.child[\argPairs] = [vckey: Pseq(#[onePizz, tri], inf)];

p.child.vckey = Prand(#[onePizz, tri, fm], inf);
// p.child[\vckeyStream]  // good

p.child.vckey = \fm;

p.child.argPairs = [vckey: Plazy({ |inval| ~vckeyStream.next(inval).loop })];

p.child.argPairs = [vckey: \fm];

// this is also pretty badass
p.child.argPairs = [vckey: Prand(#[onePizz, tri, fm], inf)];

p.child.voicerArgs.listVars

p.child.makeChordPattern = { Pxrand(~chords, inf) };
p.child.fitFunc = \chordFitInt;

p.child.fitFunc = \chordFitNotes;

p.child.resetArgsOnChord = true;

Ptuple([0.25, Pseq([Pwhite(0.2, 0.33, 1), Pn(0.08, inf)], 1), 0.5]) => MicRh(\rpt16);

\rpt16 =>.micro p;



// slurred 16th-note sextuplets

Fact(\triVC) => VC(\tri);


{ |notes, inEvent|
	// .collect{} runs in the context of the arpeggiator,
	// so I must keep a reference to the chord object (in which this function runs)
	var curChord = currentEnvironment, topEvent;
	// topnote comes from inEvent -- don't modify inEvent, just a copy
	inEvent = inEvent.copy;
	topEvent = inEvent[\top].copy;
	inEvent[\top] = topEvent;
	Pseries(topEvent[\freq], BP(inEvent[\collIndex]).child.topIntervals, inf).collect { |aTop, inval|
		topEvent[\freq] = aTop + (inval[\xpose] ?? { 0 });
		Func(\chordFitInt).doAction(curChord, inEvent,
			inEvent[\fitnessOverride] ?? { Library.at(\fitFactors) })
		.asChord
	}
} => ArpegPat(\sxt);

{ |notepat, inEvent|
	var sixth = 1/6, count = 0;
	Ptuple([
		sixth,
		Pseq([Pn(inf /*sixth + 0.01*/, inEvent[\length] / sixth - 1), sixth * 0.2], 1),
		Pgeom(rrand(0.35, 0.5), rrand(0.8, 0.92), inf)
	])
} => MicRh(\sxt);

(
BP(\sxt).free;
Func('newCh').value(\sxt, \arpeg1Slurs, \macroRh, MBM(0)[\tripletCh], nil, Pwhite(3, 7, inf) * (1/6), \sxt, \sxt, nil, \d);
1 => BP(\sxt);
)

p = BP(\sxt);
VC(\tri) => p;

Pwhite(1, 3, inf) * 0.5 =>.macro p;

p.topNote = PR(\patternTop).copy.make {
	~deg = Pwhite(32, 40, inf);
	~mode = \d;
};

p.topNote.deg = Pwhite(28, 35, inf);

p.child.topIntervals = Pwrand(#[1, 2, 3], #[0.75, 0.2, 0.05], inf);

p.child.topIntervals = Pwrand(#[-1, -2, -3], #[0.75, 0.2, 0.05], inf).collect { |int, ev|
	ev[\xpose] = 14;
	int
};

p.child.topIntervals = Pwrand(#[1, 2, 3], #[0.75, 0.2, 0.05], inf) * Pstutter(Pwhite(1, 3, inf), Pseq(#[-1, 1], inf, { 2.rand }));

p.child.topIntervals = Prand([
	Pwrand(#[1, 2, 3], #[0.75, 0.2, 0.05], inf),
	Pwrand(#[-1, -2, -3], #[0.75, 0.2, 0.05], inf).collect { |int, ev|
		ev[\xpose] = 14;
		int
	},
	Pwrand(#[1, 2, 3], #[0.75, 0.2, 0.05], inf) * Pstutter(Pwhite(1, 3, inf), Pseq(#[-1, 1], inf, { 2.rand }))
]);

p.child.argPairs = Pbind(
	\pan, Plazy({ |ev|
		var size = ev[\note].asFloat.size;
		if(size > 1) { Array.series(size, -1.0, 2.0 / (size-1)).scramble.loop } { 0.loop }
	})
);

(p.child.argPairs = Pbind(
	\pan, Plazy({ |ev|
		Array.fill(ev[\note].asFloat.size, { 1.0.rand2 }).loop
	}),
	\ffreq, Plazy({ |ev|
		Ptuple(
			Array.fill(ev[\note].asFloat.size, { exprand(1200, 1800) })
			.put(0, Pn(Pgeom(exprand(2500, 5000), rrand(0.7, 0.81), 3), inf))
		)
	})
));



// rhythm patterns for klinks etc.
BP(\cl).free;
PR(\clicks).chuck(BP(\cl), nil, (master: ~master));
// BP(\cl) => MCG(3);
1 => BP(\cl);

p = BP(\cl);

// used in ~postPattern
p.durBase = 0.125;
p.dur = Plazy({ ~durBaseStream.next.loop }) * Pwrand([Pn(1, 2), 2, 4], #[0.1, 0.75, 0.15], inf);
p.waitTime = Pwhite(1.0, 4.0, inf).round(0.25);

p.event.eventKey = \polySynthPlayer;

p.freqTemplate

p.dHarmonicSeries = 50.midicps * (1..9);  // more than 9 introduces aliasing @ 44.1k
p.specs = Plazy({
	var harmonics = ~dHarmonicSeries.copy;
	Pseq([
		Array.fill(3, {
			// trick: removeAt returns the item that was removed, which is what I want
			harmonics.removeAt(round(exprand(0.01, harmonics.size - 0.001) - 0.5).asInteger)
		}),
		Pn([#[62, 69].choose.midicps], inf)
	]).collect { |freqs|
		freqs.collect { |freq|
			[
				(#[1, 2] ++ ~freqTemplate.scramble.keep(3)) * freq,
				~ampTemplate,
				Array.fill(5, { exprand(0.02, 0.2) })
			].flat
		}
	}
});

p.objects[\klinks][\pattern] = Pbind(
	\bufnum, Plazy({ ~klbufnumStream.next.loop }),
	\klAtk, BPStream(\klAtk),
	\klDcy, BPStream(\klDcy),
	\excfreq, Plazy({ ~excfreqStream.next.loop }),
	\specs, Plazy({ ~specs/*Stream.next.loop*/ }),
	\ampFactor, BPStream(\klampFactor)
);

p.objects[\zzip][\pattern] = Pbind(
	\bufnum, Plazy({ ~zzbufnumStream.next.loop }),
	\sustain, BPStream(\sustain),
	\freq, BPStream(\freq),
	\hpfreq, Plazy({ ~hpfreq/*Stream.next.loop*/ }),
	\hprq, Plazy({ ~hprqStream.next.loop }),
	\env, Plazy({ ~envStream.next.loop }),
	\ampFactor, BPStream(\zzampFactor)
);

p.hpfreq = Plazy({
	var baseFreq = (#[62, 69].choose + (12 * rrand(2, 5))).midicps,
	harmonics = baseFreq * 0.5 * (1 .. (40000 / baseFreq).asInteger);
	Pseq([
		if(harmonics.size <= 3) { harmonics } {
			Array.fill(3, {
				// trick: removeAt returns the item that was removed, which is what I want
				harmonics.removeAt(round(exprand(0.01, harmonics.size - 0.001) - 0.5).asInteger)
			})
		},
		Pn(baseFreq, inf)
	])
});

p.hpfreqStream.next(());

p.hpfreq.asStream.next(());

p.reset;
p.override(\synth, Pn(\zzip, 1));
e = p.eventStream.next(p.event.copy);

e.play;

(p.postPattern = {
	var dur = ~phraseDurStream.next;
	Pfindur(dur, Pbind(
		// \amp, Env(#[1.0, 0.6, 0.6, 0.2], [0.1, 0.5, 0.4] * dur, #[-4, 0, -2])
		// .asStream * Pkey(\ampFactor),
		\amp, Pseq([1.0, Env(#[0.86, 0.3], [dur], -7)], 1) * Pkey(\ampFactor),
		\dur, Plazy({ ~dur }), // * Env(#[1, 2], [dur], -1.5),
		\pan, Plazy({ ~panStream.next.loop }),
		\isAccent, Pseq([true, Pn(false, inf)], 1)
	))
})

(
var dur = rrand(25.0, 35.0), ratio = rrand(0.3, 0.7);
p.override(\waitTime, (Pif(
	Ptime() < dur,
	Env(
		rrand(#[2.8, 0.15, 2.8], #[4.0, 0.75, 4.0]),
		[ratio, 1 - ratio] * dur,
		#[-3, 3]
	).postcs
).round(0.25) + Prand(#[0, 0.25], inf)).trace);
)

(
var dur = rrand(9.0, 17.0);
p.override(\waitTime, Pif(
	Ptime() < dur,
	Pwrand(#[0.25, 0.5, 0.75], #[0.1, 0.5, 0.4], inf)
	* Env(
		[1, rrand(6.0, 9.0)],
		[dur],
		2
	).asStream.trunc  // trunc applies to streams, not Envs directly
).trace);
)

p.listVars;

// p.pan = Pwhite(-1.0, 1.0, inf);
// p.phraseDur = Pwhite(3.0, 7.0, inf);

// other parms, see line 343 in drones-and-clicks.scd

// really f'ing hard problem: control polyphony from Pspawner

p[\superPattern] = p[\asPattern];
p[\superPattern] = PR(\clicks)[\asPattern];


p.maxPoly = GenericGlobalControl(\maxPoly, nil, 1, #[1, 20, \lin, 1]);
p.maxPoly => VP(0);
p[\userfree] = { ~maxPoly.free };

p.maxPoly.spec = #[0.05, 20, \exp];



p.simultaneousThreshold = 0.001;
(p.asPattern = {
	var stream = ~superPattern.().asStream;
	Prout({ |inval|
		var simult = IdentitySet.new, accents = IdentitySet.new,
		event, delta, numout,
		cleanup = EventStreamCleanup.new;
		block { |break|
			loop {
				// collect simultaneous events
				while {
					event = stream.next(inval);
					if(event.isNil) { break.(cleanup.exit(inval)) };  // end condition
					if(event[\isAccent] == true) { event };
					event.delta < ~simultaneousThreshold
				} {
					if(event.isRest.not) {
						if(event[\isAccent] == true) {
							accents.add(event.put(\delta, 0))
						} {
							simult.add(event.put(\delta, 0))
						};
					};
				};
				if(simult.isEmpty and: { accents.isEmpty }) {
					inval = event.yield
				} {
					delta = event.delta;
					event[\delta] = 0;
					if(event.isRest.not) {
						if(event[\isAccent] == true) {
							accents.add(event)
						} {
							simult.add(event)
						};
					};
					numout = min(
						simult.size + accents.size,
						~maxPoly.value.trunc + ~maxPoly.value.frac.coin.asInteger
					);
					if(accents.size > 0) { numout = max(1, numout) };
					min(numout, accents.size).do {
						event = accents.choose;
						accents.remove(event);  // "take" should do this but not for Set???????
						inval = event.yield;
					};
					(numout - accents.size).clip(0, simult.size).do {
						event = simult.choose;
						simult.remove(event);
						inval = event.yield;
					};
					simult.clear; accents.clear;
					inval = Event.silent(delta).yield;
				};
			};
		};
	})
})

p.unOverride(\waitTime);
p.override(\waitTime, (Pwhite(2, 8, inf) * 0.25).trace);

p[\postPattern].postcs


// must make this first, to send synthdefs
PR(\clicks).chuck(BP(\cl), nil, (master: ~master));

BP(\gcl).free;
PR(\gridClicks).chuck(BP(\gcl), nil, (master: ~master));
1 => BP(\gcl);

p = BP(\gcl);

p.phraseDur.postcs

p.freqEnv = Env(#[1, 0.3], #[8], 2);

p.latestPhraseDur
p.freqEnv = { Env([1, rrand(-8, -4).midiratio], [~latestPhraseDur], 3) };

p.waitTime = nil;  // stop after last gesture; stopCleanup automatically restores waitTime



// did I do anything with that fmbass? I think no
// VC(\fmb).free;

// MonoPortaVoicer owns 'freqlag' argument name
WrapInstr("osc2.fm1ramp", { |freq, freqRampTime, gate = 1, car_env|
	WrapInstr.wrap("osc2.fm1", [
		Ramp.kr(freq, freqRampTime), gate,
		car_env.dereference.value(gate)
	])
}, [\freq, \unipolar, \unipolar, ObjectSpec(Env.adsr(0.1, 0.2, 0.6, 0.12))]);

(
VC(\qb).free;
Fact(\fmbass).chuck(VC(\qb), nil, (
	// car_env: Env.adsr(0.1, 0.2, 0.6, 0.12),
	car_env: `{ |gate|
		gate = Latch.kr(gate, gate);
		Env.adsr(
			gate.linlin(0, 1, 1, 0.05),
			gate.linlin(0, 1, 1.6, 0.15),
			0.6, 0.8
		)
	},
	instr: "osc2.fm1ramp"
));
)

k.free;
k = VoicerMIDISocket(0, VC(\qb).v);

k.noteOnArgsPat = Pbind(\freqRampTime, Pkey(\velocity).linlin(0, 127, 0.4, 0.1));

s.nodeAllocator.inspect;

VC(\qb).env[\free] = { [~target, ~highEndToRvb, ~cb, ~mb].free };

PeakMonitor(VC(\qb).env.highEndToRvb)

VC(\qb).env.highEndToRvb.inbus
BusDict

VC(\qb).env.highEndToRvb => MCG(2)

VC(\qb).env.highEndToRvb.level = 1;

VC(\qb).env.target.postSettings


// the degree pattern is really terrible
// also, not so many 16ths

(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~bp = \rp;

	~mode = \d;
	~startDegree = \patRejectLastN.eval(
		Pseries({ rrand(21, 28) }, Pwhite(1, 4, inf) * Pseq(#[-1, 1], inf, { 2.rand }), inf).fold(21, 28),
		1
	);
	~degree = Pseries(
		{ |ev| ~startDegreeStream.next(ev) },
		Pstutter(Pwhite(1, 2, inf), Pwhite(1, 4, inf)) * Pseq(#[-1, 1], inf, { 2.rand }),
		inf
	);
	~dur = Pconst({ |ev| ev[\parentDur] }, Pseq([Pwhite(0.3, 1.0, 1), Rest(10000)], 1));
	~dur2 = Pconst(
		{ |ev| ev[\parentDur] },
		Pseq([Pwhite(4, 7, 1) * 0.25, Pwrand(#[0.25, 0.5, 0.75], #[0.05, 0.6, 0.35], inf)], 1)
	);
	~length = Pwhite(0.3, 1.0, inf);
	~length2 = Prout { |ev|
		// - 0.001 -- build in a threshold to avoid FP rounding error
		var stopTime = (thisThread.clock.beats + ev[\parentDur]) - 0.001;
		while {
			(thisThread.beats + ev.delta) < stopTime
		} {
			ev = (ev[\dur] * 1.01).yield;
		};
		(stopTime - thisThread.clock.beats - 0.12).yield;
	};
	~freqRampTime = Pkey(\dur) * Pwhite(0.2, 0.6, inf);
	~gate = 0.7;
	~parentDur = Pfunc({ BP(~bp).lastEvent.delta });

	~asPattern = {
		if(~parentDurStream.isNil) { ~makeStreamForKey.(\parentDur) };
		if(~startDegreeStream.isNil) { ~makeStreamForKey.(\startDegree) };
		PnNilSafe(
			Pbind(
				\parentDur, Plazy({ |ev| ~parentDurStream.next(ev).loop }),
				\dur, Plazy({ ~dur }),
				\mode, BPStream(\mode),
				\freq, Plazy({ ~degree }),
				\length, Plazy({ ~length }),
				\freqRampTime, BPStream(\freqRampTime) / Ptempo(),
				\gate, BPStream(\gate)
			).trace,
			inf
		)
	};
} => PR(\sbass);
)

BP(\sbs).free;
PR(\sbass) => BP(\sbs);
VC(\qb) => BP(\sbs);
BP(\sbs) => MT(1);

p = BP(\sbs);

p.parentDur = MacRh(\rpt16).asPattern;

BP(\sbs).reset;
BP(\sbs).play(AbsoluteTimeSpec(BP(\rp).eventStreamPlayer.nextBeat.roundUp));

p.dur = Pconst({ |ev| ev[\parentDur] }, Pseq([Pwhite(0.3, 1.0, 1), Rest(10000)], 1)).trace;

p.dur = Pfuncn({ |ev| ev[\parentDur] }, 1);
p.length = Pwhite(0.3, 1.0, inf);

p.dur = p.dur2;
p.length = Prout { |ev|
	// - 0.001 -- build in a threshold to avoid FP rounding error
	var stopTime = (thisThread.clock.beats + ev[\parentDur]) - 0.001;
	while {
		(thisThread.beats + ev.delta) < stopTime
	} {
		ev = (ev[\dur] * 1.01).yield;
	};
	(stopTime - thisThread.clock.beats - 0.12).yield;
};

BP(\rp).v[\lastEvent]

p.parentDur = Pfunc({ BP(~bp).lastEvent.delta });

p.startDegree = \patRejectLastN.eval(Pseries({ rrand(21, 28) }, Pwhite(1, 4, inf) * Pseq(#[-1, 1], inf, { 2.rand }), inf).fold(21, 28), 1);

p.degree = Pseries(
	{ |ev| ~startDegreeStream.next(ev) },
	Pstutter(Pwhite(1, 2, inf), Pwhite(1, 4, inf)) * Pseq(#[-1, 1], inf, { 2.rand }),
	inf
);

p.dur = Pconst(
	{ |ev| ev[\parentDur] },
	Pseq([Pwhite(4, 7, 1) * 0.25, Pwrand(#[0.25, 0.5, 0.75], #[0.05, 0.6, 0.35], inf)], 1)
);

p.length = Prout { |ev|
	// - 0.001 -- build in a threshold to avoid FP rounding error
	var stopTime = (thisThread.clock.beats + ev[\parentDur]) - 0.001;
	while {
		(thisThread.beats + ev.delta) < stopTime
	} {
		ev = (ev[\dur] * 1.01).yield;
	};
	(stopTime - thisThread.clock.beats - 0.12).yield;
};

p.freqRampTime = Pkey(\dur) * Pwhite(0.2, 0.6, inf);

// ok, this is solid, but sometimes the damn stupid voicer doesn't play the first note?
p.length = Prout { |ev|
	// - 0.001 -- build in a threshold to avoid FP rounding error
	var stopTime = (thisThread.clock.beats + BP(~bp).lastEvent.delta) - 0.001;
	while {
		(thisThread.beats + ev.delta) < stopTime
	} {
		ev = (ev[\dur] * 1.01).yield;
	};
	0.1.yield;
};

VC(\qb).gate(150, 0.15, 0.7);

p.event.adjustLengthToRealDelta = false;

( 'freqRampTime': 0.85166999816895, 'length': 0.95428758859634, 'clock': a TempoClock, 'eventKey': voicerNote,
  'dur': 4, 'mode': d, 'gate': 0.7, 'collIndex': sbs, 'voicer': a MonoPortaVoicer,
  'adjustLengthToRealDelta': false, 'timingOffset': 0, 'parentDur': 4, 'freq': 25, 'propagateDownward': a Function )

(parent: ProtoEvent(\voicerNote).v, voicer: VC(\qb).v, freq: 22, mode: \d, length: 0.7, dur: 1, gate: 0.7, freqRampTime: 0.8, timingOffset: 0, debug: true, clock: TempoClock.default).play;

VC(\qb).v.nodes[0].inspect
VC(\qb).v.nodes[0].shouldSteal
VC(\qb).nodes[0].myLastLatency

>> steal: steal: true
isPlaying: false
synth exists: true
synth is playing: false
since last trigger: 0.0010378360748291
should steal: true

>> steal: steal: true
isPlaying: false
synth exists: true
synth is playing: false
since last trigger: 0.0011160373687744
should steal: false