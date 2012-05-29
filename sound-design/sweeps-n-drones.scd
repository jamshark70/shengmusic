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
