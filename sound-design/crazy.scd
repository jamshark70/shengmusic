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

a.free;
