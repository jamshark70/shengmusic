(thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;
// (thisProcess.nowExecutingPath.dirname +/+ "../common/common-defs.scd").loadPath;

(thisProcess.nowExecutingPath.dirname +/+ "../processes/long-ch-procs.scd").loadPath;

(thisProcess.nowExecutingPath.dirname +/+ "../processes/mid-fast-procs.scd").loadPath;

TempoClock.tempo = 88/60;

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

(type: \voicerNote, voicer: VC(\flzg).v, ffreq: 4000, rq: 0.4, holdtime: 1000, flzgrate: 28, flzgratio: 0.4, flzgdepth: 0.9, flzgtime: 0.8, sustain: 2).play;



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



p = PbindProxy(
	\type, \voicerNote,
	\voicer, VC(\fm).v,
	\midinote, Pseed(Pstutter(Pwhite(1, 3, inf), Pwhite(0, 0x7FFFFFFF, inf)),
		Pseries({ rrand(48, 55) }, Pwrand(#[-1, -2, -3, -4], #[0.2, 0.4, 0.3, 0.1], { rrand(4, 8) }))),
	\dur, 0.15,
	\car_buf, b,
	\car_detune, 1.006,
	\car_buf, b /* VC(\fm).env.bufs[2] */,
	\mod_buf, Prand(VC(\fm).env.bufs, inf),
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

p.set(\mod_ratio2, Pwhite(1, 3, inf) * 2 + 1 + (Pwhite(0.12, 0.3, inf) * Prand(#[-1, 1], inf)), \mod_ratio1, Pkey(\mod_ratio2));


// smooth melody
(
SynthDef(\noiselet2, { |freq = 440, noisefreq = 60, beats = 0.5, noisebuf,
	filtAttack = 0.02, filtDecay = 0.3,
	attack = 1, decay = 0, susLevel = 1, release = 1, gate = 1,
	pan = 0, amp = 0.1, out = 0, freqlag = 0, freqratio = 1.003|
	var sig = COsc.ar(noisebuf, noisefreq, beats, amp),
	eg = EnvGen.kr(Env.adsr(attack, decay, susLevel, release), gate, doneAction: 2);
	sig = Formlet.ar(sig, Lag.kr(freq, freqlag) * [1, freqratio], filtAttack, filtDecay).sum;
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

k = VoicerMIDISocket(0, v);

v.setArgDefaults([attack: 0.15, decay: 0.1, susLevel: 0.6, release: 0.2]);

v.globalControls[\filtAttack].spec_(#[0.01, 0.28, \exp]);

v.mapGlobal(\filtDecay, nil, 0.3, #[0.1, 0.5, \exp]);

VC(\nletmel).env.target.postSettings


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
	env: Env(#[0, 1, 0.4, 0.05, 0], #[0.07, 0.12, 3, 0.12], #[-4, -4, -6.5, -4], releaseNode: 3)
));

Fact(\oscilBP) => BP(\oscil);
p = BP(\oscil);
VC(\oscil) => p;

p => MT(1);


Pwhite(3, 6, inf) * 0.5 =>.macro p;
\hold16th =>.micro p;

Pseq([Pwhite(3, 6, { rrand(2, 6) }) * 0.5, Pn(1, { 2.rand + 1 })], inf) =>.macro p;
Pif(Pkey(\delta) <= 1, \hold6tuplet, \hold16th) =>.micro p;


'16th' =>.micro p;

\highLow =>.arpeg p;
\up =>.arpeg p;
\interleave =>.arpeg p;

