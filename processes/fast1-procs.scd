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
	~cfreq = Pexprand(200, 800, inf);
	~fwobblefreq = Pwhite(18, 45, inf);
	~fdecay = 3;
	~excratio = 0.01;
	~fattack = 0.1;
	~sustain = 0.9;
	~rwidth = Pwhite(1.01, 3.5, inf);
	~preamp = 3;
	~amp = 0.1;

	~prep = {
		~chan = MixerChannel(~collIndex, s, 2, 2, level: ~mixerLevel, outbus: ~master);
		if(Server.program = "supernova") {
			~targ = ParGroup(~chan.synthgroup);
		} {
			~targ = ~chan.synthgroup;
		};
		~event.putAll((target: ~targ, bus: ~chan.inbus));
		~makeSynthDef.();
		~makeBuffer.();
	};
	~freeCleanup = {
		[~chan, ~buf].free;
	};

	~makeSynthDef = {
		~def = SynthDef(\plink, { |cfreq = 440, width = 0.1, fdecay = 0.7, fwobblefreq = 20, excratio = 0.25, excdecay = 0.1, sustain = 3, fattack = 1, preamp = 3, amp = 0.1, rwidth = 1, out, bufnum|
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
			\cfreq, BPStream(\cfreq),
			\fwobblefreq, BPStream(\fwobblefreq),
			\excratio, BPStream(\excratio),
			\fdecay, BPStream(\fdecay),
			\fattack, BPStream(\fattack),
			\sustain, BPStream(\sustain),
			\rwidth, BPStream(\rwidth),
			\preamp, BPStream(\preamp),
			\amp, BPStream(\amp)
		);
	};
} => PR(\plinks);
)
