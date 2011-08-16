\supernova.eval;

(thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;

s.addr = ~debugAddr;
s.addr = ~saveAddr;


// brainstorm: really wacko, disjointed sounds -- don't fight the mood
// here, throw some shit on the wall, see what sticks

// other interesting idea: onset detection of live sheng playing, then decimate it
// for testing, i'll use a file elsewhere on disk

b.free;
b = Buffer.readAndQuery(s, "/home/dlm/share/SuperCollider/Recordings/cues/feet101120_155745-partnering-norm.aiff", 51766, 1449461);

b.free;
b = 2.collect { |i|
	Buffer.readChannel(s, "/home/dlm/share/SuperCollider/Recordings/cues/feet101120_155745-partnering-norm.aiff", 51766, 1449461, i);
};

b.do { |buf, i|
	buf.readChannel(
		"/home/dlm/share/SuperCollider/Recordings/cues/feet101120_155745-partnering-norm.aiff",
		51766, 1449461, channels: i
	)
};


~eb = Buffer.alloc(s, 2048, 1);
~eb.sendCollection(Env.perc(0.05, 0.95).discretize(2048));

~eb.getToFloatArray(action: { |data| { data.plot }.defer });


// aliasing is nice, quicksilvery, I want more aggressive

a = n.play {
	var	bufFr = BufFrames.ir(b[0]),
		trig = Dust.kr(12),
		dur = TExpRand.kr(0.07, 0.8, trig),
		rate = Demand.kr(trig, 0, Dswitch1([
			Dwhite(4.0, 8.0, inf),
			Dwhite(1.0, 1.4, inf),
			Dwhite(0.2, 0.5, inf)
		], Dwrand(#[0, 1, 2], #[0.6, 0.3, 0.1], inf))),
		pos = TRand.kr(0, bufFr - (rate * dur * BufSampleRate.ir(b[0])), trig) / bufFr;
	GrainBuf.ar(1, trig, dur, b, rate, pos, interp: 2, pan: 0, envbufnum: ~eb);
}.play;

a.free;


// different fx per grain = multiple SynthDefs

Disintegrator.ar( in, probability: 0.5, multiplier: 0, mul: 1, add: 0 )
WaveLoss.ar( in: 0, drop: 20, outof: 40, mode: 1, mul: 1, add: 0 )


// DON'T SKIP THIS!!!
~src = { |bufnum, rate = 1, start = 0, sustain = 1|
	PlayBuf.ar(1, bufnum, rate, 0, start, loop: 0)
		* EnvGen.kr(Env.linen(0.05, sustain, 0.05), doneAction: 2)
};

// interesting with changing spectra; not aggressive
a = m.play({ |dratio = 0.25|
	var	sig = SynthDef.wrap(~src),
		sr = SampleRate.ir;
	sig = Latch.ar(sig, Impulse.ar(sr * dratio));
	LPF.ar(sig.round(0.01), sr * 0.45);
}, [bufnum: b[0], start: 44100, dratio: 0.05]);

OSCFunc({ |msg| s.sendMsg(\n_trace, msg[1]) }, '/n_go', s.addr).oneShot;


// not aggressive but this is doing REALLY neat stuff
a = m.play({ |dratio = 0.25, bufnum, rate = 1, start = 0, sustain = 1|
	var	bufFr = BufFrames.kr(bufnum),
		freq = SinOsc.kr(0.09, 0).range(6, 18),
		trig = Impulse.ar(freq),
		dur = freq.reciprocal * 20,
		sig = GrainBuf.ar(1, trig, dur, bufnum, rate,
			start / bufFr, // SinOsc.kr(0.1, 0, 441, start) / bufFr,
			envbufnum: ~eb
		),
		sr = SampleRate.ir;
	sig = Latch.ar(sig, Impulse.ar(sr * dratio));
	LPF.ar(sig.round(0.01), sr * 0.45);
}, [bufnum: b[0], start: 948088, dratio: 0.05, rate: 1]);

a.set(\start, 309696);
a.set(\start, 356384);

a.free;

SynthDef(\buzzz, { |bufnum, tfmod = 0, tfLo = 5, tfHi = 5, gdur = 0.1, rate = 1, start = 0, envbuf = -1, gate = 1, dratio = 0.25, resolution = 0.01, lpfreq = 19000, amp = 1, out|
	var	bufFr = BufFrames.kr(bufnum),
		tfreq = SinOsc.kr(tfmod).range(tfLo, tfHi),
		trig = Impulse.ar(tfreq),
		sig = GrainBuf.ar(1, trig, gdur, bufnum, rate,
			start / bufFr, // SinOsc.kr(0.1, 0, 441, start) / bufFr,
			envbufnum: envbuf
		),
		sr = SampleRate.ir;
	sig = Latch.ar(sig, Impulse.ar(sr * dratio));
	sig = LPF.ar(sig.round(resolution), lpfreq, amp);
	Out.ar(out, sig * Linen.kr(gate, 0.01, 1, 0.01, doneAction: 2));
}).add;

// SinOsc thing doesn't work
m.play((
	instrument: \buzzz, 
	bufnum: b[0], tfLo: 22, tfHi: 8, tfmod: 6,
	gdur: 0.2, rate: 1, start: rrand(0, (b[0].numFrames * 0.8).asInteger),
	envbuf: ~eb, sustain: 2, dratio: 0.25, resolution: 0.01, lpfreq: 19000, amp: 4
));


// got some low frequencies, make it grittier
a = m.play({ |dratio = 0.25, bufnum, rate = 1, start = 0, sustain = 1|
	var	bufFr = BufFrames.kr(bufnum),
		freq = SinOsc.kr(0.09, 0).range(3, 12),
		trig = Impulse.ar(freq),
		dur = 0.1,
		sig = GrainBuf.ar(1, trig, dur, bufnum, rate,
			start / bufFr, // SinOsc.kr(0.1, 0, 441, start) / bufFr,
			envbufnum: ~eb
		);
	sig = Klank.ar(`[
		{ Rand(100, 200) } ! 3,
		nil,
		0.25
	], sig);
	sig.distort // Limiter.ar(sig);
}, [bufnum: b[0], start: 948088, dratio: 0.05, rate: 1]);

a.set(\start, 309696);
a.set(\start, 356384);

p = Pbind(
	\type, \set,
	\id, a,
	\args, #[start],
	\start, Pwhite(0, (b[0].numFrames * 0.8).asInteger, inf),
	\dur, Pwhite(1, 4, inf)
).play;


a.trace;

p.stop;
a.free;



// switch to 1 synth per grain: may need different filter characteristics per grain
SynthDef(\klunk, { |bufnum, rate = 1, start = 0, gdur = 0.1,
	fdur = 0.25, ffreqs = #[100, 150, 200], /*flo = 100, fhi = 200,*/
	preamp = 3, pan = 0, amp = 0.1, out = 0|
	var	grainenv = EnvGen.ar(Env.perc(0.01, gdur)),
		sig = PlayBuf.ar(1, bufnum, rate, 0, start) * grainenv;
	sig = Klank.ar(`[
		ffreqs, // { Rand(flo, fhi) } ! 3,
		nil,
		fdur ! ffreqs.size
	], sig);
	sig = (sig * preamp).distort;
	Out.ar(out, Pan2.ar(sig, pan, amp));
	Line.kr(0, 0, gdur + fdur, doneAction: 2);
}).add;

SynthDef(\klunk2, { |bufnum, rate = 1, start = 0, gdur = 0.1,
	fdur = 0.25, ffreqs = #[100, 150, 200], /*flo = 100, fhi = 200,*/
	preamp = 3, pan = 0, amp = 0.1, out = 0|
	var	grainenv = EnvGen.ar(Env.perc(0.01, gdur)),
		sig = PlayBuf.ar(1, bufnum, rate, 0, start) * grainenv,
		fenv = NamedControl.kr(\fenv, (0 ! 20).overWrite(Env.one.asArray)),
		totalDur = gdur + fdur,
		feg = EnvGen.ar(fenv, timeScale: totalDur);
	sig = DynKlank.ar(`[
		ffreqs * feg, // { Rand(flo, fhi) } ! 3,
		nil,
		fdur ! ffreqs.size
	], sig);
	sig = (sig * preamp).distort;
	Out.ar(out, Pan2.ar(sig, pan, amp));
	Line.kr(0, 0, totalDur, doneAction: 2);
}).add;


e = n.play(p = PbindProxy(
	\instrument, \klunk,
	\bufnum, b[0],
	\start, Pwhite(0, (b[0].numFrames * 0.8).asInteger, inf),
	\gdur, 0.1,
	\fdur, 0.25,
	\flo, 100,
	\fhi, 200,
	\preamp, 3,
	\pan, 0,
	\amp, 0.1,
	\delta, sin(Ptime() * 2pi / 20).linlin(-1, 1, 0.05, 0.4)
));

p.set(\amp, 1);
p.set(\fdur, 0.8);

OSCFunc({ |msg| s.sendMsg(\n_trace, msg[1]) }, '/n_go', s.addr).oneShot;

e.stop;


e = n.play(Pstutter(
	Pwhite(5, 16, inf),
	p = PbindProxy(
		\instrument, \klunk,
		\bufnum, b[0],
		\start, Pwhite(0, (b[0].numFrames * 0.8).asInteger, inf),
		\gdur, 0.1,
		\fdur, 0.25,
		\ff, Pwhite(100, 200, inf).clump(3),
		\ffreqs, Pfunc({ |ev| [ev[\ff]] }),
		\preamp, 3,
		\pan, 0,
		\amp, 1,
		\delta, Pwhite(0.09, 0.4, inf)
	)
));

p.set(\ff, Pwhite(70, 150, inf).clump(3));
p.set(\fdur, 0.25);
p.set(\gdur, 0.7);  // long grain dur is actually quite nice
p.set(\gdur, 0.5);
p.set(\gdur, 0.1);  // more percussive

e.stop;


e = n.play(
	Pchain(
		x = PbindProxy(
			\bufnum, b[0],
			\start, Pwhite(0, (b[0].numFrames * 0.8).asInteger, inf),
			\ffreqs, Pfunc({ |ev| [ev[\ff]] }),
			\preamp, 1,
			\pan, 0,
			\amp, 1
		),
		Pseq([
			y = PbindProxy(
				\instrument, \klunk,
				\gdur, 0.1,
				\fdur, 0.25,
				\ff, Pwhite(70, 150, inf).clump(3),
				\delta, Plimitsum({ rrand(1, 4) * 0.5 }, Plazy({ Pn(rrand(0.09, 0.22), inf) }))
			),
			z = PbindProxy(
				\instrument, \klunk2,
				\delta, Pwhite(0.6, 1.2, 1),
				\gdur, Pkey(\delta) * 0.6,
				\fdur, Pkey(\delta),
				\ff, Pwhite(140, 300, inf).clump(3),
				\fenv, Pfunc({
					[Env([rrand(0.8, 0.98), rrand(1.03, 1.4)].rotate(2.rand), #[1], \exp)]
				})
			)
		], inf)
	)//,
	//(protoEvent: ProtoEvent(\singleSynthPlayer).copy)
);

z.set(\gdur, 0.2);
z.set(\fdur, 2.0);

e.stop;


