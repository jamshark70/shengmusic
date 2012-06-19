
var saveSubType = AbstractChuckArray.defaultSubType;

protect {

	// drones
	// a modified karplus-strong approach
	// note the crazy hackery needed for tuning based on filter frequency :O

	WrapInstr("osc.ks_sustained", { |freq = 440, amp = 0.1, ffreq = 2000, 
		excratio = 0.5, excamp = 1, fbamp = 1, pan = 0,
		env, timeScale = 1,
		bufselect, firstbuf = 1, numbufs = 2, detectSilence|
		var frq = freq.dereference.value(),
		delayt = max(0, frq.reciprocal - ControlDur.ir),
		excfreq = frq * excratio.dereference.value(),
		firstbufnum = firstbuf.asUGenInput,  // .bufnum if a Buffer, 'this' if a number
		exc = VOsc.ar(
			bufselect.dereference.value().range(firstbufnum, firstbufnum + numbufs - 1.01),
			excfreq, 0,
			excamp.dereference.value()
		),
		feedback = LocalIn.ar(1),
		gate = 1, eg, gatedEnv;
		// the delay doubles the number of end-to-beginning buffer transitions
		// helps to blur the glitchiness somewhat
		exc = exc + DelayL.ar(exc, 0.05, (excfreq * 2).reciprocal);
		feedback = feedback + exc;
		feedback = LPF.ar(feedback, ffreq);
		feedback = DelayL.ar(feedback, 0.11, delayt, mul: fbamp);
		feedback = LeakDC.ar(feedback);
		LocalOut.ar(feedback);
		env = env.dereference.value();
		gatedEnv = try { env.isSustained } { |err|
			if(env.isKindOf(SequenceableCollection)) { true }
			{ err.throw }
		};
		if(gatedEnv) { gate = NamedControl.kr(\gate, 1) };
		eg = EnvGen.kr(env, gate, timeScale: timeScale, doneAction: 2);
		if(detectSilence == true) {
			DetectSilence.ar(feedback, 0.003, doneAction: 2);
		};
		Pan2.ar(feedback, pan, eg * amp)
	}, [
		\freq, \amp, \freq,
		#[0.1, 1, \exp], \amp, \amp, \bipolar,
		EnvSpec(Env.adsr), #[0.01, 100, \exp],
		ObjectSpec({ SinOsc.kr(Rand(0.08, 0.14)) }), \mybuf, StaticSpec(2, 16, \lin, 1, 2),
		ObjectSpec(false)
	]);

	PR(\abstractProcess).clone {
		~event = (eventKey: \default);
		~requiredKeys = #[sharedReady];
		~prep = {
			~chan = MixerChannel(~collIndex, s, 2, 2,
				level: 0.75,
				outbus: ~master ? topEnvironment[\master] //,
				// completionFunc?
			);
			~event.proto = (group: ~chan.synthgroup, out: ~chan.inbus.index);
			BP(\shengShared).updateWhenReady(~collIndex);
			currentEnvironment
		};
		~freeCleanup = {
			~chan.free;
		};
		~sharedReady_ = { |bool|
			~sharedReady = bool;
			~makeSynthDef.();
		};
		~makeSynthDef = {
			~def = WrapPatch("osc.ks_sustained", [
				nil, nil, nil,
				`{ LFDNoise1.kr(0.9).range(0.5, 1) }, nil, nil, nil,
				`{ NamedControl(\env, Env.adsr.asArray.extend(40, 0)) }, nil,
				`{ LFDNoise1.kr(Rand(0.08, 0.14)) },
				BP(\shengShared).noiseBufs[0], BP(\shengShared).noiseBufs.size
			]).asSynthDef.add;
			~defName = ~def.name.asSymbol;
		};

		~octave = 5;
		~deg = Prand(#[0, 4], inf);
		~degree = Pfunc({ |ev| ev[\deg].dup(3).flat });
		~root = 2;
		~dur = Pseq([Pexprand(0.4, 0.8, { rrand(2, 9) }), Pwhite(1.5, 4.5, 1)], inf);
		~sustain = Pwhite(4.0, 7.0, inf);
		~freqStuff = Pfunc({ |ev|
			// for efficiency: do this only once
			var freq = ev.use({ ~detunedFreq.value });
			[freq, freq.asArray.maxItem]
		});
		~hiProb = 0.01;
		~ffreq = max(
			Pwhite(1600, 2000, inf),
			(Pwhite(3, 6, inf) + Pwhite(0.2, 0.8, inf)) * Pkey(\topFreq)
		) * Pif(Plazy({ BPStream(\hiProb) }).coin, Pexprand(2.0, 3.0, inf), 1);
		~ampFactor =  Pkey(\ffreq).linlin(1600, 12000, 1.0, 0.08);
		~ctranspose = (
			Pwhite(-0.1, 0.1, inf) + Pkey(\fratio).linlin(4, 23, 0.6, 0.051)
		).clump(Pkey(\degree).collect(_.size));
		~pan = Pwhite(0.7, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand });
		~env = [Env.adsr(0.5, 0.6, 0.6, 4)];
		~excamp = 1.2;
		~amp = 0.1;

		~asPattern = {
			Pbind(
				\instrument, BPStream(\defName),
				\octave, BPStream(\octave),
				\deg, BPStream(\deg),
				\degree, BPStream(\degree),
				\root, BPStream(\root),
				\dur, BPStream(\dur),
				\sustain, BPStream(\sustain),
				#[freq, topFreq], BPStream(\freqStuff),
				\ffreq, BPStream(\ffreq),
				\fratio, Pkey(\ffreq) / Pkey(\topFreq),
				\ampFactor, Pkey(\ffreq).linlin(1600, 12000, 1.0, 0.08),
				\ctranspose, BPStream(\ctranspose),
				\pan, BPStream(\pan),
				\env, BPStream(\env),
				\excamp, BPStream(\excamp) * Pkey(\ampFactor),
				\amp, BPStream(\amp)
			)
		};
	} => PR(\shengDrone);
} {
	AbstractChuckArray.defaultSubType = saveSubType;
};