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
		car_buf, mod_buf, car_vs, mod_vs, basefreq, keyscale, pan, car_env_time = 1, mod_env_time = 1;
		var sig, mod, mod_ratio, car_amp, mod_amp;
		car_amp = Latch.kr(Sensitivity.kr(1, gate, car_vs), gate);
		mod_amp = Latch.kr(Sensitivity.kr(1, gate, mod_vs), gate)
		* EnvGen.kr(mod_env.dereference.value(slideTime), gate, timeScale: mod_env_time);
		freq = freq * XLine.kr(max(0.001, freqInitRatio), 1.0, slideTime);
		mod_lev = mod_lev * basefreq / ((keyscale * freq) + (basefreq * (1 - keyscale)));
		mod_ratio = Line.kr(mod_ratio1, mod_ratio2, slideTime);
		mod = Osc.ar(mod_buf, freq.madd(mod_ratio * [1, car_detune], detune * [1, -1]), 0, mod_amp * mod_lev);
		freq = freq * [1, car_detune];
		sig = Mix(Osc.ar(car_buf, freq + (mod * freq), 0, car_amp))
		* EnvGen.kr(car_env.dereference.value(slideTime), gate, timeScale: car_env_time, doneAction:2);
		Pan2.ar(sig, pan);
	}, [
		\freq, \amp, EnvSpec(Env.adsr(0.01, 1, 1, 0.05)), EnvSpec(Env.adsr(0.01, 1, 1, 1)), [0.01, 300, \exponential],
		#[0.05, 20, \exp], [1, 12, \linear, 0, 1], [1, 12, \linear, 0, 1], #[0, 2],
		[-5, 5, \linear, 0, 0], \mydetune,
		\mybuf, \mybuf, nil, nil, \freq, [0.001, 1.0, \exp], \bipolar, #[0.05, 20, \exp], #[0.05, 20, \exp]
	]);

	// most args are left unset - be careful
	(	keys: #[master, rvbmc],
		initLevel: 0.75,
		makeBufs: {
			~bufs = Buffer.allocConsecutive(8, s, 2048, 1, { |buf, i|
				var amps;
				i = i + 3;
				amps = Array.fill(i+1, 0).put(0, 1).put(i, 1);
				Pfin(i div: 2, Pshuf((1 .. i-2), 1)).do { |randIndex|
					amps[randIndex] = rrand(0.2, 0.7);
				};
				buf.sine1Msg(amps)
			});
		},
		defaultCarrierBuf: { ~bufs.first.bufnum },
		defaultModBuf: { ~bufs.first.bufnum },
		make: { |name|
			~target = MixerChannel(name, s, 2, 2, ~initLevel, outbus: ~master, completionFunc: nil);
			~makeBufs.();

			Voicer(15, WrapInstr("osc2.fm_monster"), [
				basefreq: `440, car_vs: `0.8, mod_vs: `0.8,
				car_env: `{ NamedControl.kr(\car_env, (0 ! 40).overWrite(Env.adsr.asArray)) },
				mod_env: `{ NamedControl.kr(\mod_env, (0 ! 40).overWrite(Env.adsr.asArray)) },
				car_buf: ~defaultCarrierBuf.(),
				mod_buf: ~defaultModBuf.(),
			], target: ~target);
		},
		free: { [~target, ~bufs].free },
		type: \voicer
	) => Fact(\madfmVC);


	// smooth melody
	SynthDef(\noiselet2, { |freq = 440, noisefreq = 60, beats = 0.5, noisebuf,
		filtAttack = 0.02, filtDecay = 0.3,
		attack = 1, decay = 0, susLevel = 1, release = 1, gate = 1,
		pan = 0, amp = 0.1, out = 0, freqlag = 0, freqratio = 1.003|
		var sig = COsc.ar(noisebuf, noisefreq, beats, amp),
		eg = EnvGen.kr(Env.adsr(attack, decay, susLevel, release), gate, doneAction: 2);
		sig = Formlet.ar(sig, Lag.kr(freq, freqlag) * [1, freqratio], filtAttack, filtDecay).sum;
		sig = Limiter.ar(sig, 1, 0.006);  // harmonics can spike the level
		Out.ar(out, Pan2.ar(sig, pan, eg));
	}).add;

	{ |name(\nletmel)|
		Fact(\noiseletVC).chuck(VC(name), nil, (
			voicerClass: MonoPortaVoicer,
			initLevel: -3.2.dbamp,
			rvbLevel: -12.dbamp,
			numVoices: 1,
			defname: \noiselet2,
			gcSpecs: [
				\filtAttack -> #[0.01, 0.28, \exp, 0, 0.19],
				\filtDecay -> #[0.1, 0.5, \exp, 0, 0.4],
				\noisefreq -> #[30, 120, \exp, 0, 60]
			],
			customize: { |voicer|
				voicer.portaTime = 0.2;
				voicer.setArgDefaults([attack: 0.15, decay: 0.1, susLevel: 0.6, release: 0.2, freqratio: 0.5015]);
			}
		));
	} => Func(\makeNletMelVC);


	// cantus firmus
	// MIDI notes = bloody mess
	{
		var t = 1/3, d, sl = 0.05, ns = -0.05, g = 0.11 / 2;
		MIDIRecBuf(\shMel,
			[
				[	79, 81, 79, 81, 79,
					79, 81, 78, 79, 81, 83, 81,
					88, 81,  83, 81, 78, 79, 81,  71, 88,  85, 86, 79,
					79, 81, 79,
					79, 81, 79, 83, 81, 79, 78, 76, 74, 76, 78, 71, 74, 76,  74, 78, 76
				],
				d = [1, 1.5, 0.5, 1.5, 0.5,
					1, 1, 0.5, 0.5, 0.5, 1, 0.5,
					g, 2-g,  0.5 + (t*2), t, t, t, t+1, g, 1.5-g, 1, 0.5, 1.5,
					0.5, 2, 0.75,
					0.5, 1+t, t, t, 1 + (t*2), t, t, t, t, 0.25, 0.25, 0.25, 0.25, 2, g, g, 2-(2*g)
				] * 2,
				(d + [sl, ns, sl, sl, 0,
					sl, ns, sl, sl, ns, sl, 0,
					sl, ns, sl, ns, sl, sl, ns, sl, ns, sl, ns, ns - 0.5,
					sl, sl, 0,
					sl, ns, sl, sl, sl, sl, sl, sl, ns, sl, sl, sl, sl, ns, sl, sl, ns
				]).putEach(#[4, 11, 25], #[0.7, 0.7, 0.9]),
				0.5
			].asNotes, (
				mode: \d, type: \mel, splitFunc: \userSplit, segFunc: \noSplit,
				phrSplits: #[5, 7, 10, 3, 17]  // note, these are indices *after* .parse
			)
		).parse(0.19, 0.19) => MBM(0);
	}.value;

	#{ |source, cross|	// absolute splice
		var	s1, s2, newSeg, splice, spl2size, spl2;
		s1 = source.notes;		// not worrying about weighting b/c poor adaptations
		s2 = cross.notes;		// will die after a few generations
		splice = ((s1.size-2).rand + 1).max(1);	// splice coordinates
		spl2size = rrand(3, (s2.size * 0.7).roundUp.asInteger);
		spl2 = (s2.size - spl2size).rand;
		newSeg = s1.copyRange(0, splice-1);
		newSeg = newSeg ++ s2.copyRange(spl2, spl2 + spl2size - 1);
		newSeg ++ s1.copyRange(splice, s1.size - 1);
	} => Func(\absSpliceFix);

	#{ |source, cross|
		// diatonic splice -- take part of s1 as is, insert intervals from part of s2,
		// and finish with s1
		var s1, s2, temp, s1ang, splice, current, new, spl2, spl2size;
		splice = ((source.notes.size-2).rand + 1).max(1);
		spl2size = rrand(3, (cross.notes.size * 0.7).round.asInteger);
		spl2 = (cross.notes.size - spl2size).rand.max(1);
		(spl2size + spl2 >= cross.notes.size).if({ spl2size = cross.notes.size - spl2 });

		(spl2size >= 2).if({
			new = source.notes.copyRange(0, splice-1);
			// last diatonically mapped note + first spliced interval - s2 dia map note
			current = (source.notes[splice-1] + cross.intervals[spl2 - 1] -
				cross.notes[spl2].freq).asFloat;
			new = new ++ (cross.notes.copyRange(spl2, spl2 + spl2size - 1) + current);
			// last note copied + transposition + next interval from source - next note (source)
			// algebraically simplifies to last note(s2) + transposition - last note (source)
			current = cross.notes[spl2 + spl2size - 1].freq + current - source.notes[splice-1].freq;
			new ++ (source.notes.copyRange(splice, source.notes.size - 1) + current);
		});
	} => Func(\intSpliceFix);

	(
		make: { |name|
			var p;
			BP(name).free;
			PR(\aiMel) => BP(name);

			p = BP(name);
			// p => VC(\nletmel);
			1 => p;

			MBM(0)[\shMelb] => p;
			MBM(0)[\shMelb] =>.adapt p;
			Pwrand([\absSpliceFix, \intSpliceFix, \delete], #[0.2, 0.5, 0.3], inf) =>.adapt p;
			p.eugTest = \dummyEugTest;

			// set phrase order
			p.mel.use {
				~phraseOrder = Plazy({ Pxrand(~mel, inf) });

				~makePhrPattern = { |passIn|
					passIn = passIn ?? { ~passInValue };
					~phrPattern = if(passIn[\repeats].isNil or: { passIn[\repeats] == inf }) {
						BPStream(\phraseOrder)
					} {
						Pfin(passIn[\repeats], BPStream(\phraseOrder))
					}
				};
			};
			p.repeats = 1;

			p.args = Pbind(
				\freqLag, Pfunc({ |ev|
					if(ev[\note].notNil and: { ev[\note].dur < 0.2 }) { 0.06 } { 0.2 }
				}),
				\ctranspose, 12
			);

			// p.macro = Pwhite(3, 6, inf) * 0.5;  // rests between phrases

			p
		},
		type: \bp
	) => Fact(\slowMelBP);

	// oscillate chords
	{ |notes, inEvent|
		notes = notes.sort { |a, b| a.asFloat > b.asFloat };
		if(BP.exists(inEvent[\collIndex])) {
			notes = notes.keep(max(2, (notes.size * BP(inEvent[\collIndex]).child.notePct.value).round.asInteger));
		};
		Pseq(
			[
				notes[0, 2 ..],  // top 2 notes
				notes[1, 3 ..]    // rest of the notes
			],
			inf
		)
	} => ArpegPat(\interleave);

	{ |notes, inEvent|
		notes = notes.sort { |a, b| a.asFloat > b.asFloat };
		if(BP.exists(inEvent[\collIndex])) {
			notes = notes.keep(max(2, (notes.size * BP(inEvent[\collIndex]).child.notePct.value).round.asInteger));
		};
		Pseq(
			notes.clump((notes.size + 1) div: 2),
			inf
		)
	} => ArpegPat(\highLow);

	{ |notepat| Pn(#[0.25, inf, 0.5], notepat.estimateLength) } => MicRh(\hold16th);
	{ |notepat| Pn([1/6, inf, 0.5], notepat.estimateLength) } => MicRh(\hold6tuplet);

	(
		make: { |name|
			var p;
			BP(name).free;
			p = Func(\newCh).value(name, \arpeg1Slurs, \macroRh, MBM(0)[\pzch], nil, Pwhite(3, 6, inf) * 0.5, \hold16th, \interleave, nil, \d);
			0 => p;

			p.child.ffreq = Ppatlace([Pexprand(3000, 9000, inf), Pexprand(800, 2500, inf)], inf);
			p.child.rq = Pwhite(0.2, 0.8, inf);
			p.child.argPairs = [ffreq: BPStream(\ffreq), rq: BPStream(\rq), holdtime: 1000];
			p.child.fitFunc = \chordFitInt;

			p.topNote = PR(\patternTop).copy.make {
				~deg = Pwhite(42, 53, inf);
				~mode = \d;
			};

			p.child.notePct = GenericGlobalControl(\notePct, nil, 0.2, #[0.1, 1.0]);
			p.useGui = { |vpIndex| ~child.notePct => VP(vpIndex) };
			p[\userfree] = { ~child.notePct.free };
			p.event.collIndex = p.collIndex;

			p
		},
		type: \bp
	) => Fact(\oscilBP);

};