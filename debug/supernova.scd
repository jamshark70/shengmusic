// buffer init hang

(
Instr(\highdrone, { |freq, detuneRatio = 1.003, width = 0.2,
	bpDownRatio = 0.2, rq = 0.08, mix = 0.56, lpsrcfreq = 4000, lpfxfreq = 8000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01,
	gate = 1, vsens = 0.8, env, envScaleUp = 1, envScaleDown = 1
	bufbase = 0, numbufs = 8, basefreq = 440, topfreq = 12543|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		// big cpu hit with this
		// sig = Pulse.ar(freq * [1, detuneRatio], width, amp).sum,
		// instead, use my buffer-mapping magic trick
		// detuneRatio should be close to 1.0, no need to calculate multiple mappings
		baselog = log2(basefreq),
		freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
			* (numbufs - 1)).clip(0, numbufs - 1.001),
		freqs = freq * [1, detuneRatio],
		// http://www.musicdsp.org/showone.php?id=8
		saw1 = Osc.ar(bufbase + freqmap, freqs, 0, amp),
		saw2 = DelayL.ar(saw1, maxdelaytime: 0.1, delaytime: width / freqs),
		sig = (saw1 - saw2).sum,
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
	\amp, \unipolar, EnvSpec(Env.adsr), #[0.1, 10, \exp], #[0.1, 10, \exp],
	\mybuf, #[1, 16, \lin, 1], \freq, \freq
]);

e = Environment.make {
	// ~target = MixerChannel(name, s, 2, 2, level: -20.dbamp);
	// KABOOM
	~bufs = \makeWavetables.eval(8, s, 1024, 48, { |numharm|
		Array.sawtoothAmps(numharm)
	});

	~patch = Patch(\highdrone, [ nil, nil, nil, nil, nil, KrNumberEditor(0.3, ControlSpec(-1, 1, 'linear', 0.0, 0)), KrNumberEditor(2800, ControlSpec(20, 20000, 'exp', 0, 440)), KrNumberEditor(7000, ControlSpec(20, 20000, 'exp', 0, 440)), KrNumberEditor(0.1, ControlSpec(0.05, 0.5, 'exp', 0.0, 0.05)), KrNumberEditor(0.018, ControlSpec(0.003, 0.05, 'exp', 0.0, 0.003)), KrNumberEditor(0.01, ControlSpec(0.001, 0.04, 'exp', 0.0, 0.001)), KrNumberEditor(0, ControlSpec(0, 1, 'amp', 0, 0)), KrNumberEditor(0.8, ControlSpec(0, 1, 'linear', 0.0, 0)), nil, nil, nil, KrNumberEditor(0, ControlSpec(0, 128, 'linear', 1, 0)), KrNumberEditor(8, ControlSpec(1, 16, 'linear', 1, 1)), KrNumberEditor(130.8127826503, ControlSpec(20, 20000, 'exp', 0, 440)), KrNumberEditor(16744, ControlSpec(20, 20000, 'exp', 0, 440)) ]);
	~patch.asSynthDef.add;

	~fgroup = Group.new;
	~sgroup = Group(~fgroup);
	~fxgroup = Group(~sgroup, \addAfter);
	~psgroup = ParGroup(~sgroup);

// received osc packet { ( 15112690133159280640 )
//   [21 int32:2, int32:1, int32:1]
//   [21 int32:3, int32:1, int32:2]
//   [21 int32:4, int32:1, int32:2]
//   [9 OSC-string:`mixers/Mxb2x2', int32:5, int32:1, int32:2, OSC-string:`busin', int32:16, OSC-string:`busout', int32:0, OSC-string:`pan', OSC-string:`c1', OSC-string:`level', OSC-string:`c0']
//   [/n_set int32:5, OSC-string:`busout', int32:0]
// }

};
)

~patch.free;  // Patch has some dependants


[nil, nil, nil, nil, nil, 0.3, 2800.0, 7000.0, 0.1, 0.018, 0.01, 0.0, 0.8, Env.new([ 0.0, 1.0, 0.8, 0.0 ], [ 0.9, 1.2, 1.8 ], -4.0, 2), nil, nil, 0, 8, 130.8127826503, 16744.0]
.collect { |ag, i|
	if(ag.isNumber) {
		"KrNumberEditor(" ++ ag ++ ", " ++ Instr(\highdrone).specs[i].asCompileString ++ ")"
	}
}.postcs; ""


[ nil, nil, nil, nil, nil, KrNumberEditor(0.3, ControlSpec(-1, 1, 'linear', 0.0, 0)), KrNumberEditor(2800, ControlSpec(20, 20000, 'exp', 0, 440)), KrNumberEditor(7000, ControlSpec(20, 20000, 'exp', 0, 440)), KrNumberEditor(0.1, ControlSpec(0.05, 0.5, 'exp', 0.0, 0.05)), KrNumberEditor(0.018, ControlSpec(0.003, 0.05, 'exp', 0.0, 0.003)), KrNumberEditor(0.01, ControlSpec(0.001, 0.04, 'exp', 0.0, 0.001)), KrNumberEditor(0, ControlSpec(0, 1, 'amp', 0, 0)), KrNumberEditor(0.8, ControlSpec(0, 1, 'linear', 0.0, 0)), nil, nil, nil, KrNumberEditor(0, ControlSpec(0, 128, 'linear', 1, 0)), KrNumberEditor(8, ControlSpec(1, 16, 'linear', 1, 1)), KrNumberEditor(130.8127826503, ControlSpec(20, 20000, 'exp', 0, 440)), KrNumberEditor(16744, ControlSpec(20, 20000, 'exp', 0, 440)) ]
