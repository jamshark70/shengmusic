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

