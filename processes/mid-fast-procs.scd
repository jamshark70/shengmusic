forkIfNeeded {
	var saveSubtype = AbstractChuckArray.defaultSubType;
	var cond = Condition.new;

	if(PR.exists(\shengShared).not) {
		loadPath(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd");
	};

	if(BP.exists(\shengShared).not) {
		PR(\shengShared) => BP(\shengShared);
		if(BP(\shengShared).ready.not) {
			NotificationCenter.registerOneShot(BP(\shengShared).v, \sharedReady, \longch, {
				cond.unhang;
			});
			cond.hang;
		};
	};

	protect {
		AbstractChuckArray.defaultSubType = \sheng;

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
				env: `{
					var envctl = NamedControl.kr(\env,
						Env.adsr(-2500, 0.15, 0.5, 0.3, curve: #[2, -3, -4]).asArray.extend(20, 0)
					);
					// the instr already made a \flzgtime NamedControl
					// so this reuses the same one
					envctl[5] = Select.kr(envctl[5] < 0, [envctl[5], NamedControl.kr(\flzgtime) * 0.4]);
					envctl
				}
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

		{ |name(\fmlow)|
			VC(name).free;
			Fact(\madfmVC).chuck(VC(name), nil, (
				makeBufs: {
					Fact(\madfmVC).v[\makeBufs].value;  // I want the usual bufs
					~sineBuf = Buffer.alloc(s, 2048, 1, { |buf| buf.sine1Msg(#[1]) });
				},
				defaultCarrierBuf: { ~sineBuf.bufnum },  // and another buf
				free: Fact(\madfmVC).v[\free].addFunc({ ~sineBuf.free })  // make a functionlist
			));
		} => Func(\makeFMLowVC);

		PR(\abstractProcess).clone {
			~event = (eventKey: \voicerNote);

			~mode = Pxrand(Mode.keys.select { |key| key.asString.last == $0 }.asArray, inf);
			~seed = Pwhite(0, 0x7FFFFFFF, inf);
			~topnote = \patRejectLastN.eval(
				Pseries({ rrand(24, 30) }, Pwhite(1, 3, inf) * Prand(#[-1, 1], inf), inf).fold(24, 30),
				1
			);
			~car_env = [Env(#[0, 1, 0.5, 0, 0], #[0.01, 0.14, 8.0, 0.15], -4, releaseNode: 3)];
			~mod_env = [Env(#[0, 1, 0.25, 0.1, 0], #[0.01, 0.3, 1.0, 10.0], -4)];
			~gate = 0.5;

			~freq = Pseed(
				Pfin({ rrand(3, 6) }, Pkey(\seed)),
				Pwhile1(
					{ |in, next| next >= 18 },
					Pseries(
						{ |inevent| inevent[\topnote] },
						Pwrand(#[-1, -2, -3], #[0.5, 0.4, 0.1], { rrand(4, 8) })
					)
				)
			);
			~dur = 0.25;
			~car_detune = 1.006;
			~mod_buf = Plazy({ Prand(VC(\fmlow).env.bufs, inf) });
			~mod_lev = Pif(Pdiff(Pkey(\freq)) > 0, Pwhite(25.0, 40.0, inf), Pwhite(8.0, 19.0, inf));
			~legato = Pif(Pdiff(Pkey(\freq)) > 0, Pwhite(2.5, 10.0, inf), 0.8);
			~length = Pkey(\dur) * Pkey(\legato);

			~outerPattern = {
				Pbind(
					\mode, BPStream(\mode),
					\seed, BPStream(\seed),
					\topnote, BPStream(\topnote),
					\car_env, BPStream(\car_env),
					\mod_env, BPStream(\mod_env),
					\gate, BPStream(\gate)
				)
			};

			~innerPattern = {
				Pbind(
					\freq, Plazy({ ~freq }),
					\dur, BPStream(\dur),
					\car_detune, BPStream(\car_detune),
					\mod_buf, BPStream(\mod_buf),
					\mod_lev, BPStream(\mod_lev),
					\legato, BPStream(\legato),
					\length, BPStream(\length)
				)
			};

			~asPattern = {
				PR(\psetp2).copy.prep(~outerPattern.(), ~innerPattern.(), currentEnvironment)
				.outerOverridesInner_(false)
			};
		} => PR(\fastlow);

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


		// repeating 16ths
		Pwhite(5, 11) * 0.25 => MacRh(\rpt16);

		{ |notes, inEvent|
			Pseq([notes.asChord, Pn(inEvent[\top][\repeatNotes] ?? { 62.mapMode(inEvent[\mode]) }, inf)], 1)
		} => ArpegPat(\rpt16);

		Ptuple([0.25, Pseq([Pwhite(0.2, 0.33, 1), Pn(0.08, inf)], 1), 0.5]) => MicRh(\rpt16);

		{ |top, topMode, mode, topEvent|
			// crappo workaround b/c this gets called multiple times
			if(topEvent[\origRepeatNotes].isNil) {
				topEvent[\origRepeatNotes] = topEvent[\repeatNotes];
			};
			topEvent[\repeatNotes] = \convertMode.eval(topEvent[\origRepeatNotes], topMode, mode);
			\convertMode.eval(top, topMode, mode)
		} => Func(\convertModeRpt);

		ProtoEvent.composite(#[voicerNote, voicerNoteKrBusLock, dummy]) => ProtoEvent(\flzg);

		(
			make: { |name|
				var p;
				BP(name).free;
				\newCh.eval(name, \arpegMultiVoicer, \macroRh, MBM(0)[\pzch], nil, MacRh(\rpt16), \rpt16, \rpt16, nil, \d);
				p = BP(\rp);

				p.topNote = PR(\patternTop).copy.make {
					~mode = \d0;
					~deg = Pwhite(35, 42, inf);
					~rpt = Pn(Pwhile1(
						{ |in, next| next.unmapMode(in[\mode]) <= 74 },
						Pseries({ rrand(-6, -2) }, Pwrand(#[1, 2, 3], #[0.5, 0.45, 0.05], inf), { rrand(3, 7) })
					), inf);
					// above may be 0: ensure a unique array
					~repeatNotes = Pfunc({ |ev| 62.mapMode(ev[\mode]) }) + Ptuple([0, BPStream(\rpt)]).collect({ |pair|
						if(pair[0] == pair[1]) { pair[0] } { pair }
					});
					~asPattern = {
						// don't like copy/paste programming
						// but I stupidly don't let you choose a mode per top event
						Pbind(
							\freq, BPStream(\deg),
							\delta, BPStream(\delta),
							\length, BPStream(\length),
							\mode, BPStream(\mode),
							\gate, BPStream(\gate),
							\repeatNotes, BPStream(\repeatNotes)
						)
					};
				};
				p.convertTopFunc = \convertModeRpt;

				// maybe a disaster -- um, NO! IT'S COOL!!!
				// p.topNote.mode = Pxrand(Mode.keys.asArray.select { |key| key.asString.last == $0 }, inf);

				p.child.initVoicerArgs;
				p.child.voicerArgs = (
					onePizz: Pbind(
						\ffreq, Pseq([Pexprand(6000, 9400, 1), Pexprand(4000, 7000, inf)]),
						\amp, 4
					),
					tri: Pbind(
						\holdtime, Pkey(\length) + 1,
						\ffreq, Pseq([Pexprand(4500, 7500, 1), Pexprand(2700, 8000, inf)]),
						\rq, Pwhite(0.1, 0.6, inf),
						\gate, Pseq([0.3, Pn(0.25, inf)]),
						\detune, Pwhite(1.002, 1.02, inf)
					),
					fm: Pbind(
						\mod_lev, Pwhite(5.0, 8.0, inf),
						\mod_ratio1, Pwhite(1, 4, inf),
						\mod_ratio2, Pkey(\mod_ratio1),
						\car_detune, Pwhite(1.002, 1.02, inf),
						\car_buf, Plazy({ Prand(VC(\fm).env.bufs, inf) }),
						\mod_buf, Plazy({ Prand(VC(\fm).env.bufs, inf) }),
						\mod_env, Plazy({
							[Env.adsr(0.01, rrand(0.07, 0.9), rrand(0.1, 0.3), 1.0)].loop
						}),
						\car_env, [Env.adsr(0.01, 0.7, 0, 0.2)],
						\gate, Pfunc({ |ev|
							if(ev[\note].asFloat.size > 2) { 0.4 } { 0.22 }
						})
					),
					// this function is only a trick to declare a temporary variable
					flzg: {
						var e = Env(#[0, 0.3, 1, 0.4, 0], #[0.15, 0.02, 0.08, 0.7], #[1, 1, 1, -6]);
						Pbind(
							\protoEvent, \voicerNoteKrBusLock, // Pseq([\voicerNoteKrBusLock, Pn(\voicerNote, inf)], 1),
							\ffreq, { ~lock.bus.asMap },
							\rq, 0.6,
							\holdtime, 1000,
							\flzgrate, Pwhite(24.0, 31.0, inf),
							\flzgratio, 0.4,
							\flzgdepth, 0.9,
							\flzgtime, 0.3,
							\env, [e],
							\numCh, 1,
							\lpcEv, (instrument: \ctlEnv, connect: 0, env: e.copy.levels_(#[1200, 4000, 12000, 6000, 2000]))
						)
					}.value,
					dummy: Pbind(\eventKey, \dummy)
				);
				p.child.resetArgsOnChord = true;
				p.child.event[\eventKey] = \flzg;

				p.child.gestures = [
					\onePizz.loop, \tri.loop, \fm.loop,
					Pseq([\flzg, \dummy, Pn(\tri, inf)], 1)
				];
				// #1 and #3 repeat the same basic voicer
				// so cut their probabilities in half
				p.child.argPairs = [vckey: Plazy({ ~gestures.wchoose(#[0.33333333333333, 0.16666666666667, 0.33333333333333, 0.16666666666667]) })];

				p.child.makeChordPattern = { Pxrand(~chords, inf) };
				p.child.fitFunc = \chordFitNotes;

				1 => p;

				p
		}, type: \bp) => Fact(\rpt16BP);


		// fluttertongue overlaps
		// this is pretty cool!
		SynthDef(\ffreqpan, { |outbus, time = 1/*, pan1 = 0, pan2 = 0*/|
			var ffreqenv = NamedControl.kr(\fenv, Env(#[4000, 4000], #[1]).asArray.extend(40, 0)),
			ffreq = EnvGen.kr(ffreqenv, 1, 1, 0, time, 2),
			panenv = NamedControl.kr(\panenv, Env.zero(1).asArray.extend(20, 0)),
			pan = EnvGen.kr(panenv, timeScale: time); // Line.kr(pan1, pan2, time);
			Out.kr(outbus, [ffreq, pan]);
		}).add;

		(Pwhite(2, 5, inf) * Ptuple([0.5, Pwhite(0.7, 1.6, inf)], inf)) => MacRh(\flzg);

		(
			make: { |name|
				var p;
				BP(name).free;
				Func(\newCh).value(name, \arpegMultiVoicer, \macroRh, MBM(0)[\pzch], nil, MacRh(\flzg).v, \blockFollow, \block, nil, \d);

				p = BP(name);
				p.child.event.eventKey = \voicerNoteKrBusLock;

				p.child.argPairs = Pbind(
					\ffreq, { ~lock.bus.asMap },
					\pan, { ("c" ++ (~lock.bus.index+1)).asSymbol },
					\rq, Pwhite(0.4, 0.8, inf),
					\holdtime, 1000,
					\env, Pfunc({ |ev|
						// above envelope, but times array is normalizeSum'med
						[Env(#[0, 0.3, 1, 0.4, 0], #[0.23809523809524, 0.0095238095238095, 0.038095238095238, 0.71428571428571] * ev[\length], #[1, 1, 1, -6])]
					}),
					\flzgrate, Pwhite(20.0, 29.0, inf),
					\flzgratio, 0.4,
					\flzgdepth, 0.9,
					\flzgtime, Pfunc({ |ev| 1.4 * ev[\env][0].times[0] }),
					\gate, 0.8,
					\numCh, 2,
					\lpcEv, Pbind(
						\instrument, \ffreqpan,
						\env, Pfunc({ |ev| [ev[\env][0].copy.levels_([1200, 4000, exprand(9500, 14000), exprand(3000, 6800), 2000])/*.curves_()*/] }),
						\time, 1,
						// pan1: p = /*rrand(0.7, 1.0) * */ #[-1, 1].choose, pan2: /*rrand(0.7, 1.0) * */ p.sign.neg
						\panenv, Pfunc({ |ev|
							var p, e = ev[\env][0];
							[Env(p = #[-1, 1].rotate(2.rand).insert(1, 0.5.rand2), [e.times[0], e.times.sum - e.times[0]], #[-4, 4] * p[0].sign)]
						})
					)
				);

				p.topNote = PR(\patternTop).copy.make {
					~mode = \d;
					~deg = Pwhite(40, 55, inf);
				};
				p.child.fitFunc = \chordFitInt;

				p
			},
			type: \bp
		) => Fact(\flzgBP);


		PR(\clicks).clone {
			~event = (eventKey: \polySynthPlayer);

			~userprep = ~userprep.addFunc({
				~maxPoly = GenericGlobalControl(\maxPoly, nil, 0.08, #[0.05, 20, \exp]);
			});
			~userfree = { ~maxPoly.free };
			~useGui = { |vpi| ~maxPoly => VP(vpi) };

			~durBase = Pn(0.125, inf);
			~dur = Plazy({ ~durBaseStream.next.loop }) * Pwrand([Pn(1, 2), 2, 4], #[0.1, 0.75, 0.15], inf);

			~waitTime_ = { |pattern|
				if(pattern.notNil) { ~waitTimeSource = pattern };
				~waitTime = pattern;
			};
			~waitTime_.(Pwhite(1.0, 4.0, inf).round(0.25));
			~stopCleanup = {
				~waitTime = ~waitTimeSource;  // automatically reset, if you stopped it by setting nil
			};

			~freqEnv = Env.one;

			~dHarmonicSeries = 50.midicps * (1..9);  // more than 9 introduces aliasing @ 44.1k
			~specs = Plazy({
				var harmonics = ~dHarmonicSeries.copy;
				(Pseq([
					Array.fill(3, {
						// trick: removeAt returns the item that was removed, which is what I want
						harmonics.removeAt(round(exprand(0.01, harmonics.size - 0.001) - 0.5).asInteger)
					}),
					Pn([#[62, 69].choose.midicps], inf)
				]) * ~freqEnv.value).collect { |freqs|
					freqs.collect { |freq|
						[
							(#[1, 2] ++ ~freqTemplate.scramble.keep(3)) * freq,
							~ampTemplate,
							Array.fill(5, { exprand(0.02, 0.2) })
						].flat
					}
				}
			});

			~hpfreq = Plazy({
				var baseFreq = (#[62, 69].choose + (12 * rrand(2, 5))).midicps,
				harmonics = baseFreq * 0.5 * (1 .. (40000 / baseFreq).asInteger);
				Pseq([
					if(harmonics.size <= 3) { harmonics } {
						Array.fill(3, {
							harmonics.removeAt(round(exprand(0.01, harmonics.size - 0.001) - 0.5).asInteger)
						})
					},
					Pn(baseFreq, inf)
				]) * ~freqEnv.value
			});

			~objects = (
				klinks: (
					def: \klinks,
					pattern: Pbind(
						\bufnum, Plazy({ ~klbufnumStream.next.loop }),
						\klAtk, BPStream(\klAtk),
						\klDcy, BPStream(\klDcy),
						\excfreq, Plazy({ ~excfreqStream.next.loop }),
						\specs, Plazy({ ~specs/*Stream.next.loop*/ }),
						\ampFactor, BPStream(\klampFactor)
					)
				),
				zzip: (
					def: \zzip,
					pattern: Pbind(
						\bufnum, Plazy({ ~zzbufnumStream.next.loop }),
						\sustain, BPStream(\sustain),
						\freq, BPStream(\freq),
						\hpfreq, Plazy({ ~hpfreq/*Stream.next.loop*/ }),
						\hprq, Plazy({ ~hprqStream.next.loop }),
						\env, Plazy({ ~envStream.next.loop }),
						\ampFactor, BPStream(\zzampFactor)
					)
				)
			);

			~superPattern = ~asPattern;
			~postPattern = {
				var dur = ~phraseDurStream.next;
				~latestPhraseDur = dur;
				Pfindur(dur, Pbind(
					\amp, Pseq([1.0, Env(#[0.86, 0.3], [dur], -7)], 1) * Pkey(\ampFactor),
					\dur, Plazy({ ~dur }), // * Env(#[1, 2], [dur], -1.5),
					\pan, Plazy({ ~panStream.next.loop }),
					\isAccent, Pseq([true, Pn(false, inf)], 1)
				))
			};

			~simultaneousThreshold = 0.001;
			~asPattern = {
				var stream = ~superPattern.().asStream;
				Prout({ |inval|
					var simult = IdentitySet.new, accents = IdentitySet.new,
					event, delta, numout,
					cleanup = EventStreamCleanup.new;
					block { |break|
						loop {
							// collect simultaneous events
							while {
								event = stream.next(inval);
								if(event.isNil) { break.(cleanup.exit(inval)) };  // end condition
								event.delta < ~simultaneousThreshold
							} {
								if(event.isRest.not) {
									if(event[\isAccent] == true) {
										accents.add(event.put(\delta, 0))
									} {
										simult.add(event.put(\delta, 0))
									};
								};
							};
							if(simult.isEmpty and: { accents.isEmpty }) {
								if(~maxPoly.value.trunc + ~maxPoly.value.frac.coin.asInteger >= 1) {
									inval = event.yield
								} {
									inval = event.put(\isRest, true).yield;
								}
							} {
								delta = event.delta;
								event[\delta] = 0;
								if(event.isRest.not) {
									if(event[\isAccent] == true) {
										accents.add(event)
									} {
										simult.add(event)
									};
								};
								numout = min(
									simult.size + accents.size,
									~maxPoly.value.trunc + ~maxPoly.value.frac.coin.asInteger
								);
								if(accents.size > 0) { numout = max(1, numout) };
								min(numout, accents.size).do {
									event = accents.choose;
									accents.remove(event);  // "take" should do this but not for Set???????
									inval = event.yield;
								};
								(numout - accents.size).clip(0, simult.size).do {
									event = simult.choose;
									simult.remove(event);
									inval = event.yield;
								};
								simult.clear; accents.clear;
								inval = Event.silent(delta).yield;
							};
						};
					};
				})
			}
		} => PR(\gridClicks);

	} { AbstractChuckArray.defaultSubType = saveSubtype };
};