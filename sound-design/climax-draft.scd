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


// metered rhythm blows up at giant chord

// bass
BP(\sd).free;
PR(\shengDrone) => BP(\sd);
0 => BP(\sd);
p = BP(\sd);

p.gestures[\midRest] = Pbind(\dur, Rest(4));  // use setGstNow to interrupt

p.gst = \midRest;

p.gestures[\bmin] = Pbind(
	\totalDur, 6,
	\dur, Pn(0.5, 12),
	\sustain, 0.4, // max(0.5, Pkey(\totalDur) - Ptime()),
	\octave, 3,
	\deg, Pseq([-2, 2, 5, 9, 11, 15, Pxrand(#[5, 9, 11, 15], inf)]),
	\amp, 0.25
);

p.gesture.postcs;

p.gst = Pn(\bmin, 1);
p.gestureNow(Pn(\bmin, 1));  // perfect, starts with rests, plays, then re-rests

p.gestures[\gmaj] = Pbind(
	\dur, Pseq([
		Pn(0.5, 8),
		Pexprand(0.8, 1.25, inf) * Pseg(
			Pseq([0.3, 0.9], inf),
			Pwhite(2.5, 6.0, inf),
			\exp
		)
	]),
	\sustain, Pwhite(0.25, 0.5, inf),
	\octave, 3,
	\deg, Pseq([-4, 0, 3, 7, 11, 12,
		Pseq([
			Pxrand(#[16, 18, 22, 11, 13, 7], { rrand(3, 7, inf) }),
			Pseq(#[-4, 0, 3], 1)
		], inf)
	]),
	\amp, 0.25
);

p.gst = \midRest;
p.setGstNow(Pn(\midRest, inf));

p.setGstNow(Pseq(#[bmin, gmaj]));

p.gestures[\gmaj].asStream.next(())

p.makeStreamForKey(\gesture);




// rhythmic, then a-rhythm pizzes
VC(\pzrhy).free;
Fact(\pizz).chuck(VC(\pzrhy), nil, (
	trigFunc: `{
		var beatsPerSec = NamedControl.kr(\beatsPerSec, 100/60),
		baseValue = NamedControl.kr(\baseValue, 0.25),
		lfoDepth = NamedControl.kr(\lfoDepth, 1),
		baseFreq = beatsPerSec / baseValue,
		lfo = LFDNoise1.kr(LFNoise1.kr(Rand(0.05, 0.09)).exprange(0.3, 1.4))
		.exprange(lfoDepth.reciprocal, lfoDepth),
		trig = Impulse.kr(baseFreq * lfo);
		trig
	}
));

(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98).play;

(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1.8, sustain: 5, amp: 1).play;

(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1.8, sustain: 5, amp: 1, degree: #[0, 1, 3, 4]).play;

// promising
// should slide lfoDepth: use global control

Pseq([
	(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1, sustain: 5, amp: 1, degree: #[0, 1, 3, 4], dur: 5, retrigProb: 0.8),
	(type: \voicerNote, voicer: VC(\pzrhy).v, fbamp: 0.98, lfoDepth: 1.8, sustain: 5, amp: 1, degree: #[0, 1, 3, 4], retrigProb: 0.8)
]).play;
