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
			new.sendCollection(Signal.fill(1024, { 1.0.rand2 }), action: { c.unhang });
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