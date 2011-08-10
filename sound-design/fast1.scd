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



(
SynthDef(\plink, { |freq = 440, width = 0.1, fdecay = 0.7, fwobblefreq = 20, excratio = 0.25, excdecay = 0.1, excbeats = 0, sustain = 3, fattack = 1, preamp = 3, amp = 0.1, /*rwidth = 1,*/ pan = 0, chfreq = 0.1, delaywidth = 0.02, delayctr = 0.02, apdecay = 0.4, trailRq = 0.02, trailAmp = 1, out, bufnum|
	var	initTrig = Impulse.kr(0),
		// oneOverRw = rwidth.reciprocal,
		// num = 6,
		// ratios = { ExpRand(oneOverRw, rwidth) } ! num,
		// ratios = (rwidth-1) * (0.0, 1/(num-1) .. 1.0) + 1,
		realfreq = Decay.kr(initTrig, fdecay, LFNoise1.kr(fwobblefreq, width), 1) * freq,
		exc = COsc.ar(bufnum, realfreq * excratio, excbeats)
			* Decay2.kr(initTrig, 0.01, excdecay),
		sig = Formlet.ar(exc, realfreq /** ratios*/, fattack, sustain), //.sum,
		trails, trailSweep;
	sig = (sig * preamp).distort * amp;
	sig = sig + AllpassL.ar(sig, 0.05, SinOsc.kr(chfreq, Rand(0, pi), delaywidth, delayctr), apdecay);
	trailSweep = XLine.kr(freq * Rand(2.0, 5.0), min(15000, freq * Rand(7.0, 12.0)),
		max(sustain, excdecay));
	trails = BPF.ar(sig, trailSweep * (0.8, 0.9 .. 1.2), trailRq);
	DetectSilence.ar(sig + trails[0], doneAction: 2);
	trails = Pan2.ar(trails, { Rand(-1.0, 1.0) } ! (trails.size)).sum;
	trails = Limiter.ar(trails) * trailAmp;
	Out.ar(out, Pan2.ar(sig, pan) + trails)
}, metadata: (
	midiControls: #[width, /*fdecay,*/ excdecay, /*excbeats, excratio, sustain, fattack,*/ preamp, /*rwidth,*/ chfreq, /*delaywidth, delayctr,*/ apdecay, trailDecay],
	specs: (
		width: \unipolar,
		fdecay: #[0.01, 2.0, \exp, 0, 0.7],
		fwobblefreq: #[1, 50, \lin, 0, 20],
		excratio: #[0.01, 1.0, \exp, 0, 0.25],
		excdecay: #[0.01, 5.0, \exp, 0, 0.1],
		excbeats: #[0, 8],
		sustain: #[0.005, 10, \exp, 0, 3],
		fattack: #[0.005, 10, \exp, 0, 1],
		preamp: #[0.05, 20, \exp, 0, 3],
//		amp: \amp,
//		rwidth: [4/5, 5/4, \exp, 0, 1],
		pan: \bipolar,
//		out: BP(\pl).chan.inbus.index,
		bufnum: b, // BP(\pl).buf,
		chfreq: #[0.01, 10, \exp, 0, 0.1],
		delaywidth: #[0.001, 0.025, \exp, 0, 0.02],
		delayctr: #[0.001, 0.025, \exp, 0, 0.02],
		apdecay: #[0.01, 2.0, \exp, 0, 0.1],
		trailDecay: #[0.1, 10, \exp, 0, 0.5],
		trailAmp: \amp
	)
)).add;
)

v = SynthDescLib.at(\plink).def.miditest(0, target: n);
k = MIDIPort.search(v);
k.noteOnArgsPat = Pbind(\amp, Pkey(\velocity).linlin(0, 127, 0.1, 0.5), \fwobblefreq, Pexprand(20, 45, inf), \excratio, Pwhite(2, 15, inf).reciprocal + rrand(0.002, 0.008), #[fattack, sustain], (Pkey(\midinote).linlin(38, 84, 0.08, 0.02) * #[1, 1.1]));

k.noteOnArgsPat = Pbind(\amp, Pkey(\velocity).linlin(0, 127, 0.1, 0.5), \fwobblefreq, Pexprand(20, 45, inf), \excratio, Pwhite(2, 15, inf).reciprocal/* + rrand(0.002, 0.008)*/, #[fattack, sustain], (Pkey(\midinote).linlin(38, 84, 0.08, 0.02) * #[1, 1.1]), \trailAmp, Pkey(\amp) * 8);


\width, 0.50393700787402, 
\fdecay, 0.7, 
\sustain, 0.4755162406834, 
\fattack, 0.1, 
\preamp, 3.6596384941205, 
\rwidth, 1.0231043297477, 

v.set([\width, 0, 
\fdecay, 0.7, 
\excdecay, 1.7893019105926, 
\sustain, 0.11560912813836, 
\fattack, 0.1, 
\preamp, 3, 
\rwidth, 1]);

\width, 0, 
\fdecay, 0.7, 
\excdecay, 1.8790371130712, 
\sustain, 0.01558923793285, 
\fattack, 0.0080706572110651, 
\preamp, 3, 
\rwidth, 1, 
