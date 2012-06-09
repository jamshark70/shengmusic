(thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);

s.addr = ~debugAddr;
s.addr = ~saveAddr;

#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
	Mode(\default).v.copy.root_(i) => Mode(key);
	Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
};



// pitch from noise

fork {
	var c = Condition.new;
	b = Array.fill(5, {
		var new = Buffer.alloc(s, 2048, 1).debug("allocated");
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
	excratio = 0.5, excamp = 0.1, fbamp = 1, pan = 0,
	env, timeScale = 1,
	bufselect, firstbuf = 1, numbufs = 2|
	var frq = freq.dereference.value(),
	delayt = max(0, frq.reciprocal - ControlDur.ir),
	excfreq = frq * excratio.dereference.value(),
	firstbufnum = firstbuf.asUGenInput,  // .bufnum if a Buffer, 'this' if a number
	exc = VOsc.ar(
		bufselect.dereference.value().range(firstbufnum, firstbufnum + numbufs - 1.01),
		excfreq, 0,
		excamp
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
	Pan2.ar(feedback, pan, eg)
}, [
	\freq, \amp, \freq,
	#[0.1, 1, \exp], \amp, \amp, \bipolar,
	EnvSpec(Env.adsr), #[0.01, 100, \exp],
	ObjectSpec({ SinOsc.kr(Rand(0.08, 0.14)) }), \mybuf, StaticSpec(2, 16, \lin, 1, 2)
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
	\excratio, Pwhite(0.45, 0.6, inf),
	\pan, Pwhite(0.7, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand }),
	\env, [Env.adsr(0.5, 0.6, 0.6, 4)]
);

r = n.play(q);

q.set(\amp, 0.01);
q.set(\excamp, 0.05);

r.stop;

