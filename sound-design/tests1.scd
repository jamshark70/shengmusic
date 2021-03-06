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


// WrapInstr(\highdrone, { |freq, detuneRatio = 1.003, width = 0.2,
// 	bpDownRatio = 0.2, rq = 0.08, mix = 0.56, lpsrcfreq = 4000, lpfxfreq = 8000,
// 	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01,
// 	gate = 1, vsens = 0.8, env, envScaleUp = 1, envScaleDown = 1|
// 	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
// 		sig = Pulse.ar(freq * [1, detuneRatio], width, amp).sum,
// 		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
// 			.exprange(lpfxfreq * bpDownRatio, lpfxfreq),
// 		filts,
// 		initTrig = Impulse.kr(0),
// 		scale = Select.kr(initTrig, [LocalIn.kr(1), envScaleUp]),
// 		eg = EnvGen.kr(env, gate, timeScale: scale, doneAction: 2);
// 	// switch timescale when env starts going down
// 	var hpz = HPZ1.kr(eg);
// 	scale.poll(initTrig);
// 	hpz.poll(initTrig);
// 	LocalOut.kr(
// 		Select.kr(
// 			PulseCount.kr(hpz < 0) >= 1,
// 			[envScaleUp, envScaleDown]
// 		)
// 	);
// 	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
// 	filts = BPF.ar(sig, ffreqs, rq);
// 	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
// 	sig = XFade2.ar(LPF.ar(sig, lpsrcfreq), LPF.ar(filts, lpfxfreq), mix);
// 	sig * eg;
// }, [\freq, \mydetune, \unipolar, #[0.1, 1.0, \exp], \myrq, \bipolar, \freq, \freq,
// 	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp],
// 	\amp, \unipolar, EnvSpec(Env.adsr), #[0.1, 10, \exp], #[0.1, 10, \exp]
// ]);


// I should NOT have to change it this way
WrapInstr(\highdrone, { |freq, detuneRatio = 1.003, width = 0.2,
	bpDownRatio = 0.2, rq = 0.08, mix = 0.56, lpsrcfreq = 4000, lpfxfreq = 8000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01,
	gate = 1, vsens = 0.8, env, envScaleUp = 1, envScaleDown = 1|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		sig = Pulse.ar(freq * [1, detuneRatio], width, amp).sum,
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfxfreq * bpDownRatio, lpfxfreq),
		filts,
		initTrig = Impulse.kr(0),
		eg_fb = Select.kr(initTrig, [LocalIn.kr(1), 0]),
		// switch timescale when env starts going down
		goingDown = (PulseCount.kr(HPZ1.kr(eg_fb) < 0) >= 1
			+ (gate <= 0)) > 0,
		scale = Select.kr(goingDown, [envScaleUp, envScaleDown]),
		eg = EnvGen.kr(env, gate, timeScale: scale, doneAction: 2);
	LocalOut.kr(eg);
	// scale.poll(HPZ1.kr(scale).abs > 0);
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	sig = XFade2.ar(LPF.ar(sig, lpsrcfreq), LPF.ar(filts, lpfxfreq), mix);
	sig * eg;
}, [\freq, \mydetune, \unipolar, #[0.1, 1.0, \exp], \myrq, \bipolar, \freq, \freq,
	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp],
	\amp, \unipolar, EnvSpec(Env.adsr), #[0.1, 10, \exp], #[0.1, 10, \exp]
]);

v = WrapInstr(\highdrone).miditest(0, initArgs: [env: Env.adsr(0.9, 1.2, 0.8, 1.8), chorusFreq: `0.1, chorusDelay: `0.018, chorusWidth: `0.01, vsens: 0.1, lpsrcfreq: 2800, lpfxfreq: 7000], target: n);

v.trace;

k = MIDIPort.search(v);

k.ccs.last.free;
k.ccs[k.ccs.size-2].free;
v.unmapGlobal(\envScaleDown); v.unmapGlobal(\envScaleUp);

k.noteOnArgsPat = Pbind(
	\envScaleUp, Pkey(\velocity).linlin(0, 127, 3.5, 0.1),
	\envScaleDown, Pkey(\envScaleUp)
);

v.trigger([62, 64].midicps, 0.1, [envScaleUp: 2.4, envScaleDown: 2.4]);

Pbind(
	\type, \voicerNote,
	\voicer, v,
	\root, 2,
	\degree, Pseq(#[
		[-2, 7], [1, 4], [-2, 7], [2, 5, 8], [-2, 7, 11]
	]),
	\dur, Pn(0.35, 4) ++ 3,
	\legato, Pn(1.2, 4) ++ 1,
	\gate, 0.4,
	\envScaleUp, 0.5,
	\envScaleDown, 0.5
).play;

v.release([62, 64].midicps);


TempoClock.default.gui;


(
(
make: { |name|
	var	out;
	~target = MixerChannel(name, s, 2, 2, level: -20.dbamp);
	out = Voicer(20, WrapInstr(\highdrone), [
		env: Env.adsr(0.9, 1.2, 0.8, 1.8), chorusFreq: `0.1, chorusDelay: `0.018,
		chorusWidth: `0.01, vsens: 0.8, lpsrcfreq: 2800, lpfxfreq: 7000,
		mix: 0.3
	], target: ~target);
	// out.mapGlobal(\width, nil, 0.2, #[0.02, 0.98]);
	out.mapGlobal(\rq, nil, 0.08, \myrq);
	// out.mapGlobal(\mix, nil, 0.3, \bipolar);
	~widthCtl = GenericGlobalControl(\width, nil, 0.2, #[0.02, 0.98]);
	out
}, free: { [~target, ~widthCtl].free }, type: \voicer) => Fact(\pulseDrone);
)

VC(\pd).free;
Fact(\pulseDrone) => VC(\pd);
VC(\pd) => VP(0);
VC(\pd) => MCG(2);

k.free;
k = VoicerMIDISocket(0, VP(0).v);

VC(\pd).env.widthCtl.watch.automate({
	LFDNoise1.kr(LFNoise1.kr(0.2).exprange(0.1, 3.0)).range(0.1, 0.8)
}, target: VC(\pd).env.target.synthgroup, addAction: \addToHead);

VC(\pd).env.widthCtl => VP(0);

VC(\pd).env.widthCtl.stopWatching;
VP(0).v.controlProxies[1].gc = nil;

k.noteOnArgsPat = Pbind(\width, VC(\pd).env.widthCtl.asMap);

VC(\pd).v.trace;

VC(\pd).v.trigger(62.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
VC(\pd).v.trigger(64.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);

VC(\pd).v.release([62, 64].midicps);

();
p = Pbind(
	\type, \voicerNote,
	\voicer, VC(\pd).v,
	\root, 2,
	\degree, #[-2, 7, 11],
	\gate, 0.4,
	\dur, Pseq([
		Plazy({
			var x = rrand(2, 6);
			Pn(rrand(max(x-5, 1), max(x-3, 1)) / x, x)
		}), 2
	], inf),
	\legato, Pif(Pkey(\dur) < 2, 0.6, 1),
	\width, Pwhite(0.08, 0.18, inf),
	// \lpsrcfreq, 2000,
	\lpfxfreq, Pexprand(3000, 12000, inf),
	\mix, Pwhite(0.6, 1.0, inf),
	\bpDownRatio, 0.7,
	\envScaleUp, 0.2,
	\envScaleDown, 0.7
).play;

p.stop;


(
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);
	~alwaysReset = true;

	~mode = \d;
	~top = Pfsm([
		#[0, 1],
		Pseq(#[7, 4], 1), #[0, 1].weight(#[1, 3]),
		Pseq(#[7, 8], 1), #[0, 1, 2, 3].weight(#[2, 1, 2, 5]),
		11, #[0, 1],
		11, #[4],
		nil, nil
	]) + 35;
	~degree = Pkey(\top);
	~gate = 0.4;
	~delta = Plazy({
		Pif(Pkey(\top) < 46, rrand(0.4, 0.7), Pwhite(3, 5, inf) * 0.5)
	});
	~length = Pkey(\delta) * Pif(Pkey(\delta) < 1, 0.6, 1);
	~width = Pwhite(0.08, 0.18, inf);
	~lpsrcfreq = 2000;
	~lpfxfreq = Pexprand(3000, 12000, inf);
	~mix = Pwhite(0.6, 1.0, inf);
	~bpDownRatio = 0.7;
	~envScaleUp = 0.2;
	~envScaleDown = 0.7;

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\top, BPStream(\top, resetSource: true),
			\freq, BPStream(\degree, resetSource: true),
			\gate, BPStream(\gate),
			\delta, BPStream(\delta, resetSource: true),
			\length, BPStream(\length),
			\width, BPStream(\width),
			\lpsrcfreq, BPStream(\lpsrcfreq),
			\lpfxfreq, BPStream(\lpfxfreq),
			\mix, BPStream(\mix),
			\bpDownRatio, BPStream(\bpDownRatio),
			\envScaleUp, BPStream(\envScaleUp),
			\envScaleDown, BPStream(\envScaleDown)
		)
	};
} => PR(\brightChords);
)

BP(\bc).free;
PR(\brightChords) => BP(\bc);
VC(\pd) => BP(\bc);
BP(\bc).quant = 0;

BP(\bc) => MT(1);



// bass

~cb = Buffer.alloc(s, 2048, 1);
~mb = Buffer.alloc(s, 2048, 1);

~cb.sine1(#[1]);
~cb.sine1((1..3).reciprocal);

~mb.sine1(#[1]);
~mb.sine1(#[1, 0.5, 0.25]);

WrapInstr("osc2.fm1").listArgs

v = WrapInstr("osc2.fm1").miditest(0, [car_buf: `~cb, mod_buf: `~mb, mod_lev: 0.302, mod_ratio: 0.5, mod_env: Env.adsr(0.01, 0.14, 1/3, 3, 3)], target: m);

Instr("busfx.chorus2").openFile

p = m.playfx(Instr("busfx.chorus2band2"), [0, 1, 3]); p.gui;

p.run(false);
p.run(true);

(
(
keys: #[master],
car_env: nil,
mod_env: Env.adsr(0.01, 0.14, 1/3, 3, 3),
make: { |name|
	var args, out;
	~target = MixerChannel(name, s, 1, 2, /*level: ,*/ outbus: ~master, completionFunc: { |chan|
		~chorus = chan.playfx(Instr("busfx.chorus2band2"), [0, 1, 3, 0.019929544097472, 0.10529309760794, 0.010555364844924, 0.84697339184144, 189.85848040307, 0.5]);
	});
	~cb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
		buf.sine1Msg(#[1]);
	});
	~mb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
		buf.sine1Msg(#[1, 0.5, 0.25]);
	});
	args = [
		car_buf: `~cb, mod_buf: `~mb, /*mod_lev: 0.302,*/ mod_ratio: 0.5,
		mod_env: ~mod_env,
		car_vs: 0.4, mod_vs: 0.7
	];
	if(~car_env.notNil) { args = args ++ [car_env: ~car_env] };
	out = MonoPortaVoicer(1, WrapInstr("osc2.fm1porta"), args, target: ~target);
	out.mapGlobal(\mod_lev, nil, 1.8, #[0.01, 8, \exponential]);
	out.portaTime = 0.3;
	out
},
free: { [~target, ~cb, ~mb].free },
type: \voicer) => Fact(\fmbass);
)

VC(\fmb).free;
Fact(\fmbass) => VC(\fmb);

k = VoicerMIDISocket(0, VP(0).v);

VC(\fmb).v.portaTime = 0.3;


();  // emacs.....
// bell for accents
~cb = Buffer.alloc(s, 2048, 1);
~mb = Buffer.alloc(s, 2048, 1);

~cb.sine1(#[1]);
~cb.sine1(#[1, 0, 0, 0, 0, 0, 0.3]);

~mb.sine1(#[1]);
~mb.sine1(#[1, 0, 0, 0, 1]);

Library.at(WrapInstr, \osc2).keys
WrapInstr("osc2.fm2car").listArgs

v = WrapInstr("osc2.fm2car").miditest(0, [car_buf: `~cb, mod_buf: `~mb, mod_lev: 4.13, detune: 1.63, mod_ratio: 5, car_env: UGenFunc({ Env.perc(0.01, NamedControl(\sustain, 1)) }), mod_env: UGenFunc({ var sus = NamedControl(\sustain, 1); Env(#[0, 1, 0.2], [0.01, sus], -4) })], target: m);

Pdefn(\gate, 0.2);
Pdefn(\gate, 1.0);
Pdefn(\gate, Pwhite(0.2, 1.0, inf));

p = Pbind(
	\type, \voicerNote,
	\voicer, v,
	\root, 2,
	\octave, 6,
	\degree, Pxrand(#[0, 1, 3, 4, 6], inf),
	\dur, 2,
	\sustain, 6,
	\gate, Pdefn(\gate)
).play;

p.stop;


// with spectrum mods, *this* bell is promising

(
WrapInstr("osc2.fm2carV", { arg freq, gate, car_env, mod_env, mod_lev, mod_ratio, detune, car_detune,
	car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale, pan;
	var sig, mod, car_amp, mod_amp, cbeven, cbodd, diff;
	car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
	mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
	* EnvGen.kr(mod_env, gate);
	mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
	mod = VOsc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
	freq = freq * [1, car_detune];

	// car_buf processing, since VOsc can't be used as an FM carrier
	cbeven = car_buf.round(2);
	diff = car_buf - cbeven;
	cbodd = cbeven + sign(diff);

	sig = [cbeven, cbodd].collect { |buf| Osc.ar(buf, freq + (mod * freq), 0, car_amp) };
	sig = XFade2.ar(sig[0], sig[1], diff.fold(0, 1) * 2 - 1);

	sig = Pan2.ar(Mix(sig) * EnvGen.kr(car_env, gate, doneAction:2), pan)
}, [\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential], [1, 12, \linear, 0, 1], [-5, 5, \linear, 0, 0], \mydetune, \mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp], \bipolar]);
)

(
keys: #[master],
make: { |name|
	var	out, carHarmonics = [1, 0.3];

//	VC(name).free;  // this breaks stuff
	~target = MixerChannel(name, s, 2, 2, level: -12.dbamp, outbus: ~master/*, completionFunc: {  }*/);

	~cb = Buffer.allocConsecutive(6, s, 2048, 1);
	~mb = Buffer.allocConsecutive(2, s, 2048, 1);
	// just being EXTRA careful about possible supernova crash
	fork {
		s.sync;
		~cb.scramble.do { |buf|
			buf.sine1(carHarmonics);
			carHarmonics = carHarmonics.insert(1, 0);
		};
		~mb.do(_.sine1(#[1]));  // we need 2 for VOsc
	};

	// WrapInstr("osc2.fm2carpan", { |pan|
	// 	Pan2.ar(WrapInstr.wrap("osc2.fm2car"), pan)
	// }, [\bipolar]);

	out = Voicer(8, WrapInstr("osc2.fm2carV"), [mod_lev: 4.13, mod_ratio: 5, car_detune: `1.00288, car_vs: `0.2697, mod_vs: `0.8, basefreq: `440, keyscale: `0.337, car_buf: UGenFunc({ LFDNoise1.kr(LFNoise1.kr(0.2).range(0.3, 5.0)).range(~cb.first.bufnum, ~cb.first.bufnum + ~cb.size - 1.001) }), mod_buf: `~mb[0], car_env: UGenFunc({ Env.perc(0.01, NamedControl.kr(\sustain, 1)) }), mod_env: UGenFunc({ var sus = NamedControl.kr(\sustain, 1); Env(#[0, 1, 0.2], [0.01, sus], -4) })], target: ~target);
	out.mapGlobal(\detune, nil, 1.63, #[-5, 5]);
	out
},
free: { [~target, ~cb, ~mb].free },
type: \voicer) => Fact(\fmbell);

VC(\fmbell).free;
Fact(\fmbell) => VC(\fmbell);
VC(\fmbell) => VP(0);

VC(\fmbell).v.mapGlobal(\mod_lev, nil, 4.13, #[1, 30, \exp]);

VC(\fmbell).globalControls[\mod_lev].spec = #[1, 30, \exp];

p = Pbind(
	\type, \voicerNote,
	\voicer, VP(0).v,
	\root, 2,
	\octave, 6,
	\degree, Pxrand(#[0, 1, 3, 4, 6], inf),
	\dur, 2,
	\sustain, 6,
	\gate, 0.3
).play;

p.stop;


// would like more attack-iness

(type: \voicerNote, voicer: VP(0).v, root: 2, octave: 6, degree: #[0, 5, 6, 10.1], dur: 2, sustain: 6, gate: 0.3).play
