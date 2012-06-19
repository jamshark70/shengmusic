
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
				// I see... because I hacked \freq above,
				// I need to reapply ctranspose here
				\freq, Pkey(\freq) * Pkey(\ctranspose).midiratio,
				\pan, BPStream(\pan),
				\env, BPStream(\env),
				\excamp, BPStream(\excamp) * Pkey(\ampFactor),
				\amp, BPStream(\amp)
			)
		};
	} => PR(\shengDrone);

	// should abstract this into a general spawner prototype
	PR(\basicSynthChooser).clone {
		// ~event = (eventKey: \singleSynthPlayer);
		~requiredKeys = #[sharedReady];

		~userprep = {
			BP(\shengShared).updateWhenReady(~collIndex);
			currentEnvironment
		};
		~sharedReady_ = { |bool|
			~sharedReady = bool;
			~bufs = BP(\shengShared).noiseBufs;
			~setBPStreams.();
		};
		~setBPStreams = {
			currentEnvironment.env.keys.do { |key|
				if(key.envirGet.isPattern) {
					~makeStreamForKey.(key);
				};
			};
		};

		// Plazy guarantees that we are in the BP's environment
		// at the time of making Pfunc
		// so we can use the BP's environment variables
		~synth = Plazy({ Pfunc({ ~objects.keys.choose }) });

		// unlike basicSynthChooser, it's your responsibility
		// to BPStream child patterns
		~objects = (
			klinks: (
				def: SynthDef(\klinks, { |out, bufnum, amp = 0.1,
					excfreq = 100, excAtk = 0.01, excDcy = 0.05,
					klAtk = 0, klDcy = 1,
					pan = 0|
					var exc = Osc.ar(bufnum, excfreq, 0, amp) * Decay2.ar(
						Impulse.ar(0), excAtk, excDcy),
					specs = NamedControl.kr(\specs, #[621.62188989246, 458.28750962083, 483.12690995039, 1341.4332586515, 229.71349364755, 0.1, 0.1, 0.1, 0.1, 0.1, 0.16730279340267, 0.039352280429134, 0.13997095946335, 0.030161787383422, 0.14313835788342]).clump(5),
					sig = Klank.ar(`specs, exc, decayscale: klDcy) - Klank.ar(`specs, exc, decayscale: klAtk);
					DetectSilence.ar(sig, doneAction: 2);
					Out.ar(out, Pan2.ar(sig, pan));
				}),
				pattern: Pbind(
					\bufnum, Plazy({ ~klbufnumStream.next.loop }),
					\klAtk, BPStream(\klAtk),
					\klDcy, BPStream(\klDcy),
					\excfreq, Plazy({ ~excfreqStream.next.loop }),
					\specs, Plazy({ ~specsStream.next.loop }),
					\ampFactor, BPStream(\klampFactor)
				)
			),
			zzip: (
				def: SynthDef(\zzip, { |out, bufnum, freq = 440, dtune = 1.003,
					hpfreq = 800, hprq = 1,
					amp = 0.1, gate = 1, pan = 0|
					var sig = VOsc3.ar(bufnum, freq / dtune, freq, freq * dtune, amp),
					env = NamedControl.kr(\env, Env.asr(0.02, 1, 0.02).asArray.extend(32, 0));
					sig = RHPF.ar(sig, hpfreq, hprq);
					Out.ar(out, Pan2.ar(sig, pan, EnvGen.kr(env, gate, doneAction: 2)));
				}),
				pattern: Pbind(
					\bufnum, Plazy({ ~zzbufnumStream.next.loop }),
					\sustain, BPStream(\sustain),
					\freq, BPStream(\freq),
					\hpfreq, Plazy({ ~hpfreqStream.next.loop }),
					\hprq, Plazy({ ~hprqStream.next.loop }),
					\env, Plazy({ ~envStream.next.loop }),
					\ampFactor, BPStream(\zzampFactor)
				)
			)
		);

		~durBase = Pwhite(0.09, 0.41, inf);
		~dur = Plazy({ ~durBaseStream.next.loop }) * Pwrand(#[1, 2], #[0.85, 0.15], inf);
		~pan = Pwhite(-1.0, 1.0, inf);
		~phraseDur = Pwhite(3.0, 7.0, inf);
		~waitTime = Pwhite(1.0, 4.0, inf);

		~ampTemplate = Array.fill(5, 0.5);
		~freqTemplate = (3..15);
		~klbufnum = Plazy({ Prand(~bufs, inf) });
		~klAtk = 0.3;
		~klDcy = 0.5;
		~excfreq = Pexprand(300, 900, inf);
		~specs = Plazy({
			Pfunc({ [[
				(#[1, 2] ++ ~freqTemplate.scramble.keep(3)) * #[62, 69].choose.midicps,
				~ampTemplate,
				Array.fill(5, { exprand(0.02, 0.2) })
			].flat] });
		});
		~klampFactor = -3.dbamp;

		~zzbufnum = Plazy({ ~bufs[0].bufnum + Pwhite(0.0, ~bufs.size - 1.01) });
		~sustain = 0.07;
		~freq = Pexprand(25, 38);
		~hpfreq = (Prand(#[62, 69], inf) + (12 * Pwhite(2, 6))).midicps;
		~hprq = Pn(0.05, inf); // rrand(0.1, 0.4);
		~env = Pfunc({ [Env.adsr(0.01, rrand(0.02, 0.15), 0.05, 0.03).asArray] });
		~zzampFactor = 1/8 * (-6.dbamp);

		// you can mess with this
		~postPattern = {
			var dur = ~phraseDurStream.next;
			Pfindur(dur, Pbind(
				\amp, Env(#[0.4, 0.8, 0.8, 0.2], [0.1, 0.5, 0.4] * dur, #[-4, 0, -2])
					.asStream * Pkey(\ampFactor),
				\dur, Plazy({ ~dur }),
				\pan, Plazy({ ~panStream.next.loop })
			))
		};

		// don't mess with this
		~asPattern = {
			Pspawner({ |sp|
				var synth;
				loop {
					synth = ~synthStream.next;
					sp.par(
						Pchain(
							~postPattern.(),
							~objects[synth][\pattern],
							(instrument: synth)
						)
					);
					sp.wait(~waitTimeStream.next);
				};
			})
		};

		// ~prepareArgsForOneDef = { |id|
		// 	~objects[id][\lazyPat] = Plazy({ ~objects[pattern] });
		// };
		~prepareArgsForOneDef = nil;
		~getUserArgs = nil;
	} => PR(\clicks);
} {
	AbstractChuckArray.defaultSubType = saveSubType;
};