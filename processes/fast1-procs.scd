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



// bleepy filters

(
PR(\abstractProcess).clone {
	~event = (eventKey: \singleSynthPlayer);

	~delta = Pwhite(1, 4, inf) * 0.25;
	~freq = Pexprand(200, 800, inf);
	~fwobblefreq = Pwhite(18, 45, inf);
	~fdecay = 3;
	~excratio = 0.01;
	~fattack = 0.1;
	~sustain = 0.9;
	~rwidth = Pwhite(1.01, 3.5, inf);
	~preamp = 3;
	~amp = 0.1;
	~pan = 0;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, level: ~mixerLevel, outbus: ~master,
			completionFunc: { |chan|
				if(Server.program == "supernova") {
					~targ = ParGroup(chan.synthgroup);
				} {
					~targ = chan.synthgroup;
				};
				~event.putAll((target: ~targ, bus: chan.inbus));
			});
		~makeSynthDef.();
		~makeBuffer.();
	};
	~freeCleanup = {
		[~chan, ~buf].free;
	};

	~makeSynthDef = {
		~def = SynthDef(\plink, { |freq = 440, width = 0.1, fdecay = 0.7, fwobblefreq = 20, excratio = 0.25, excdecay = 0.1, excbeats = 0, sustain = 3, fattack = 1, preamp = 3, amp = 0.1, rwidth = 1, pan = 0, chfreq = 0.1, delaywidth = 0.02, delayctr = 0.02, apdecay = 0.4, out, bufnum|
			var	initTrig = Impulse.kr(0),
				oneOverRw = rwidth.reciprocal,
				num = 6,
				ratios = { ExpRand(oneOverRw, rwidth) } ! num,
				// ratios = (rwidth-1) * (0.0, 1/(num-1) .. 1.0) + 1,
				realfreq = Decay.kr(initTrig, fdecay, LFNoise1.kr(fwobblefreq, width), 1) * freq,
				exc = COsc.ar(bufnum, realfreq * excratio, excbeats)
					* Decay2.kr(initTrig, 0.01, excdecay),
				sig = Formlet.ar(exc, realfreq * ratios, fattack, sustain).sum;
			sig = (sig * preamp).distort * amp;
			sig = sig + AllpassL.ar(sig, 0.05, SinOsc.kr(chfreq, Rand(0, pi), delaywidth, delayctr), apdecay);
			DetectSilence.ar(sig, doneAction: 2);
			Out.ar(out, Pan2.ar(sig, pan))
		}).add;
	};

	~makeBuffer = {
		~buf !? { ~buf.free };
		~buf = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, wait: -1);
	};

	~asPattern = {
		Pbind(
			\instrument, ~def.name,
			\bufnum, ~buf,
			\delta, BPStream(\delta),
			\freq, BPStream(\freq),
			\fwobblefreq, BPStream(\fwobblefreq),
			\excratio, BPStream(\excratio),
			\fdecay, BPStream(\fdecay),
			\fattack, BPStream(\fattack),
			\sustain, BPStream(\sustain),
			\rwidth, BPStream(\rwidth),
			\preamp, BPStream(\preamp),
			\amp, BPStream(\amp),
			\pan, BPStream(\pan)
		);
	};
} => PR(\plinks);
)

BP(\pl).free;
PR(\plinks).chuck(BP(\pl), nil, (master: ~master));
1 => BP(\pl);

TempoClock.tempo = 104/60;

p = BP(\pl);
p.sustain = 0.9 / Ptempo();

p.delta = Pn(
	Pconst({ rrand(2, 3) }, Pwrand(#[0.25, 0.5, 0.75, 1], #[0.05, 0.4, 0.35, 0.2], inf)),
	inf
);

// basic flow works; needs more rhythmic control

p.event.parent  // is nil, can change
p.event.eventKey = \polySynthPlayer;

// check by midi
d = SynthDescLib.at(\plink).def;
d.allControlNames.collect(_.name)
d.metadata

d.metadata = (
	midiControls: #[width, /*fdecay,*/ excdecay, /*excbeats, excratio, sustain, fattack,*/ preamp, rwidth, chfreq, delaywidth, delayctr, apdecay],
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
		rwidth: [4/5, 5/4, \exp, 0, 1],
		pan: \bipolar,
//		out: BP(\pl).chan.inbus.index,
		bufnum: BP(\pl).buf,
		chfreq: #[0.01, 10, \exp, 0, 0.1],
		delaywidth: #[0.001, 0.025, \exp, 0, 0.02],
		delayctr: #[0.001, 0.025, \exp, 0, 0.02],
		apdecay: #[0.01, 2.0, \exp, 0, 0.1]
	)
);

v.trace;
v.playingNodes.do(_.free);

v = d.miditest(0, target: BP(\pl).targ, bus: BP(\pl).chan.inbus);
k = MIDIPort.search(v);
k.noteOnArgsPat = Pbind(\amp, Pkey(\velocity).linlin(0, 127, 0.1, 0.5), \fwobblefreq, Pexprand(20, 45, inf), \excratio, Pwhite(2, 15, inf).reciprocal + rrand(0.002, 0.008), #[fattack, sustain], (Pkey(\midinote).linlin(38, 84, 0.08, 0.02) * #[1, 1.1]));

k.noteOnArgsPat = Pbind(\amp, Pkey(\velocity).linlin(0, 127, 0.1, 0.5), \fwobblefreq, Pexprand(20, 45, inf), \excratio, Pwhite(2, 15, inf).reciprocal/* + rrand(0.002, 0.008)*/, #[fattack, sustain], (Pkey(\midinote).linlin(38, 84, 0.08, 0.02) * #[1, 1.1]));

// excratio off-integer denominators is interesting ^^ if noise osc sustains thru
// fatk/sustain needs some tuning but getting close

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
