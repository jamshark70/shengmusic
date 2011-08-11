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

\chuckIf.eval(ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 2), Mode, \d);



// bleepy filters

(
PR(\abstractProcess).clone {
	~event = (eventKey: \polySynthPlayer);
	~alwaysReset = true;
	~printStopMsg = false;

	~delta = Pwhite(1, 4, inf) * 0.25;
	~mode = \d;
	~degree = Pwhite(28, 42, inf);
	~freq = Pfunc({ |ev| ev[\mode].asMode.cps(ev[\degree]) });
	~fwobblefreq = Pwhite(18, 45, inf);
	~fdecay = 0.7;
	~excratio = 0.25;
	~sustain = 0.9;
	~rwidth = Pwhite(1.01, 3.5, inf);
	~preamp = 3;
	~amp = 0.1;
	~pan = 0;

	// don't flop
	~fltenv = Pfunc({ |ev|
		ev[\degree].unmapMode(ev[\mode]).linlin(38, 84, 0.08, 0.02) *.t #[1, 1.1];
	});
	~excbeats = 0.65;
	~apdecay = 0.1;
	~trailRq = 0.02;
	~trailAmp = 8;

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
		~def = SynthDef(\plink, { |freq = 440, width = 0.1, fdecay = 0.7, fwobblefreq = 20, excratio = 0.25, sustain = 1, excbeats = 0, fltdecay = 0.1, fattack = 0.05, preamp = 3, amp = 0.1, pan = 0, chfreq = 0.1, delaywidth = 0.02, delayctr = 0.02, apdecay = 0.4, trailRq = 0.02, trailAmp = 1, out, bufnum|
			var	initTrig = Impulse.kr(0),
				realfreq = Decay.kr(initTrig, fdecay, LFNoise1.kr(fwobblefreq, width), 1) * freq,
				exc = COsc.ar(bufnum, realfreq * excratio, excbeats)
					* Decay2.kr(initTrig, 0.01, sustain),
				sig = (exc * 0.12) + Formlet.ar(exc, realfreq, fattack, fltdecay),
				trails, trailSweep;
			sig = (sig * preamp).distort * amp;
			// little phase messiness, slightly reverb-y
			sig = sig + AllpassL.ar(sig, 0.05, SinOsc.kr(chfreq, Rand(0, pi), delaywidth, delayctr), apdecay);
			trailSweep = XLine.kr(freq * Rand(2.0, 5.0), min(15000, freq * Rand(7.0, 12.0)),
				max(sustain, fltdecay));
			// a little bizarro upper-frequency nonsense, stereo-spread
			trails = BPF.ar(sig, trailSweep * (0.8, 0.9 .. 1.2), trailRq);
			DetectSilence.ar(sig + trails[0], 0.001, doneAction: 2);
			trails = Pan2.ar(trails, { Rand(-1.0, 1.0) } ! (trails.size)).sum;
			trails = Limiter.ar(trails) * trailAmp;
			Out.ar(out, Pan2.ar(sig, pan) + trails)
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
			\mode, BPStream(\mode),
			\degree, BPStream(\degree),
			\freq, BPStream(\freq),
			\fwobblefreq, BPStream(\fwobblefreq),
			\excratio, BPStream(\excratio),
			\fdecay, BPStream(\fdecay),
			\sustain, BPStream(\sustain) / Ptempo(),
			\preamp, BPStream(\preamp),
			\amp, BPStream(\amp),
			\pan, BPStream(\pan),
			#[fattack, fltdecay], BPStream(\fltenv),
			\excbeats, BPStream(\excbeats),
			\apdecay, BPStream(\apdecay),
			\trailRq, BPStream(\trailRq),
			\trailAmp, BPStream(\trailAmp)
		);
	};

	~reset = Func(\resetBPStreams).v;
} => PR(\plinks);
)

TempoClock.tempo = 104/60;

BP(\pl).free;
PR(\plinks).chuck(BP(\pl), nil, (master: ~master));
1 => BP(\pl);

p = BP(\pl);

p => MCG(2);
p =>.60 MT(1);

// why doesn't the frakkin' Func fire here? - ah, isFunction == false
p.reset = Func(\resetBPStreams).v;

p.delta = Pseq([1.5, 2.5], 1);

p.alwaysReset = true;

// don't get bass from here!
p.degree = #[/*19,*/ 26, 33, 42, 46];

// 'k, i'll buy that
p.degree = Ptuple([
	Pseq(#[
		26, 26, 27, 28, 29, 30,
		26, 26, 27, 28, 29, 30, 31.5
	], 1) + #[0, 7],
	42, 46
], 1).collect(_.flat);
p.delta = Pseq(#[
	1.5, 2.5, 1.5, 1.5, 1, 4,
	2, 1, 1.5, 1.5, 2, 0.5, 0.5
], 1);

p.amp = 0.3

// has potential... hit accent points?
p.degree = Prand(#[42, [40, 43]], inf);
p.delta = Pwrand(#[0.5, 0.75], #[0.35, 0.65], inf);


SynthDescLib.at(\plink).controls.do { |cn| cn.name.postln }; ""

// try sweeping down in 16ths - quite useful, esp. modulating sustain
b = Buffer.sendCollection(s, Signal.fill(1024, { 1.0.rand2 }).asWavetable, wait: -1);

(
p = n.play(Pbind(
	\instrument, \plink,
	\freq, Env(#[900, 400], #[4], 2).asStream * (0.8, 0.9 .. 1.2),
	\width, 0,
	\excratio, Pkey(\freq) * (2.sqrt / 500),
	\sustain, Env(#[0.1, 1.2, 0.1], #[3, 1], #[4, -4]).asStream / Ptempo(),
	\excbeats, 0.65,
	\fltdecay, 0.02,
	\fattack, 0.01,
	\preamp, 4,
	\amp, 0.1,
	\pan, 0,
	// \chfreq
	// \delaywidth
	// \delayctr
	\apdecay, 0.1,
	\trailRq, 0.004,
	\trailAmp, 1,
	\bufnum, b,
	\delta, Pn(0.25, 16)
), (quant: 1));
// u.remove;
// u = Updater(p, { |... args| args.postln });
)



// bass

WrapInstr("osc2.fm1ramp", { |freq, freqlag|
	WrapInstr.wrap("osc2.fm1", [Ramp.kr(freq, freqlag)])
}, [\freq, \unipolar]);

(
VC(\qb).free;
Fact(\fmbass).chuck(VC(\qb), nil, (
	// car_env: Env()
	instr: "osc2.fm1ramp"
));
)

TempoClock.default.tempo = 104/60;

p = Pbind(
	\type, \voicerNote,
	\voicer, VC(\qb).v,
	\degree, Pseq(#[-2, -9], inf),
	\freqlag, 0.6 / Ptempo(),
	\dur, Pseq(#[0.5, 1], inf),
	\sustain, Pseq(#[0.7, 0.55], inf),
	\gate, 0.5
).play(quant:1);

p.stop;

VC(\qb).v.gate(47.midicps, 1, 0.5);

MIDIRecBuf(\fastbs1, [
	[	47, 35, 47, 49, 50, 40, 42,
		47, 35, 47, 49, 50, 52, 40, 42, 44
	],
	// perceived rhythm is 1, 0.5 but I have to start the slide early
	[	0.5, 1, 2.5, 1.5, 1.5, 1, 4,
		// same here: 1.5, 0.5
		1, 1, 1, 1.5, 1.5, 1, 1, 0.5, 3.5
	],
	[	0.6, 0.7, 0.2, 0.2, 0.2, 0.2, 0.2,
		1.1, 0.7, 0.2, 0.2, 0.2, 1.1, 0.7, 0.2, 0.2
	],
	0.5
].asNotes, (type: \mel)) => MBM(0);

BP(\qb).free;
PR(\mel1).chuck(BP(\qb), nil, (repeats: 1, printStopMsg: false, alwaysReset: true));
VC(\qb) => BP(\qb);
1 => BP(\qb);
//BP(\qb).alwaysReset = true;

MBM(0)[\fastbs1] => BP(\qb);

// I wish I knew why I had to fudge it like this...
VC(\qb).v.portaTime = 0.4 / (104/60);

Instr("osc2.fm1porta").openFile

b.free;

Voicer(30, \pf, target: n) => VC(\pf);
VC(\pf).mapGlobal(\amp, nil, 0.1, \amp);
VC(\pf).mapGlobal(\transpose, nil, 0, #[-12, 12, \lin, 1, 0]);

socket.noteOnArgsPat = Pbind(\vel, Pkey(\velocity).linlin(0, 127, 30, 127));
