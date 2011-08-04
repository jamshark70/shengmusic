~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);
s.addr = ~debugAddr;
s.addr = ~saveAddr;

\supernova.eval;

BP.loadGui;

~master = MixerChannel(\master, s, 2, 2, level: -20.dbamp);
~master => MCG(7);

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2, outbus: ~master);
m => MCG(0); n => MCG(1);
)


// try some squirrelly filters
b = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, wait: -1);

a = m.play { |preamp = 3, amp = 0.1|
	var	initTrig = Impulse.kr(0),
		cfreq = ExpRand(400, 1100),
		width = Rand(0.1, 0.4),
		freq = Decay.kr(initTrig, 1.2, LFNoise1.kr(Rand(5, 15), width), 1) * cfreq,
		exc = Osc.ar(b, cfreq * 0.25) * Decay2.kr(initTrig, 0.01, 0.1),
		sig = Ringz.ar(exc, freq, 3);
	sig = (sig * preamp).distort * amp;
	DetectSilence.ar(sig, doneAction: 2);
	sig
};

fork {
	var c = Condition.new, of;
	a = m.play { |amp = 0.1|
		var	initTrig = Impulse.kr(0),
			cfreq = ExpRand(400, 1100),
			width = Rand(0.1, 0.4),
			freq = Decay.kr(initTrig, 0.25, LFNoise1.kr(Rand(2, 8), width), 1) * cfreq,
			exc = Osc.ar(b, cfreq, 0, amp) * Decay2.kr(initTrig, 0.01, 0.1),
			sig = Ringz.ar(exc, freq, 0.8);
		sig = Limiter.ar(sig);
		DetectSilence.ar(sig, doneAction: 2);
		sig
	};
	of = OSCFunc({ |msg|
		if(msg[1] == a.nodeID) { of.free; c.unhang }
	}, '/n_go', s.addr);
	c.hang;
	a.trace;
};


SynthDef(\bzz, { |cfreq = 440, width = 0.1, fdecay = 0.7, fwobblefreq = 20, excratio = 0.25, excdecay = 0.1, sustain = 3, fattack = 1, preamp = 3, amp = 0.1, rwidth = 1, out, bufnum|
	var	initTrig = Impulse.kr(0),
		oneOverRw = rwidth.reciprocal,
		ratios = { ExpRand(oneOverRw, rwidth) } ! 6,
		freq = Decay.kr(initTrig, fdecay, LFNoise1.kr(fwobblefreq, width), 1) * cfreq,
		exc = Osc.ar(bufnum, cfreq * excratio) * Decay2.kr(initTrig, 0.01, excdecay),
		sig = Formlet.ar(exc, freq * ratios, fattack, sustain).sum;
	sig = (sig * preamp).distort * amp;
	DetectSilence.ar(sig, doneAction: 2);
	Out.ar(out, sig)
}).add;

Pdefn(\delta, 1); // (Pexprand(0.2, 1.2, inf));
Pdefn(\cfreq, Pexprand(200, 800, inf));
Pdefn(\fwobblefreq, Pwhite(18, 45, inf));
Pdefn(\fdecay, 3);
Pdefn(\excratio, 0.01);
Pdefn(\fattack, 0.1);
Pdefn(\sustain, 0.9);
Pdefn(\rwidth, sin(Ptime() * 2pi / 10) * 1.5 + 2.5);

Pdefn(\excratio, 10 / Pkey(\cfreq));

~pg = ParGroup.new;

p = m.play(Pbind(
	\instrument, \bzz,
	\bufnum, b,
	\delta, Pdefn(\delta),
	\cfreq, Pdefn(\cfreq),
	\fwobblefreq, Pdefn(\fwobblefreq),
	\excratio, Pdefn(\excratio),
	\fdecay, Pdefn(\fdecay),
	\fattack, Pdefn(\fattack),
	\sustain, Pdefn(\sustain),
	\rwidth, Pdefn(\rwidth),
	\group, ~pg //,
//	\amp, -40.dbamp
));

p.stop;

s.sendMsg(\n_trace, 1002);
(1000..1002).do(s.sendMsg(\n_free, _));

x = Pdefn(\rwidth).source.asStream;
x.next;


