BP.loadGui;

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2);
n = MixerChannel(\test2, s, 2, 2);
m => MCG(0); n => MCG(1);
)


// some drones, to blend with sheng

a = m.play {
	Pulse.ar(440 * [1, 1.003], width: 0.2).sum
}.play;

a.free;


// hmmm... http://www.musicdsp.org/showone.php?id=8

a = m.play { Pulse.ar(440, 0.5) };

a = m.play {
	var	saw = Saw.ar(440),
		width = SinOsc.ar(0.1, 0, 0.4, 0.5),
		delay = width * 440.reciprocal;
	saw - DelayL.ar(saw, 0.2, delay)
};

a.free;

Server.default = Server.internal;
Server.default.makeGui;
Server.default.scope;

a = {
	var	saw = Saw.ar(110 * [1, 1.003]).sum,
		width = SinOsc.ar(0.1, 0, 0.4, 0.5),
		delay = width * 110.reciprocal;
	// still seems to have DC
	LeakDC.ar(saw - DelayL.ar(saw, 0.2, delay)) ! 2
}.play;

a.free;

Server.default = Server.local;


// will use Pulse for now but above may work with VOsc3!

g = GenericGlobalControl(\width, nil, 0.5); g => VP(0);
h = GenericGlobalControl(\rq, nil, 0.5, \myrq); h => VP(0);
i = GenericGlobalControl(\mix, nil, 0, \bipolar); i => VP(0);
j = GenericGlobalControl(\lpfreq, nil, 4000, \freq); j => VP(0);

a = n.play({ |width = 0.5, rq = 0.5, mix = 0, lpfreq = 4000|
	var	sig = Pulse.ar(62.midicps * [1, 1.003], width).sum,
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfreq * 0.2, lpfreq),
		filts;
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(0.1, 0, 0.01, 0.018));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	sig = XFade2.ar(sig, filts, mix);
	LPF.ar(sig, lpfreq)
}, [width: g.asMap, rq: h.asMap, mix: i.asMap, lpfreq: j.asMap]);

a.trace;

a.free;

[j, i, h, g].free


WrapInstr(\highdrone, { |freq, detuneRatio = 1.003, width = 0.2,
	bpDownRatio = 0.2, rq = 0.08, mix = 0.56, lpfreq = 4000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01,
	gate = 1, vsens = 0.8, env|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		sig = Pulse.ar(freq * [1, detuneRatio], width, amp).sum,
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfreq * bpDownRatio, lpfreq),
		filts,
		eg = EnvGen.kr(env, gate, doneAction: 2);
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	sig = XFade2.ar(sig, filts, mix);
	LPF.ar(sig, lpfreq) * eg;
}, [\freq, \mydetune, \unipolar, #[0.1, 1.0, \exp], \myrq, \bipolar, \freq,
	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp],
	\amp, \unipolar, EnvSpec(Env.adsr)
]);

WrapInstr(\highdrone).miditest(0, initArgs: [env: Env.adsr(0.4, 0.8, 0.6, 0.9)], target: n);