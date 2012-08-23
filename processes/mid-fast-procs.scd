forkIfNeeded {
	var cond = Condition.new;

	if(PR.exists(\shengShared).not) {
		loadPath(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd");
	};

	if(BP.exists(\shengShared).not) {
		PR(\shengShared) => BP(\shengShared);
		NotificationCenter.registerOneShot(BP(\shengShared).v, \sharedReady, \longch, {
			cond.unhang;
		});
		cond.hang;
	};


	// fluttertongue
	// really need to pass the envelope through, so copy/paste time...
	WrapInstr("osc2.v3mappanflzg", { |freq, bufbase, numbufs, basefreq, topfreq,
		ffreq = 2000, rq = 1,
		pan, holdtime = 1, env,
		/*flzgtime = 0.15,*/ flzgrate = 12, flzgratio = 0.7, flzgdepth = 0.8|
		var baselog = log2(basefreq),
		freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
			* (numbufs - 1)).clip(0, numbufs - 1.001);
		var flzgtime = NamedControl.kr(\flzgtime, 0.15),
		sig = WrapInstr.wrap("osc2.vosc3", [freq, nil, bufbase, freqmap, env.dereference.value]),
		flzgspeed = Line.kr(flzgrate * flzgratio, flzgrate, flzgtime),
		flzglow = XLine.kr(max(0.001, 1 - flzgdepth), 1, flzgtime),
		flzgamp = VarSaw.ar(flzgspeed, width: 0.2).range(flzglow, 1);
		Line.kr(0, 1, holdtime + 0.15, doneAction: 2);  // zombie killer
		Pan2.ar(RLPF.ar(sig, ffreq, rq), pan, flzgamp);
	}, [
		\freq, #[0, 1000, \linear, 1, 0], #[0, 20, \lin, 1, 0], \freq, \freq,
		\freq, \rq,
		\bipolar, #[0.01, 10], EnvSpec(Env.adsr),
		/*#[0, 0.5],*/ #[1, 30], #[0.25, 4, \exp], nil
	]);

	// can't 'make' a Factory inside another Factory
	{ |name(\flzg)|
		Fact(\triVC).chuck(VC(\flzg), nil, (
			instrName: "osc2.v3mappanflzg",
			env: `{ Env.adsr(
				// the instr already made a \flzgtime NamedControl
				// so this reuses the same one
				NamedControl.kr(\flzgtime) * 0.4,
				0.15, 0.5, 0.3, curve: #[2, -3, -4]
			) }
		));
	} => Func(\makeflzgVC);

	// mad FM
	WrapInstr("osc2.fm_monster", { arg freq, gate, car_env, mod_env, mod_lev,
		freqInitRatio = 1, mod_ratio1 = 1, mod_ratio2 = 1, slideTime = 1,
		detune, car_detune,
		car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale, pan;
		var sig, mod, mod_ratio, car_amp, mod_amp;
		car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
		mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
		* EnvGen.kr(mod_env.dereference.value(slideTime), gate);
		freq = freq * XLine.kr(max(0.001, freqInitRatio), 1.0, slideTime);
		mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
		mod_ratio = Line.kr(mod_ratio1, mod_ratio2, slideTime);
		mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
		freq = freq * [1, car_detune];
		sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
		* EnvGen.kr(car_env.dereference.value(slideTime), gate, doneAction:2);
		Pan2.ar(sig, pan);
	}, [
		\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential],
		#[0.05, 20, \exp], [1, 12, \linear, 0, 1], [1, 12, \linear, 0, 1], #[0, 2],
		[-5, 5, \linear, 0, 0], \mydetune,
		\mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp], \bipolar
	]);

	// most args are left unset - be careful
	(	keys: #[master, rvbmc],
		initLevel: 0.75,
		make: { |name|
			~target = MixerChannel(name, s, 2, 2, ~initLevel, outbus: ~master, completionFunc: nil);

			~bufs = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
				var amps;
				i = i + 3;
				amps = Array.fill(i+1, 0).put(0, 1).put(i, 1);
				Pfin(i div: 2, Pshuf((1 .. i-2), 1)).do { |randIndex|
					amps[randIndex] = rrand(0.2, 0.7);
				};
				buf.sine1Msg(amps)
			});

			Voicer(15, WrapInstr("osc2.fm_monster"), [
				basefreq: `440, car_vs: `0.8, mod_vs: `0.8,
				car_env: `{ NamedControl.kr(\car_env, (0 ! 40).overWrite(Env.adsr.asArray)) },
				mod_env: `{ NamedControl.kr(\mod_env, (0 ! 40).overWrite(Env.adsr.asArray)) }
			], target: ~target);
		},
		free: { [~target, ~bufs].free },
		type: \voicer
	) => Fact(\madfmVC);


};