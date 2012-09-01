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

// SynthDescLib.global.browse;


// pitch from noise

fork {
	var c = Condition.new;
	b = Array.fill(5, {
		var new = Buffer.alloc(s, 2048, 1);
		s.sync;
		fork {
			new.sendCollection(Signal.fill(1024, { 1.0.rand2 }).asWavetable, action: { c.unhang });
		};
		c.hang;
		new
	});
	"done".postln;
};


// it's a bit like a buzz saw, very very harsh
// maybe pink noise in the bufs?

a = m.play {
	var excfreq = Rand(50, 90),
	exc = VOsc3.ar(
		SinOsc.kr(0.05).range(b[0].bufnum, b[4].bufnum - 0.01),
		excfreq / 0.95, excfreq, excfreq * 0.95,
		0.1
	),
	freq = MouseX.kr(200, 600, 1, 0.1),
	delayt = freq.reciprocal;
	LeakDC.ar(
		CombL.ar(
			exc,
			maxdelaytime: 0.06,
			delaytime: delayt,
			decaytime: MouseY.kr(0.01, maxval: 5, warp: \exponential, lag: 0.1)
		) - DelayL.ar(exc, 0.06, freq.reciprocal)
	)
};

a.free;

(0..4).do { |b| s.sendMsg(\b_free, b) };
(0..4).do { |b| s.bufferAllocator.free(b) };

PeakMonitor(m);


// less buzz-saw-y
// actually really cool - you can hear sweeping through the noise bufs!!

a = m.play {
	var //excfreq = Rand(30, 80) * LFNoise1.kr(1.2).exprange(1/1.2, 1.2),
	freq = MouseX.kr(80, 600, 1, 0.1),
	delayt = freq.reciprocal - ControlDur.ir,
	excfreq = freq * SinOsc.kr(0.08).range(0.5, 1),
	exc = VOsc.ar(
		SinOsc.kr(0.05).range(b[0].bufnum, b[4].bufnum - 0.01),
		// excfreq / 0.95, excfreq, excfreq * 0.95,
		excfreq, 0,
		0.1 //Decay2.kr(Impulse.kr(0) * 0.1, attackTime: 0.005, decayTime: 0.02)
	),
	feedback = LocalIn.ar(1);
	exc = exc + DelayL.ar(exc, 0.05, (excfreq * 2).reciprocal); // (SinOsc.kr(Rand(0.09, 0.11), 0, 0.002, 0.003));
	feedback = feedback + exc;
	feedback = LPF.ar(feedback, MouseY.kr(1000, 10000, \exponential, 0.1));
	feedback = DelayL.ar(feedback, 0.11, delayt, mul: 1);
	LocalOut.ar(feedback);
	LeakDC.ar(feedback);
};

a.trace

m.scope

a.free;



WrapInstr("osc.ks_sustained", { |freq = 440, amp = 0.1, ffreq = 2000,
	excratio = 0.5, excamp = 1, fbamp = 1, pan = 0,
	env, timeScale = 1,
	bufselect, firstbuf = 1, numbufs = 2, detectSilence|
	var frq = freq.dereference.value(),
	delayt = max(0, frq.reciprocal - ControlDur.ir),
	excfreq = frq * excratio.dereference.value(),
	firstbufnum = firstbuf.asUGenInput,  // .bufnum if a Buffer, 'this' if a number
	exc = VOsc.ar(
		bufselect.dereference.value().range(firstbufnum, firstbufnum + numbufs - 1.01),
		excfreq, 0,
		excamp.dereference.value()
	),
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
		#[0.1, 1, \exp], \amp, \amp, \bipolar,
		EnvSpec(Env.adsr), #[0.01, 100, \exp],
		ObjectSpec({ SinOsc.kr(Rand(0.08, 0.14)) }), \mybuf, StaticSpec(2, 16, \lin, 1, 2),
		ObjectSpec(false)
]);


p = WrapPatch("osc.ks_sustained", [
	nil, nil, nil,
	`{ LFDNoise1.kr(0.9).range(0.5, 1) }, nil, nil, nil,
	`{ NamedControl(\env, Env.adsr.asArray.extend(40, 0)) }, nil,
	`{ LFDNoise1.kr(Rand(0.08, 0.14)) }, b[0], b.size
]);

d = p.asSynthDef;

d.add;

m.play((instrument: d.name, ffreq: 8000, fbamp: 0.5));

r = m.play(
	q = PbindProxy(
		\instrument, d.name,
		\freq, Pexprand(200, 800, inf),
		\dur, Pexprand(0.06, 0.16, inf),
		\sustain, Pwhite(0.6, 1.0, inf),
		\ffreq, Pexprand(800, 9000, inf),
		\excratio, 0.5 // Pwhite(0.45, 0.6, inf),
	)
);

r = m.play(
	q = PbindProxy(
		\instrument, d.name,
		\freq, Pexprand(200, 800, inf),
		\dur, Pexprand(0.7, 2.2, inf),
		\sustain, Pwhite(3.0, 6.0, inf),
		\ffreq, Pexprand(800, 9000, inf),
		\excratio, 0.5, // Pwhite(0.45, 0.6, inf),
		\env, [Env.asr(1.5, 1, 2.2)]
	)
);


// one pitch w/ variations
// at low frequencies, fundamental is basically gone
// but the harmonics are damn cool, like inside-piano stuff
// rather metal-y, may need softening
r = n.play(
	q = PbindProxy(
		\instrument, d.name,
		\freq, Pwhite(33, 57, inf) *.x Pexprand(1/1.014, 1.014, 6),
		\dur, Pseq([Pexprand(0.4, 0.8, 5), Pwhite(6.0, 10.0, 1)], inf),
		\sustain, Pwhite(4.0, 7.0, inf),
		\ffreq, Pexprand(2000, 9000, inf),
		\excratio, Pwhite(0.45, 0.6, inf),
		\pan, Pwhite(0.7, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand }),
		\env, [Env.adsr(0.5, 0.6, 0.6, 4)]
	)
);

q.set(\ffreq, 2000);

// OK, THAT'S nice -- strong sense of pitch
q.set(\ffreq, Pexprand(800, 1800, inf));

q.set(\freq, Pwhite(50, 69, inf).collect { |num| num.asMIDINote.postln; num.midicps } *.x Pexprand(1/1.014, 1.014, 6));

q.set(\freq, Pwhite(50, 69, inf).midicps *.x Pexprand(1/1.014, 1.014, 6));

r.stop;

e = r.originalStream.next(());

OSCFunc({ |msg| s.sendMsg(\n_trace, msg[1]) }, '/n_go', s.addr).oneShot;
m.play(e);

// low notes are quite buzzy, dystopian
// midrange sounds better
(44100/64).cpsmidi.asInteger.asMIDINote

1.014.ratiomidi

n.play((instrument: d.name, midinote: [57, 61, 64].dup(3).flat, ctranspose: Array.fill(9, { 0.25.rand2 }), sustain: 3, ffreq: 1700, env: Env.adsr(0.5, 0.6, 0.6, 4)));


n.play((instrument: d.name, midinote: [26, 38].dup(5).flat, ctranspose: Array.fill(10, { 0.25.rand2 }), sustain: 15, ffreq: 900, env: Env.adsr(0.5, 0.6, 0.6, 4)));


// actually quite nice, calls for cavernous reverb *heh heh*
// sometimes low pitches seem tuned noticeably sharper than higher ones
q = PbindProxy(
	\instrument, d.name,
	\deg, Pseries(
		1,
		Pseq([1, 3, Pwrand(#[1, 2, 3], #[0.5, 0.3, 0.2], inf) * Prand(#[-1, 1], inf)]),
		inf
	).fold(-7, 7),
	\degree, Pfunc({ |ev| ev[\deg].dup(3).flat }),
	\ctranspose, Pwhite(-0.25, 0.25, inf).clump(Pkey(\degree).collect(_.size)),
	\root, 2,
	\dur, Pseq([Pexprand(0.4, 0.8, 5), Pwhite(6.0, 10.0, 1)], inf),
	\sustain, Pwhite(4.0, 7.0, inf),
	\ffreq, Pexprand(1600, 2000, inf),
	// \excratio, Pwhite(0.45, 0.6, inf),
	\pan, Pwhite(0.7, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand }),
	\env, [Env.adsr(0.5, 0.6, 0.6, 4)]
);

r = n.play(q);

q.set(\amp, 0.1);
q.set(\excamp, 0.5);

r.stop;



// plucked
WrapInstr("osc.ks_sustained").listArgs

p = WrapPatch("osc.ks_sustained", [
	nil, nil, nil,
	nil, // `{ LFDNoise1.kr(0.9).range(0.5, 1) },
	`{
		var time = NamedControl.kr(\excTime, 0.06);
		EnvGen.kr(Env.perc(0.5, 0.5), timeScale: time)
	}, nil, nil,
	Env(#[0, 1, 1], #[0.005, 3000]), nil,
	`{ LFDNoise1.kr(Rand(0.08, 0.14)) }, b[0], b.size, true
]);

(d = p.asSynthDef).add;

OSCdef(\on, { |msg| s.sendMsg(\n_trace, msg[1]); msg.debug("^^ on") }, '/n_go', s.addr);
OSCdef(\off, { |msg| msg.debug("  off") }, '/n_end', s.addr);

OSCdef(\on).free; OSCdef(\off).free;


n.play((instrument: d.name, fbamp: 0.99, ffreq: 2000, amp: 1, excTime: 0.05))

q = PbindProxy(
	\instrument, d.name,
	\freq, 60.midicps,
	\baseDur, 0.1,
	\dur, Pkey(\baseDur) * Pwrand(#[1, 2], #[0.9, 0.1], inf),
	\fbamp, 0.96,
	\ffreq, 2000,
	\amp, 1,
	\excTime, 0.01,
	\excratio, 1
);

r = n.play(q);

q.set(\ffreq, Pexprand(900, 2400, inf) * 2);

q.set(\baseDur, 0.12);

q.set(\fbamp, Pwhite(0.8, 1.0, inf));

// q.set(\freq, Array.fill(3, { 60.midicps * exprand(0.95, 1/0.95) }));

q.set(\freq, 60.midicps * Ptuple(Array.fill(3, Pexprand(0.8, 1 / 0.8, inf)), inf));

// excratio == 1 seems to raise by 1 octave
q.set(\excratio, 1);
q.set(\freq, 72.midicps);

r.stop;


// logic has some potential but this sound is too pitchy

p = Pbind(
	\instrument, d.name,
	\freq, Plazy({ exprand(100, 689).loop }),
	\baseDur, Plazy({ exprand(0.09, 0.14).loop }),
	\dur, Pkey(\baseDur) * Pwrand(#[1, 2], #[0.9, 0.1], inf),
	\fbamp, Pwhite(0.8, 1.0, inf),
	\ffreq, Pexprand(900, 2400, inf),
	\amp, Pseg(
		Pseq([0, 0.5, 0]),
		Plazy({ rrand(3.0, 6.0).loop }),
		\sine
	),
	\excTime, 0.01,
	\excratio, 1
);

r = n.play(p);

q = n.play(Pspawner({ |sp|
	loop {
		sp.par(p);
		sp.wait(rrand(1.0, 4.0));
	}
}));

q.stop;


// maybe something like this?

a = m.play {
	var exc = Osc.ar(b.choose, exprand(50, 200)) * Decay2.ar(
		Impulse.ar(0), 0.01, 0.05),
	sig = Klank.ar(`[
		Array.fill(5, { exprand(200, 1400) }),
		Array.fill(5, 0.1),
		Array.fill(5, { exprand(0.02, 0.2) })
	], exc);
	DetectSilence.ar(sig, doneAction: 2);
	sig
};


[ [ 621.62188989246, 458.28750962083, 483.12690995039, 1341.4332586515, 229.71349364755 ], [ 0.1, 0.1, 0.1, 0.1, 0.1 ], [ 0.16730279340267, 0.039352280429134, 0.13997095946335, 0.030161787383422, 0.14313835788342 ] ].flat


// could transform into this sound later
// but not what I want at first

// would like a more transparent sound
// the exciter is too clearly audible
(
SynthDef(\klinks, { |out, bufnum, amp = 0.1,
	excfreq = 100, excAtk = 0.01, excDcy = 0.05,
	klAtk = 0, klDcy = 1,
	pan = 0|
	var exc = Osc.ar(bufnum, excfreq, 0, amp) * Decay2.ar(
		Impulse.ar(0), excAtk, excDcy),
	specs = NamedControl.kr(\specs, #[621.62188989246, 458.28750962083, 483.12690995039, 1341.4332586515, 229.71349364755, 0.1, 0.1, 0.1, 0.1, 0.1, 0.16730279340267, 0.039352280429134, 0.13997095946335, 0.030161787383422, 0.14313835788342]).clump(5),
	sig = Klank.ar(`specs, exc, decayscale: klDcy) - Klank.ar(`specs, exc, decayscale: klAtk);
	DetectSilence.ar(sig, doneAction: 2);
	Out.ar(out, Pan2.ar(sig, pan));
}).add;
)

e = n.play((instrument: \klinks, bufnum: b.choose, amp: 0.8));

p = n.play(Pn((instrument: \klinks, bufnum: b.choose, amp: 0.8, dur: 0.5, excAtk: 0.05, excDcy: 0.1, specs: [[621.62188989246, 458.28750962083, 483.12690995039, 1341.4332586515, 229.71349364755, 0.1, 0.1, 0.1, 0.1, 0.1] ++ Array.fill(5, { exprand(0.05, 0.15) })]), inf));

p.stop;


Pdefn(\klAtk, 0.5);
Pdefn(\klDcy, 1);

p = n.play(Pspawner({ |sp|
	var dur, ampTemplate = Array.fill(5, 0.5);
	loop {
		dur = rrand(3.0, 7.0);
		sp.par(
			Pfindur(dur, Pbind(
				\instrument, \klinks,
				\bufnum, BP(\shengShared).noiseBufs.choose,
				\amp, Env(#[0.4, 0.8, 0.8, 0.2], [0.1, 0.5, 0.4] * dur, #[-4, 0, -2]),
				\dur, rrand(0.09, 0.41) * Pwrand(#[1, 2], #[0.85, 0.15], inf),
				\pan, 1.0.rand2,
				\klAtk, Pdefn(\klAtk),
				\klDcy, Pdefn(\klDcy),
				\excfreq, exprand(300, 900),
				// \excAtk, 0.06,
				// \excDcy, 0.14,
				\specs, [[
					Array.fill(5, { exprand(1400, 4000) }),
					ampTemplate,
					Array.fill(5, { exprand(0.02, 0.2) })
				].flat]
			))
		);
		sp.wait(exprand(1.0, 4.0));
	}
}));

Pdefn(\klAtk, 0.3);
Pdefn(\klDcy, 0.5);

p.stop;


OSCFunc({ |msg| s.sendMsg(\n_trace, msg[1]) }, '/n_go', s.addr).oneShot;

s.nodeAllocator.inspect

s.sendMsg(\n_trace, e.id[0]);



// the secret: low frequency (gets a really silvery chorusy effect)
// and high-pass filtering

SynthDef(\zzip, { |out, bufnum, freq = 440, dtune = 1.003,
	hpfreq = 800, hprq = 1,
	amp = 0.1, gate = 1, pan = 0|
	var sig = VOsc3.ar(bufnum, freq / dtune, freq, freq * dtune, amp),
	env = NamedControl.kr(\env, Env.asr(0.02, 1, 0.02).asArray.extend(32, 0));
	sig = RHPF.ar(sig, hpfreq, hprq);
	Out.ar(out, Pan2.ar(sig, pan, EnvGen.kr(env, gate, doneAction: 2)));
}).add

n.play((instrument: \zzip, bufnum: rrand(0.0, b.size - 1.01), sustain: 0.07, freq: 30, hpfreq: 8000, env: Env.asr(0.03, 1, 0.03)));

p = n.play(q = PbindProxy(
	\instrument, \zzip,
	\bufnum, rrand(0.0, b.size - 1.01),
	\sustain, 0.07,
	\freq, Pexprand(25, 38, inf),
	\hpfreq, Pexprand(6000, 9500, inf),
	\env, [Env.adsr(0.01, 0.02, 0.05, 0.03).asArray],
	\pan, Pwhite(0.7, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand })
));

q.set(\dur, Pstutter(Pwhite(3, 8, inf), Pexprand(0.09, 0.14, inf)));
q.set(\pan, Pwhite(-1.0, 1.0, inf));
q.set(\hprq, Pwhite(0.1, 0.4, inf));
q.set(\hpfreq, Pexprand(5000, 8000, inf));

q.set(\env, [Env.adsr(0.01, 0.15, 0.05, 0.03).asArray]);

p.stop;



p = n.play(Pspawner({ |sp|
	var dur, ampTemplate = Array.fill(5, 0.5);
	loop {
		dur = rrand(3.0, 7.0);
		sp.par(
			Pfindur(dur, Pbind(
				\instrument, \zzip,
				\bufnum, rrand(0.0, b.size - 1.01),
				\sustain, 0.07,
				\freq, Pexprand(25, 38),
				\hpfreq, exprand(5000, 8000),
				\hprq, 0.05, // rrand(0.1, 0.4),
				\env, [Env.adsr(0.01, rrand(0.02, 0.15), 0.05, 0.03).asArray],
				// \env, [Env.adsr(0.01, 0.02, 0.05, 0.03).asArray],
				\amp, Env(#[0.4, 0.8, 0.8, 0.2] / 8, [0.1, 0.5, 0.4] * dur, #[-4, 0, -2]),
				\dur, rrand(0.09, 0.41) * Pwrand(#[1, 2], #[0.85, 0.15], inf),
				\pan, 1.0.rand2,
			))
		);
		sp.wait(exprand(1.0, 4.0));
	}
}));

p.stop;


// ok, idea - multiple synthdefs

(
var ampTemplate = Array.fill(5, 0.5), freqTemplate = (3..15),
zzipFreqStream = (Prand(#[62, 69], inf) + (12 * Pwhite(2, 6))).midicps.asStream;

~dict = (
	zzip: Pbind(
		\instrument, \zzip,
		\bufnum, Plazy({ b[0].bufnum + rrand(0.0, b.size - 1.01).loop }),
		\sustain, 0.07,
		\freq, Pexprand(25, 38),
		\hpfreq, Plazy({ zzipFreqStream.next.loop }),
		\hprq, 0.05, // rrand(0.1, 0.4),
		\env, Plazy({ [Env.adsr(0.01, rrand(0.02, 0.15), 0.05, 0.03).asArray].loop }),
		// \env, [Env.adsr(0.01, 0.02, 0.05, 0.03).asArray],
		\dur, Plazy({ rrand(0.09, 0.41).loop }) * Pwrand(#[1, 2], #[0.85, 0.15], inf),
		\pan, Plazy({ 1.0.rand2.loop }),
		\ampFactor, 1/8 * (-6.dbamp)
	),
	klinks: Pbind(
		\instrument, \klinks,
		\bufnum, Plazy({ b.choose.loop }),
		\dur, Plazy({ rrand(0.09, 0.41).loop }) * Pwrand(#[1, 2], #[0.85, 0.15], inf),
		\pan, Plazy({ 1.0.rand2.loop }),
		\klAtk, Pdefn(\klAtk),
		\klDcy, Pdefn(\klDcy),
		\excfreq, Plazy({ exprand(300, 900).loop }),
		// \excAtk, 0.06,
		// \excDcy, 0.14,
		\specs, Plazy({ [[
			// Array.fill(5, { exprand(1400, 4000) }),
			(#[1, 2] ++ freqTemplate.scramble.keep(3)) * #[62, 69].choose.midicps,
			ampTemplate,
			Array.fill(5, { exprand(0.02, 0.2) })
		].flat].loop }),
		\ampFactor, -3.dbamp
	)
);
)

p = n.play(Pspawner({ |sp|
	var dur, synthStream = Prand(#[zzip, klinks], inf).asStream, synth;
	loop {
		dur = rrand(3.0, 7.0);
		synth = synthStream.next.postln;
		sp.par(
			Pchain(
				Pbind(
					\amp, Env(#[0.4, 0.8, 0.8, 0.2], [0.1, 0.5, 0.4] * dur, #[-4, 0, -2])
					.asStream * Pkey(\ampFactor),
					\dur, Pkey(\dur) * Env(#[1, 2], [dur], 3)
				),
				Pfindur(dur, ~dict[synth])
			)
		);
		sp.wait(exprand(1.0, 4.0));
	};
}));

p.isPlaying
p.stop;


(~rvbmc = MixerChannel(\rvb, s, 2, 2, outbus: ~master)) => MCG(6);

z = ~rvbmc.playfx(Instr("busfx.freeverb2"), [0]); z.gui;

FxPatch(
	[ 'busfx', 'freeverb2' ], [ 22, 1.0, 0.96938775510204, 0.38265306122449, 1.0 ]
)

n.postSettings;  // send == -8.dbamp



// actually quite nice, calls for cavernous reverb *heh heh*
// sometimes low pitches seem tuned noticeably sharper than higher ones
q = PbindProxy(
	\instrument, d.name,
	\octave, 5,
	\deg, Prand(#[0, 4], inf),
	\degree, Pfunc({ |ev| ev[\deg].dup(3).flat }),
	\root, 2,
	\dur, Pseq([Pexprand(0.4, 0.8, 5), Pwhite(6.0, 10.0, 1)], inf),
	\sustain, Pwhite(4.0, 7.0, inf),
	\ffreq, Pexprand(1600, 2000, inf),
	\ctranspose, Pwhite(-0.25, 0.25, inf).clump(Pkey(\degree).collect(_.size)),
	// \excratio, Pwhite(0.45, 0.6, inf),
	\pan, Pwhite(0.7, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand }),
	\env, [Env.adsr(0.5, 0.6, 0.6, 4)]
);

r = n.play(q);

q.set(\amp, 0.1);
q.set(\excamp, 1.2);

q.set(\dur, Pseq([Pexprand(0.4, 0.8, { rrand(2, 9) }), Pwhite(1.5, 4.5, 1)], inf));

q.set(\octave, Pwhite(3, 5, inf));

q.set(\octave, Pwhite(3, 3, inf));

q.set(\octave, 3);
q.set(\octave, 4);
q.set(\octave, 5);

q.set(\ffreq, Pfunc({ |ev|
	var freq = ev.use({ ~detunedFreq.value.asArray.maxItem }),
	ffreq = max(rrand(1600, 2000), (rrand(3, 6) + rrand(0.2, 0.8)) * freq);
	if(0.01.coin) { ffreq = ffreq * exprand(2.0, 3.0) };
	// [ev[\octave], (ffreq / freq)].postln;
	ev[\fratio] = ffreq / freq;
	ev[\ampFactor] = ffreq.linlin(1600, 12000, 1.0, 0.08);
	ffreq
}));

q.set(\excamp, 1.2 * Pkey(\ampFactor));

g = GenericGlobalControl(\cents, nil, 15.306, #[-100, 100]);
g.gui;

q.set(\ctranspose, (Pwhite(-0.15, 0.15, inf) + (g.asPattern * 0.01)).clump(Pkey(\degree).collect(_.size)));

q.set(\ctranspose, (/*Pwhite(-0.15, 0.15, inf) +*/ (Pkey(\octave).linlin(3, 5, 0.051, 0.38))).clump(Pkey(\degree).collect(_.size)));

q.set(\ctranspose, (Pwhite(-0.1, 0.1, inf) + (Pkey(\fratio).linlin(4, 23, 0.6, 0.051))).clump(Pkey(\degree).collect(_.size)));

r.stop;

r.isPlaying

1600 / 36.midicps

440 * 24

Library.at(WrapInstr, \test).keys

a = n.play(Instr("test.tuner"), [nil, 1]); a.gui

Patch("test.tuner",[
	440.0,
	1,
	Env([ 0.0, 1.0, 1.0, 0.0 ], [ 0.05, 0, 0.1 ], -4.0, 2),
	0.0,
	0.9911978051386
])

0.9911978051386.ratiomidi

50.midicps



// process tests

(~rvbmc = MixerChannel(\rvb, s, 2, 2, outbus: ~master, completionFunc: { |chan| z = ~rvbmc.playfx(Instr("busfx.freeverb2"), [22, 1.0, 0.96938775510204, 0.38265306122449, 1.0]); })) => MCG(6);

(thisProcess.nowExecutingPath.dirname.dirname +/+ "processes/drones-and-clicks.scd").loadPath;

BP(\sd).free;
PR(\shengDrone) => BP(\sd);
0 => BP(\sd);
p = BP(\sd);

BP(\cl).free;
PR(\clicks).chuck(BP(\cl), nil, (master: ~master));
// BP(\cl) => MCG(3);
0 => BP(\cl);


BP(\cl).listVars;



e = p.use { ~eventStream.next(~event.copy) };
e.associationsDo { |assn| assn.postln }; ""

f = e.copy;
f.keysValuesDo { |key, val|
	if(val.size == 3) { f[key] = val[0] };
};

f.amp = 0.5;
e.amp = 0.5;

p.chan.play(f);

p.chan.play(e);

p.triggerOneEvent(0);

e.pan = 0;

p.chan.play(e.copy.sustain_(7).env_([Env.adsr(0.4, 0.9, 0.2, 4, curve: #[2, -1, -4])]));

var sus = 0.2;
p.chan.play(e.copy.sustain_(7).env_([Env.adsr(0.5, 0.6, sus, 4, 0.2/sus, curve: #[2, -1, -4])]));

var sus = 0.2;
n.play(e.copy.sustain_(7).env_([Env.adsr(0.5, 0.6, sus, 4, 0.2/sus, curve: #[2, -1, -4])]));

e.env.postcs

e.env_([Env.adsr(0.5, 0.8, 0.2, 4)]);

p.listVars


p.sustainAmp = 0.2;
p.desiredSusAmp = 0.2;

p.sustainAmp = 0.6;
p.desiredSusAmp = 0.6;

p.octave = Pwhite(3, 5, inf);
p.octave = 5;
p.deg = Pif(Pkey(\dur) >= 2, 0, Pwrand(#[0, 4], #[0.45, 0.55], inf));

p.override(\deg, Pseq([3, 5], 1));
p.override(\octave, Pn(5, 2));

p.saveSustain = p.sustain;
p.saveDur = p.dur;

p.dur.postcs

// slow opening
p.hiProb = 0;

p.dur = Pseq([
	Pexprand(4.0, 9.0, { rrand(2, 5) }),
	Pexprand(0.3, 0.8, { rrand(2, 8) })
	Pexprand(4.0, 9.0, { rrand(2, 4) }),
], inf);

p.sustain = Pwhite(1.5, 4.5, inf);

p.savePan = p.pan;
p.pan = Pwhite(-0.5, 0.5, inf);

p.gestures.longPauses = Pbind(
	\dur, Pseq([
		Pexprand(4.0, 9.0, { rrand(2, 5) }),
	], 1),
	\sustain, Pwhite(1.5, 4.5, inf),
	\octave, 5,
	\deg, 0
);

p.gestures.da = Pbind(
	\dur, Pexprand(0.3, 0.8, { rrand(2, 8) }),
	\sustain, Pwhite(1.5, 4.5, inf),
	\octave, 5,
	\deg, Pwrand(#[0, 4], #[0.45, 0.55], inf)
);

p.gst = \longPauses;

p.gst = Pseq(#[longPauses, da], inf);

p.gstStream

p.gesture.postcs

p.listMethods;
p.listVars;

p.override(\gst, Pn(\default, 1).trace(prefix: "override gesture: "));
p.unOverride(\gst);

p.makeStreamForKey(\gesture);

p.gestures.dArpeg = Pbind(
	\dur, Pexprand(0.3, 0.8, inf),
	\sustain, Pwhite(1.5, 4.5, inf),
	\octave, 5,
	\deg, Pscratch(
		Pwhile1(
			{ |inval, next| next <= 9 },
			Pseries(-14, Pseq([4, 3, Pwrand(#[1, 2, 3], #[0.45, 0.45, 0.1], inf)], 1), inf)
		),
		Pn(Plazy({
			var numforward = rrand(2, 5), numbackward = rrand(2, 4);
			Pseq([Pn(1, numforward), numbackward, Pn(-1, numbackward - 1), numbackward], 1)
		}), inf)
	)
);

p.override(\gesture, p.gestures[\dArpeg], false, { "override done".debug });
p.nextEventNow;


p.gestures.enat = Pbind(
	\dur, Plazy({ Pn(rrand(0.3, 0.52), rrand(5, 9)) }),
	\sustain, 0.25,
	\octave, 5,
	\deg, 1,
	\amp, 0.25
);

p.override(\gesture, p.gestures[\enat]); p.nextEventNow;


p.gestures.ebnat = Pbind(
	\dur, Plazy({ Pn(rrand(0.2, 0.45), rrand(6, 11)) }),
	\sustain, 0.25,
	\octave, 5,
	\deg, Pstutter(Pwhite(2, 3, inf), Pseq(#[-2, 1], inf, { 2.rand })),
	\amp, 0.25
);

p.override(\gesture, p.gestures[\ebnat]); p.nextEventNow;


p.gestures.pentatonic = Pbind(
	\dur, Plazy({ Pn(rrand(0.2, 0.45), inf) }),
	\sustain, 0.25,
	\octave, 5,
	\deg, Pstutter(Pwhite(2, 3, inf), Pshuf(#[-2, 0, 1, 2, 4], 1)),
	\amp, 0.25
);

p.override(\gesture, p.gestures[\pentatonic]); p.nextEventNow;


p.gestures.gb = Pbind(
	\dur, Plazy({ Pn(rrand(0.2, 0.45), { rrand(7, 12) }) }),
	\sustain, 0.25,
	\octave, 5,
	\deg, Pstutter(Pwhite(2, 3, inf), Pseq(#[3, 5], inf)),
	\amp, 0.25
);

p.gestures.gbcs = Pbind(
	\dur, Plazy({ Pn(rrand(0.2, 0.45), { rrand(12, 21) }) }),
	\sustain, 0.25,
	\octave, 5,
	\deg, Pstutter(Pwhite(2, 3, inf), Pseq(#[3, 5, 6], inf)),
	\amp, 0.25
);

p.gestures.gsbcs = Pbind(
	\dur, Plazy({ Pn(rrand(0.2, 0.45), { rrand(12, 21) }) }),
	\sustain, 0.25,
	\octave, 5,
	\deg, Pstutter(Pwhite(2, 3, inf), Pn(Pshuf(#[3.1, 5, 6], 1), inf)),
	\amp, 0.25
);

p.gestures.midRest = Pbind(
	\dur, Pwhite(2.0, 5.0, 1),
	\deg, Rest
);

// this does not yield control, so you have to override it or use below technique
p.gestures.fullRangeDrone = Plazy({
	Pset(\octave, Pwhite(Env(#[5, 3], #[5]).asStream.round, 5.99, inf).trunc, PnNilSafe(~gestures[\default], inf))
});

// p.gst = \fullRangeDrone; p.gestureNow(\fullRangeDrone);
(
p.gst = \fullRangeDrone;       // new gesture name
p.makeStreamForKey(\gesture);  // start 'gesture' fresh with the new choice
p.nextEventNow;                // go immediately
)

p.gestureNow(Pn(\gb, 2));
p.gestureNow(Pn(\gsbcs, 1));


(
p.gst = Pseq(#[longPauses, da, longPauses], inf);
p.makeStreamForKey(\gesture);  // start 'gesture' fresh with the new choice
p.nextEventNow;                // go immediately
)

p.gstStream

p.gestureNow = { |keyPat, overrideDoneFunc|
	~override.(\gesture, Psym(Pn(keyPat, 1), ~gestures), false, overrideDoneFunc);
	~nextEventNow.();
	currentEnvironment
};

p.gestureNow(Pseq(#[da, gsbcs, midRest], 1));


p.gestureNow(\enat);
p.gestureNow(\ebnat);
p.gestureNow(\pentatonic);
p.gestureNow(Pseq(#[da, gb], 1));

p.gestureNow(Pseq(#[da, gbcs], 1));

p.gestureNow(\dArpeg);

p.setGstNow(\fullRangeDrone);
p.setGstNow(Pseq([ 'longPauses', 'da', 'longPauses' ], inf));

p.gst = Pseq([
	Pseq(['longPauses', 'da']),
	Prand([
		\enat, \ebnat, \pentatonic,
		Pseq(#[da, gb], 1),
		Pseq(#[da, gbcs], 1),
		\dArpeg
	])
], inf).trace;




// get some low sounds out of klinks def

// ok... multiband formlet, with periodic noise (including impulse-like transition)
// starts to become formant-like
n.play((instrument: \klinks, bufnum: BP(\shengShared).noiseBufs.choose, excfreq: exprand(25, 42), excAtk: 0.02, excDcy: 0.7, klAtk: 0.3, klDcy: 0.7, amp: 1, specs: [Array.fill(5, { exprand(80, 160) })]));

// not sure about modulating the exciter frequency
(
n.play((
	instrument: \klinks,
	bufnum: BP(\shengShared).noiseBufs.choose,
	excfreq: { ~lock.bus.asMap },
	excAtk: 0.02,
	excDcy: 0.7,
	klAtk: 0.3,
	klDcy: 0.7,
	amp: 1,
	specs: [Array.fill(5, { exprand(80, 160) })],
	parent: ProtoEvent(\polySynthKrBusLock).parent,
	numCh: 1,
	lpcEv: (
		instrument: \ctlEnv,
		env: [Env([1, rrand(1.5, 2.5)].rotate(2.rand) * exprand(25, 42), #[0.7], \exp)],
		connect: 0
	)
));
)

n.play((instrument: \klinks, bufnum: BP(\shengShared).noiseBufs.choose, excfreq: exprand(25, 42), excAtk: 0.02, excDcy: 0.7, klAtk: 0.3, klDcy: 0.7, amp: 1, specs: [Array.fill(5, { exprand(80, 160) })]));

(
SynthDef(\klinks2, { |out, bufnum = #[0, 0], amp = 0.1,
	excfreq = 100, excDetune = 1, excAtk = 0.01, excDcy = 0.05,
	klAtk = 0, klDcy = 1,
	pan = 0|
	var exc = Osc.ar(bufnum, excfreq * [1, excDetune], Rand(0, pi) + [0, pi], amp) * Decay2.ar(
		Impulse.ar(0), excAtk, excDcy),
	specs = NamedControl.kr(\specs, #[621.62188989246, 458.28750962083, 483.12690995039, 1341.4332586515, 229.71349364755, 0.1, 0.1, 0.1, 0.1, 0.1, 0.16730279340267, 0.039352280429134, 0.13997095946335, 0.030161787383422, 0.14313835788342]).clump(5),
	sig = Klank.ar(`specs, exc, decayscale: klDcy) - Klank.ar(`specs, exc, decayscale: klAtk);
	DetectSilence.ar(sig, doneAction: 2);
	Out.ar(out, Balance2.ar(sig[0], sig[1], pan));
}).add;
)


q = PbindProxy(
	\instrument, \klinks2,
	\bufnum, Pxrand(BP(\shengShared).noiseBufs, inf).clump(2).collect([_]),
	\degree, Pwhite(0, 4, inf),
	\octave, 3,
	\root, 2,
	\excfreq, Pfunc({ |ev| ev.use { ~detunedFreq.value } }),
	\excAtk, 0.02,
	\excDcy, 0.7,
	\klAtk, 0.3,
	\klDcy, 0.7,
	\amp, 1,
	\specs, Pexprand(80, 160, inf).clump(5).collect([_])
);

q.set(
	\instrument, \klinks2,
	\bufnum, Pxrand(BP(\shengShared).noiseBufs, inf).clump(2).collect([_])
);

p = n.play(q);

q.set(\excDetune, 1.5);

q.set(\octave, 5);
q.set(\specs, [Array.fill(5, { exprand(80, 160) })]);

g = GenericGlobalControl(\bufnum, nil, BP(\shengShared).noiseBufs.first.bufnum, [BP(\shengShared).noiseBufs.first.bufnum, BP(\shengShared).noiseBufs.first.bufnum + BP(\shengShared).noiseBufs.size - 1, \lin, 1]);

g => VP(0);
g.free;

q.set(\bufnum, g);
q.set(\excfreq, 80);
q.set(\excfreq, Pfunc({ |ev| ev.use { ~detunedFreq.value } }));

q.set(\octave, 3);

q.set(\bufnum, Prand(BP(\shengShared).noiseBufs, inf));

g.free;
g = GenericGlobalControl(\detuneRatio, nil, 1, #[1, 1.5, \exp]);
g => VP(0);

q.set(\specs, (Pkey(\excfreq) * (2 ** (3 - Pkey(\octave))) * (1..5) * (Pexprand(g.reciprocal, g, inf).clump(5))).collect([_]));

q.set(\octave, 7);
q.set(\octave, Pn(Pseries(2, 1, 6), inf));

q.set(\delta, Pwhite(1, 3, inf) * 0.5);

q.set(\klAtk, 0.25, \klDcy, 7);  // long decay time sounds nice, careful of limiting

q.postcs

p.isPlaying;

p = n.play(q);
p.stop;

e = q.source.endless.asStream.next(());

source.source.asStream.next(());

SynthDef(\osc, { |bufnum, excfreq, amp = 0.1, out|
	Out.ar(out,
		(Osc.ar(bufnum, excfreq, mul: amp) * EnvGen.kr(Env.perc(0.01, 0.5), doneAction: 2)) ! 2
	)
}).add;

q.set(\instrument, \osc);
q.set(\instrument, \klinks);