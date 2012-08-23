(thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;
// (thisProcess.nowExecutingPath.dirname +/+ "../common/common-defs.scd").loadPath;

(thisProcess.nowExecutingPath.dirname +/+ "../processes/long-ch-procs.scd").loadPath;

(thisProcess.nowExecutingPath.dirname +/+ "../processes/mid-fast-procs.scd").loadPath;

BP(\shengShared).free;
PR(\shengShared) => BP(\shengShared);

MixingBoard.at(0).postSettings;

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);

s.addr = ~debugAddr;
s.addr = ~saveAddr;



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


VC(\fm).free;
Fact(\madfmVC) => VC(\fm);

(type: \voicerNote, voicer: VC(\fm).v, freq: 440, sustain: 2, mod_ratio1: 3, mod_ratio2: 3, car_detune: 1.003, car_buf: VC(\fm).env.bufs.choose, mod_buf: VC(\fm).env.bufs.choose, car_env: Env.adsr(0.01, 0.8, 0.1, 0.2), mod_env: Env.adsr(0.01, 0.8, 0.6, 0.2)).play;