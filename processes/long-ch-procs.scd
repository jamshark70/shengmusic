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


		// RAPID PIZZES

		WrapInstr("osc.ks_retrig", { |freq = 440, amp = 0.1, ffreq = 2000,
			excratio = 0.5, excamp = 1, excAtk = 0.005, excDcy = 0.03, retrigProb = 1,
			fbamp = 1, pan = 0,
			env, timeScale = 1,
			bufselect, firstbuf = 1, numbufs = 2, detectSilence, trigFunc|
			var frq = freq.dereference.value(),
			delayt = max(0, frq.reciprocal - ControlDur.ir),
			excfreq = frq * excratio.dereference.value(),
			firstbufnum = firstbuf.asUGenInput,  // .bufnum if a Buffer, 'this' if a number
			// exciter retriggering
			trig = trigFunc.dereference.value() ?? {
				Impulse.ar(EnvGen.kr(NamedControl.kr(
					\trigFreqEnv,
					(0 ! 40).overWrite(Env().asArray)
				), timeScale: timeScale))
			},
			mask = TRand.ar(0, 1, trig) < retrigProb,
			excEnv = min(1.0, Decay2.ar(trig * mask, excAtk, excDcy)),
			exc = VOsc.ar(
				bufselect.dereference.value().range(firstbufnum, firstbufnum + numbufs - 1.01),
				excfreq, 0,
				excamp.dereference.value()
			) * excEnv,
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
				#[0.1, 1, \exp], \amp, #[0.001, 0.2, \exp], #[0.001, 0.2, \exp], nil,
				\amp, \bipolar,
				EnvSpec(Env.adsr), #[0.01, 100, \exp],
				ObjectSpec({ SinOsc.kr(Rand(0.08, 0.14)) }), \mybuf, StaticSpec(2, 16, \lin, 1, 2),
				ObjectSpec(false), ObjectSpec(nil)
		]);

		(keys: #[master, rvbmc],
			initLevel: 0.75,
			trigFunc: nil,
			detectSilence: false,
			postMCCreation: nil,  // a function
			make: { |name|
				var out;
				~target = MixerChannel(name, s, 2, 2, ~initLevel, outbus: ~master, completionFunc: { |chan|
					if(~rvbmc.notNil) { chan.newPostSend(~rvbmc, 0.4) };
					~postMCCreation.value(chan);
				});
				out = Voicer(25, WrapInstr("osc.ks_retrig"), [
					env: `{ NamedControl.kr(\env, (0 ! 20).overWrite(Env.asr.asArray)) },
					firstbuf: `(BP(\shengShared).noiseBufs[0].bufnum),
					numbufs: `(BP(\shengShared).noiseBufs.size),
					amp: 1,
					trigFunc: ~trigFunc,
					detectSilence: ~detectSilence
				], target: ~target);
				out.mapGlobal(\retrigProb, nil, 0.12, #[0, 1]);
				out
		}, free: { ~target.free }, type: \voicer) => Fact(\pizz);


		Pwhite(0.6, 2.4, inf) * Ptuple([1, Pwhite(4.2, 9.8, inf), 0.5], inf) => MicRh(\pizzes);

		MIDIRecBuf(\openDA, [
			#[50, 57, 62, 69, 74],
			0.1, 0.1, 0.5
		].asNotes, (type: \ch, mode: d)) => MBM(0);

		MIDIRecBuf(\pzch, [
			[	38, 45, 50, 54, 55, 59, 61, 64,
				40, 49, 50, 54, 57, 61, 64, 71,
				42, 50, 52, 57, 59, 62, 66, 67,
				43, 47, 49, 52, 54, 57, 62, 67
			],
			Array.fill(4, (0.1 ! 8).put(7, 1)).flat,
			1 ! 32,
			0.5 ! 32
		].asNotes, (type: \ch, mode: \d)) => MBM(0);

		(
			make: { |name|
				var new;
				BP(name).free;
				new = \newCh.eval(name, \arpeg1, \macroRh, MBM(0)[\openDA], nil, Pwhite(14, 24, inf), \pizzes, \shuf1, nil, \d);
				new.quant = 0;
				new.topNote = PR(\patternTop).copy.make {
					~deg = 'patRejectLastN'.eval(Pseries(
						{ rrand(36, 43) },
						Pwrand(#[1, 2, 3], #[0.5, 0.3, 0.2], inf),
						inf
					).fold(36, 43), 1);
					~mode = \d;
				};
				new.child.use {
					~fitFunc = \chordFitNotes;

					~ffreq = Pfunc({ |ev|
						var topfreq = ev[\mode].asMode.cps(ev[\freq] ?? { ev[\note].freq }).asArray.maxItem,
						ffreq = (topfreq * exprand(4.0, 18.0)).clip(1000, 12000);
						ev[\ffreqRatio] = ffreq / topfreq;
						ffreq
					});
					~ctranspose = Pkey(\ffreqRatio).linlin(4, 23, 0.6, 0.051);
					~excratio = Pwhite(0.4, 0.65);
					~excamp = 1;
					~fbamp = Pwhite(0.98, 0.998, inf);
					~trigFreqEnv = Pfunc({
						var atk = rrand(0.35, 0.5);
						[Env(
							[rrand(0.9, 1.25), rrand(8.0, 12.5), rrand(0.9, 1.25)],
							[atk, 1 - atk],
							\exp
						)].asArray
					});
					~timeScale = Pkey(\length);
					~excAtk = Pexprand(0.005, 0.02);
					~excDcy = (Pkey(\excAtk) * Pwhite(2.0, 5.0));
					~retrigProb = 0.6;
					~pan = (Pwhite(0.4) * Pseq([ -1, 1 ], inf));
					~amp = 1;

					~argPairs = Pbind(
						\ffreq, BPStream(\ffreq),
						\excratio, BPStream(\excratio),
						\excamp, BPStream(\excamp),
						\fbamp, BPStream(\fbamp),
						\trigFreqEnv, BPStream(\trigFreqEnv),
						\timeScale, BPStream(\timeScale),
						\excAtk, BPStream(\excAtk),
						\excDcy, BPStream(\excDcy),
						\retrigProb, BPStream(\retrigProb),
						\pan, BPStream(\pan),
						\amp, BPStream(\amp),
						\ctranspose, BPStream(\ctranspose)
					);
				};
				new
		}, type: \bp) => Fact(\pzBP);

		PR(\abstractProcess).clone {
			~resetChild = false;
			~first = true;
			~rest = Pwhite(7.0, 14.0, inf);

			~event = (eventKey: \hang);
			~alwaysReset = true;
			~prep = { |bpname|
				~bp = bpname ?? { ~bp };
				~cond = Condition.new;
				~event.put(\cond, ~cond);
				currentEnvironment
			};
			~preparePlay = {
				case
				{ BP.exists(~bp).not } { "BP(%) doesn't exists".format(~bp.asCompileString).warn }
				{ BP(~bp).v[\eventStream].isNil } { BP(~bp).prepareForPlay }
				{ ~resetChild } { BP(~bp).reset };

				if(~stopWatcher.isNil) {
					~stopWatcher = NotificationCenter.register(BP(~bp).child, \childStop, ~collIndex, e {
						~cond.unhang
					});
				};
			};
			~asPattern = {
				if(~restStream.isNil) { ~makeStreamForKey.(\rest) };
				Prout({ |inevent|
					loop {
						if(~first != ~wasFirst) {
							~wasFirst = ~first;
							if(~first) {
								MBM(0)[\openDA] => BP(\pz);
								BP(~bp).child.fitFunc = \asis;
								~first = false;
							} {
								MBM(0)[\pzch] => BP(\pz);
								BP(~bp).child.fitFunc = \chordFitNotes;
							};
						};
						BP(~bp).triggerOneEvent(0);
						// hang first, then wait 'delta' beats
						inevent = inevent.copy.put(\delta, ~restStream.next(inevent)).yield;
					}
				})
			};
			~stopCleanup = {
				~stopWatcher.remove;
				~stopWatcher = nil;
				BP(~bp).child[\eventStreamPlayer].stop;
				if(BP(~bp).child.event[\voicer].isKindOf(Voicer)) {
					BP(~bp).child.event.voicer.nodes.do { |node|
						node.release(-1.65);  // force 0.65 sec release
					};
				};
			};
		} => PR(\chordRunner);



		// TRIPLET GESTURE

		WrapInstr("osc2.v3mappan", { |pan, holdtime = 1|
			var sig = WrapInstr.wrap("osc2.vosc3mapfilt");
			Line.kr(0, 1, holdtime + 0.15, doneAction: 2);  // zombie killer
			Pan2.ar(sig, pan);
		}, [\bipolar, #[0.01, 10], \amp]);

		(
			keys: #[master, rvbmc],
			iMadeBufs: false,
			getBufs: { BP(\shengShared).oscBufs },
			env: Env.adsr(0.07, 0.12, 0.4, 0.12),
			instrName: "osc2.v3mappan",
			voicerArgs: { [
				bufbase: `(~oscBufs.first.bufnum),
				numbufs: `(~oscBufs.size),
				basefreq: `(48.midicps),
				topfreq: `(132.midicps),
				env: ~env,
				vsens: `1,
				detune: 1.003
			] },
			make: { |name|
				var out;
				~oscBufs = ~getBufs.value;
				if(~oscBufs.isNil) {
					Error("Making VC(%): Osc buffers not provided.".format(name.asCompileString)).throw;
				};
				~target = MixerChannel(name, s, 2, 2, level: ~initLevel ? 0.75, outbus: ~master,
					completionFunc: { |chan|
						~eq = MultiEQ(2, \loshelf, 1266.303, -7.669.dbamp, 1).play(chan);
						~chorus = chan.playfx(Instr("busfx.chorus2"), [
							0, 2, 2, 3,
							0.017377393674649, 0.1, 0.0071613988449721,
							1.6669675304762, 0.61054022965853]
						);
					};
				);
				out = Voicer(20, WrapInstr(~instrName), ~voicerArgs.value, target: ~target);
				~customize.value(out);
				out
			},
			free: { ~target.free },
			type: \voicer) => Fact(\triVC);


		{ |notes, event| Pn(event[\length] / 3, 3).collect { |x| [x, x * 0.7, 0.5] } } => MicRh(\triplet);

		// { |notes, event| Ptuple([Pn(event[\length] / 3, 3), Pseq([event[\length] * 0.16, 0.1, 0.1], 1), 0.5]) } => MicRh(\trpOverlap);

		{ |notes, event| Ptuple([Pn(event[\length] / 3, 3), event[\length] * 0.22, 0.5]) } => MicRh(\trpOverlap);

		Pwhite(0.8, 1.6, { rrand(5, 11) }) => MacRh(\triplet);

		Pwhite(0.5, 0.75, { rrand(2, 4) }) => MacRh(\tshort);
		Pwhite(1.0, 1.25, { rrand(1, 2) }) => MacRh(\tmid);
		Pwhite(1.8, 2.2, 1) => MacRh(\tlong);

		// IMPORTANT: this assumes MicRh will stop the arpeggiation
		{ |notes|
			if(notes.isArray) {
				Pn(notes.asChord, inf)
			} {
				Pn(notes, inf)
			};
		} => ArpegPat(\blocks);

		MIDIRecBuf(\tripletCh, [
			[	62, 67, 69,
				62, 66, 71,
				62, 64, 71,
				62, 67, 71,
				62, 66, 76
			],
			(0.1 ! 15).putSeries(2, 5, 15, 1),
			0.1,
			0.5
		].asNotes, (mode: \d, type: \ch)) => MBM(0);


		(
			keys: #[clock88],
			childProc: \arpeg1,
			oneChordPerArpeg: true,
			argPairs: [
				gate: Pseq(#[0.17, 0.1, 0.1]),
				pan: Plazy({ |ev| (~panWidthStream.next(ev) * ~panSideStream.next(ev)).loop }),
				width: Pstutter(10, Pwhite(0.05, 0.15, 1)),
				ffreq: Pgeom({ exprand(6000, 9000) }, Pstutter(10, Pwhite(0.15, 0.22, 1)), 3),
				rq: Pseq(#[0.1, 0.4, 1.0], inf),
				holdtime: Pkey(\length) / Ptempo()
			],
			make: { |name|
				var p;
				BP(name).free;
				p = \newCh.eval(name, ~childProc, \macroRh, MBM(0)[\tripletCh], nil, MacRh(\triplet), \triplet, \blocks, nil, \d);

				p.topNote = PR(\patternTop).copy.make {
					~deg = Pxrand((33..44), inf);
					~mode = \d;
				};

				p.quant = 0;
				p.clock = ~clock88;
				p.printStopMsg = false;
				p.alwaysReset = true;

				if(~oneChordPerArpeg ? false) {
					// make sure each child pattern stays on the same chord
					// especially for overlap
					p.child.nextNoteStream = #{ |inEvent|
						~nextNotePattern.value(inEvent);
						~updateNoteStream.value(inEvent);
						Pn(~noteStream.next(inEvent), inf);
					};
				};
				p.child.makeChordPattern = { Pxrand(~chords, inf) };
				p.child.fitFunc = \chordFitNotes;

				p.child.panWidth = Pwhite(0.7, 1.0, inf);
				p.child.panSide = Pseq(#[-1, 1], inf);
				p.child.argPairs = ~argPairs;

				p.overlapCtl = GenericGlobalControl(\tpOverlap, nil, 1, #[0.3, 10, \exp]);
				p.useGui = { |vpi| ~overlapCtl => VP(vpi) };
				p.userfree = { ~overlapCtl.free };
				p.event.stopChild = false;

				p
		}, type: \bp) => Fact(\tripletBP);

		Plazy({
			var dur = rrand(9.0, 16.0), proportion = rrand(0.3, 0.7);
			Plimitsum(dur, Pexprand(0.8, 1.25, inf)
				// * Env([2.0, 0.8, 2.0], [proportion, 1 - proportion] * dur, \exp).postcs);
				* Env(rrand(#[1.5, 0.56, 1.8], #[2.2, 0.75, 2.4]), [proportion, 1 - proportion] * dur, \sin));
		}) => MacRh(\accelrit);

		{ |env, timeScale = 1, lo = 0.8, hi = 1.25|
			var times = env.times * timeScale;
			Plimitsum(times.sum, Pexprand(0.8, 1.25, inf) * env.copy.times_(times))
		} => Func(\envRandWrap);

		Plazy({
			\envRandWrap.eval(Env([rrand(0.4, 0.6), rrand(2.0, 2.5)], #[1], \exp), rrand(6.0, 11.0))
		}) => MacRh(\decel);

		Plazy({
			var ratio = rrand(0.6, 0.75);
			\envRandWrap.eval(Env([rrand(2.0, 2.5), rrand(0.4, 0.6), rrand(0.4, 0.6), rrand(1.4, 1.7)], [ratio, 0.9 - ratio, 0.1], \exp), rrand(11.0, 16.0))
		}) => MacRh(\accel);

		SynthDef(\overlapEnv, { |out|
			Out.kr(out, EnvGen.kr(
				Env(
					[Rand(3.0, 3.2), Rand(8.0, 8.5), Rand(3.7, 4.2), 3],
					[Rand(7, 9), Rand(10, 14), Rand(5, 7)],
					#[2, 5, -3]
				),
				doneAction: 2
			))
		}).add;

		Pstutter(Pwhite(3, 5, inf), Pwhite(2.0, 3.5, inf)) / Ptuple([Plazy({ BP(\tri).overlapCtl.asPattern }), 1], inf) => MacRh(\tpOverlap);

		PR(\abstractProcess).clone {
			~event = (eventKey: \hang);
			// ~bp = nil;  // name of bp
			~playMode = \default;

			~alwaysReset = true;

			~prep = { |bpname|
				~cond = Condition.new;
				~event.put(\cond, ~cond);
				~modes = ~modes.value;
				~bp_.(bpname ?? ~bp);
				~modeStreams = IdentityDictionary.new;
				currentEnvironment
			};
			~freeCleanup = { ~resp.remove };

			~bp_ = { |bpname|
				if(bpname != ~bp or: { ~resp.isNil }) {
					~resp.remove;
					~bp = bpname;
					// wrong, we want to wait for the parent to stop, not each arpeg
					// ~resp = NotificationCenter.register(BP(~bp).child, \childStop, ~collIndex, e {
					// 	~cond.unhang;
					// });
					~resp = Updater(BP(~bp), e { |obj, what, more|
						if(more == \stopped) { ~cond.unhang };
					});
				};
				currentEnvironment
			};

			~dftRest = Pwhite(6.0, 10.0, inf);

			~modes = { (
				default: (
					stopChild: false,
					prepare: {
						MacRh(\tlong) => BP(~bp);
					},
					asPattern: {
						Pbind(
							\action, e { BP(~bp).play(0) },
							\delta, BPStream(\dftRest)
						)
					},
				),
				accelrit: (prepare: { MacRh(\accelrit) => BP(~bp) }),
				accel: (prepare: { MacRh(\accel) => BP(~bp) }),
				decel: (prepare: { MacRh(\decel) => BP(~bp) }),
				overlap: (
					prepare: {
						MacRh(\tpOverlap) => BP(~bp);
					},
					asPattern: {
						Pbind(
							\action, e {
								BP(~bp).overlapCtl
								.watch
								.automate(\overlapEnv)
								.onFree(e { BP(~bp).stopNow });
								BP(~bp).play(0);
							},
							\delta, BPStream(\dftRest)
						)
					}
				),
				at2: { |me, subKey ... keys|
					var k = keys.detect { |key| me[key][subKey].notNil };
					me[k ?? { \default }][subKey]
				}
			) };

			// ~preparePlay = {
			// 	~modes.at2(\prepare, ~playMode).value;
			// };

			~asPattern = {
				Prout({ |inevent|
					var mode;
					if(~playModeStream.isNil) { ~makeStreamForKey.(\playMode) };
					loop {
						mode = ~playModeStream.next(inevent);
						if(mode.notNil) {
							~lastPlayMode = mode;
							~modes.at2(\prepare, mode).value;
							if(~modeStreams[mode].isNil) {
								~modeStreams[mode] = ~modes.at2(\asPattern, mode).value.asStream;
							};
							inevent = ~modeStreams[mode].next(inevent).yield;
						} {
							nil.alwaysYield
						}
					}
				})
			};

			~stopCleanup = {
				if(~modes.at2(\stopChild, ~lastPlayMode)) { BP(~bp).stopNow };
			};
		} => PR(\triDriver);



		{ |source, inEvent, fitFactors, eventValues|
			var	transposeStats,  // [[xpose1, fitness1], [xpose2, fitness2]...]
			xposeBy, mode, topEvent, top, topMode, root, notes;

			#mode, topEvent, top, topMode, root, notes = eventValues;

			// transpose and evaluate for each note
			transposeStats = notes.collect({ |n|
				[xposeBy = (top - n).asFloat,
					Func(\chPitchFit).doAction(notes + xposeBy, top, root, mode, fitFactors)];
			}).sort({ |a, b| a[1] > b[1] });  // sort fitnesses descending
			// transpose the whole chord
			Func(\fixNotesAboveTop).doAction(notes + transposeStats[0][0], top, mode);
		} => Func(\chordFitNotesCustomValues);

		{ |source, inEvent, fitFactors|
			var eventValues = Func(\getValuesFromEvent).doAction(source, inEvent),
			evcopy = eventValues.copy,
			top = eventValues[2];

			top.asFloat.asArray.collect { |aTop|
				\chordFitNotesCustomValues.eval(source, inEvent, fitFactors,
					evcopy.put(2, aTop)
				)
			}
		} => Func(\chordFitNotesMulti);

		{ |notes|
			notes = notes.collect { |item|
				if(item.isArray) {
					item.asChord
				} {
					item
				};
			};
			Pseq(notes, inf)
		} => ArpegPat(\blocksMulti);


		{ |notes, event| var d = rrand(3, 7); Ptuple([Pn(event[\length] / d, d), event[\length] * 0.7 / d, 0.5]) } => MicRh(\tup);



		(
			oneChordPerArpeg: false,
			argPairs: [
				gate: Pseq([0.17, Pn(0.1, inf)]),
				pan: Plazy({ |ev| (~panWidthStream.next(ev) * ~panSideStream.next(ev)).loop }),
				width: Pstutter(10, Pwhite(0.05, 0.15, 1)),
				ffreq: Pgeom({ exprand(6000, 9000) }, Pstutter(10, Pwhite(0.5, 0.7, 1)), inf),
				rq: Pseq([0.1, min(1, Pgeom(0.4, 0.97, inf))]),
				holdtime: Pkey(\length) / Ptempo()
			],
			childProc: \arpeg1,
			make: { |name|
				var r;
				BP(name).free;
				// you may not chuck a Fact while make-ing a different Fact
				r = Fact(\tripletBP).v[\make].value(name);

				// r.topNote.deg = (Pxrand((33..44), inf) - Ptuple([0, Pwhite(-6, -2, inf)], inf));
				r.topNote.deg = 'patRejectLastN'.eval(Pseries(
					{ rrand(36, 43) },
					Pwrand(#[1, 2, 3], #[0.5, 0.3, 0.2], inf),
					inf
				).fold(36, 43), 1) - Ptuple([0, Pwhite(-6, -2, inf)], inf);
				Pwhite(1, 3, inf) =>.macro r;

				r.child.fitFunc = \chordFitNotesMulti;
				\blocksMulti =>.arpeg r;
				\tup =>.micro r;

				r
			},
			type: \bp) => Fact(\tupletBP);


		// transparent thingy
		(
			keys: #[master, rvbmc],

			make: { |name|
				~chan = MixerChannel(name, s, 2, 2, level: 0.75, outbus: ~master, completionFunc: { |chan|
					chan.newPostSend(~rvbmc, 0.7);
				});
				// sh!t design for SY, shouldn't have to do this
				~target = ~chan.synthgroup;
				~out = ~chan.inbus;
				~bus = ~out;

				~bufs = \makeWavetables.eval(8, s, 2048, 48, { |numHarm|
					var a = Array.squareAmps(numHarm), i;
					min(numHarm, 7).do { |i|
						a[i] = a[i] * ((i+1) / 7);
					};
					(numHarm * 0.15).do {
						i = 1.0.rand.lincurve(0, 1, 0, numHarm - 0.001, -3).asInteger;
						a[i] = a[i] * rrand(2.0, 8.0);
					};
					a;
				});

				~def = WrapPatch("osc2.v3mappan", \patchArgs.eval(WrapInstr("osc2.v3mappan"), [
					bufbase: ~bufs.first.bufnum,
					numbufs: ~bufs.size,
					basefreq: 48.midicps,
					topfreq: 132.midicps,
					env: Env.adsr(1.8, 0.9, 0.6, 2.4, curve: -2.5),
					vsens: 1,
					detune: `1.003
				])).asSynthDef;
				~def.name = ~def.name ++ UniqueID.next;
				~def.add;
				SynthDescLib.at(~def.name.asSymbol).msgFuncKeepGate = true;

				~def.name.asSymbol
			},
			free: { [~chan, ~bufs].free }) => Fact(\trnspSY);

		SynthDef(\ffreqWobble, { |low = 400, hi = 9000, time = 1,
			upRatio = 0.3, shape = 5, curve = 0,
			clipLo = 20, clipHi = 20000, out|
			var env = Env([low, hi, low], [upRatio, 1.0 - upRatio]).asArray
			.put(6, shape).put(10, shape)
			.put(7, curve).put(11, curve),
			eg = EnvGen.kr(env, timeScale: time, doneAction: 2),
			wobbleAmtEnv = NamedControl.kr(
				\wobbleEnv,
				(0 ! 20).overWrite(Env(#[1, 1.4, 1], #[0.5, 0.5], \sin).asArray)
			),
			wobbleEg = EnvGen.kr(wobbleAmtEnv, timeScale: time),
			wobbleRateEnv = NamedControl.kr(
				\wobbleRateEnv,
				(0 ! 20).overWrite(Env(#[2.5, 7.5, 2.5], #[0.5, 0.5], \sin).asArray)
			),
			wobbleRateEg = EnvGen.kr(wobbleRateEnv, timeScale: time),
			wobbly = Lag.kr(
				LFPulse.kr(wobbleRateEg).exprange(wobbleEg.reciprocal, wobbleEg),
				0.15 / wobbleRateEg
			);
			ReplaceOut.kr(out, Clip.kr(wobbly * eg, clipLo, clipHi));
		}).add;

		{ |notes, inEvent|
			Ptuple([
				Pexprand(0.05, 0.1, notes.estimateLength),
				inEvent[\length] * Pexprand(0.95, 1.05, inf),
				0.5
			], 1)
		} => MicRh(\quickArp);

		MIDIRecBuf(\transparent, [
			[69, 74, 83,  74, 76, 85,  69, 74, 76, 79] + 12,
			(0.1 ! 10).putEach(#[2, 5, 9], 1),
			1, 0.5
		].asNotes, (type: \ch, mode: \d)) => MBM(0);

		(
			make: { |name|
				var p;

				BP(name).free;
				\newCh.eval(name, \arpegSynth, \macroRh, MBM(0)[\transparent], nil, Pwhite(5.0, 10.0, inf), \quickArp, \up1, nil, \d);

				p = BP(name);
				p.child.argPairs = { |inEvent|
					[
						numCh: 1,
						// debugpost: Pfunc({ |ev| ev[\note].postcs }),
						holdtime: (inEvent[\length] + 4) / Ptempo(),
						sustain: Pkey(\length),
						ffreq: { ~lock.bus.asMap },
						rq: Pwhite(0.1, 0.4, inf),
						lpcEv: Pbind(
							\instrument, \ffreqWobble,
							\low, Pexprand(300, 500, inf),
							\hi, Pexprand(3000, 11000, inf),
							\upRatio, Pwhite(0.72, 0.9, inf),
							\shape, Env.shapeNumber(\exp),
							\time, Pkey(\holdtime),
							\wobbleEnv, Pfunc({ |ev|
								Env(
									[rrand(1.25, 1.7), rrand(2.5, 3.5), rrand(1.25, 1.7)],
									[ev[\upRatio], 1.0 - ev[\upRatio]],
									\sin
								)
							})
						)
					]
				};

				p.child.event.eventKey = \synthNoteKrBusLock;
				p.recalcPropagateKeys;  // hack hack hack

				p
		}, type: \bp) => Fact(\trnspBP);



		// low chord

		(keys: #[master, rvbmc],
			initLevel: 0.75,
			make: { |name|
				var out;
				~target = MixerChannel(name, s, 2, 2, ~initLevel, outbus: ~master, completionFunc: { |chan|
					if(~rvbmc.notNil) { chan.newPostSend(~rvbmc, 0.4) };
				});
				out = Voicer(25, WrapInstr("osc.ks_retrig"), [
					env: `{ NamedControl.kr(\env, (0 ! 20).overWrite(Env.asr.asArray)) },
					firstbuf: `(BP(\shengShared).noiseBufs[0].bufnum),
					numbufs: `(BP(\shengShared).noiseBufs.size),
					amp: 1,
					trigFunc: `{
						var baseDur = NamedControl.kr(\baseDur, 0.22);
						TDuty.kr(
							baseDur * Dstutter.new(
								Dseq([Dwrand(#[4, 3, 5, 6], #[6, 2, 1, 1].normalizeSum, 1), 1], inf),
								Dseq([1, Dwrand(#[2, 3], #[0.86, 0.14], 1)], inf)
							),
							level: 1
						)
					}
				], target: ~target);
				out.mapGlobal(\retrigProb, nil, 0.12, #[0, 1]);
				out
		}, free: { ~target.free }, type: \voicer) => Fact(\lowpizz);

		MIDIRecBuf(\lowCh, [
			#[33, 45, 54, 55, 62, 64,  35, 47, 54, 55, 61, 64, 69],
			(0.1 ! 13).putEach(#[5, 12], 1),
			1, 0.5
		].asNotes, (mode: \d, type: \ch)) => MBM(0);

		(Pwhite(17.0, 22.0, inf) + Ptuple([Pwhite(2.5, 4.5, inf), 0], inf)) => MacRh(\lowCh);

		{ |notes, ev|
			var totalDur = ev[\length];
			Pseq([0, Pexprand(0.8, 2.0, inf)], 1).collect { |delta|
				[
					delta,
					// this is my evil hack to calculate a side effect and ignore its result
					totalDur.value(totalDur = totalDur - (delta * rrand(1.4, 1.8))),
					0.5
				]
			}
		} => MicRh(\lowCh);

		(
			make: { |name|
				var p;
				BP(name).free;
				p = Func(\newCh).value(name, \arpeg1, \macroRh, MBM(0)[\lowCh], nil, MacRh(\lowCh), \lowCh, \up1, nil, \d);

				p.child.event.eventKey = \voicerNoteKrBusLock;
				p.recalcPropagateKeys;  // hack hack hack
				p.child.argPairs = { |event|
					var shouldSetBass = true;
					[
						\saveBassNote, Pfunc({
							if(shouldSetBass) {
								Library.put(\lowChBass, ~currentChord.notes.minItem.asFloat);
								shouldSetBass = false;
							};
							0
						}),
						\amp, Pgeom.fromEndpoints(3, 1.5, ~currentChord.notes.size),
						\ffreq, { ~newFreq[0] * exprand(8.0, 11.0) },
						\fbamp, 0.99,
						\excamp, 0.4,
						\excAtk, 0.08,
						\excDcy, 0.12,
						\baseDur, { ~lock.bus.asMap },
						\retrigProb, 1,
						\numCh, 1,
						\timeScale, Pkey(\length) / Ptempo(),
						\env, [Env(#[0, 1, 1, 0], #[0.12, 0.7, 0.18], #[2, 0, -4])],
						\lpcEv, Pbind(
							\instrument, \ctlEnv,
							\connect, 0,
							\env, Pfunc({ |ev|
								Env(
									#[0.31, 0.1, 0.31] * exprand(0.8, 1.25),
									#[0.5, 0.5] * ev[\timeScale],
									\sin
								)
							})
						)
					]
				};
				p.printStopMsg = false;
				p.leadTime = 0.02;

				p
			},
			type: \bp
		) => Fact(\lowChBP);



		// high chord

		SynthDef(\noiselet, { |freq = 440, noisefreq = 60, beats = 0.5, noisebuf,
			filtAttack = 0.02, filtDecay = 0.3,
			attack = 1, decay = 0, susLevel = 1, release = 1, gate = 1,
			pan = 0, amp = 0.1, out = 0, freqlag = 0|
			var sig = COsc.ar(noisebuf, noisefreq, beats, amp),
			eg = EnvGen.kr(Env.adsr(attack, decay, susLevel, release), gate, doneAction: 2);
			sig = Formlet.ar(sig, Lag.kr(freq, freqlag), filtAttack, filtDecay);
			sig = Limiter.ar(sig, 1, 0.006);  // harmonics can spike the level
			Out.ar(out, Pan2.ar(sig, pan, eg));
		}).add;

		(
			type: \voicer,
			keys: #[master, rvbmc],
			initLevel: -14.dbamp,
			rvbLevel: 0.8,
			voicerClass: Voicer,
			numVoices: 20,
			defname: \noiselet,
			// now, customizing this factory is pushing into the absurd
			gcSpecs: [
				\filtAttack -> #[0.001, 0.15, \exp, 0, 0.05],
				\noisefreq -> #[30, 120, \exp, 0, 60]
			],
			make: { |name|
				var out;
				~target = MixerChannel(name, s, 2, 2, outbus: ~master, level: ~initLevel,
					completionFunc: { |chan|
						chan.newPostSend(~rvbmc, ~rvbLevel);
						chan.playfx(Instr("busfx.chorus"), [0, 2, 0.012257636323289, 0.12067926406393, 0.0077565879124374, 2.1478235488828, 0.5]);
					}
				);

				out = ~voicerClass.new(~numVoices, ~defname, [attack: 1.5, decay: 1.0, susLevel: 0.7, release: 4.5], target: ~target);
				~gcSpecs.do { |assn|
					var spec = assn.value.asSpec;
					out.mapGlobal(assn.key, nil, spec.default, spec);
				};

				~target.doWhenReady {
					out.globalControls[\noisefreq].automate({
						LFDNoise1.kr(LFDNoise1.kr(0.15).range(0.1, 2)).exprange(30, 90)
					}, target: ~target.fadergroup, addAction: \addToHead);
					~customize.value(out);
				};

				out
			},
			free: { ~target.free }
		) => Fact(\noiseletVC);


		// first pitch intro c. m30
		MIDIRecBuf(\simpleCh, [
			#[81, 83,  81, 86, 88, 85,  79, 74, 90, 83],
			#[0.1, 1, 0.1, 0.1, 0.1, 1, 0.1, 0.1, 0.1, 1],
			0.1, 0.5
		].asNotes, (type: \ch, mode: \d)) => MBM(0);

		{ |notes| Pseq(notes, 1) } => ArpegPat(\asis1);
		Ptuple([ Pwhite(2.2, 2.9, inf), Pwhite(3.5, 8.0), 0.5 ]) => MicRh(\slowHighCh);

		Ptuple([Pwhite(0.8, 1.7, inf), Pwhite(4.0, 9.0, inf), 0.5]) => MicRh(\highCh);

		Pfunc({
			var d;
			if(BP(\lowCh).isPlaying) {
				d = BP(\lowCh).lastEvent.delta;
				[d, d - rrand(8.0, 11.5)]
			} { nil }
		}) => MacRh(\highCh);

		(
			quant: DelayTimeSpec(Pwhite(4.5, 7.0, inf)),
			customizeHook: nil,
			make: { |name|
				var p;
				BP(name).free;
				p = Func(\newCh).value(name, \arpeg1, \macroRh, MBM(0)[\pzch], nil, MacRh(\highCh).v, \highCh, \xrand, nil, \d);

				p.child.argPairs = [
					beats: Pwhite(0.3, 0.8, inf),
					noisebuf: Prand(BP(\shengShared).noiseBufs, inf),
					pan: Pwhite(-0.8, 0.8, inf)
				];
				// here, I *do* want closer spacing
				p.child.fitFunc = \chordFitNotes;
				p.bassID = \lowChBass;
				p.topNote = PR(\patternTop).copy.make {
					~deg = Pwhite(47, 55, inf);
					~mode = \d;
				};
				~quant => p;
				p.leadTime = 0;  // force later than \lowCh

				~customizeHook.(p);

				p
		}, type: \bp) => Fact(\highChBP);



		// scotch snap

		{ |name(\onePizz)|
			VC(name).free;
			Fact(\pizz).chuck(VC(name), nil, (
				initLevel: -17.dbamp,
				postMCCreation: { |chan|
					chan.playfx(Instr("busfx.chorus"), [0, 2, 0.0065907508688725, 0.091029817799152, 0.0015096530399363, 0.99376910470698, 0.5])
				},
				detectSilence: true,
				trigFunc: { Impulse.ar(0) }
			));
			VC(name).set([retrigProb: 1]);
			VC(name)
		} => Func(\makeOnePizzVC);

		Pseq([Pn(1, { #[1, 2, 3].wchoose(#[0.35, 0.45, 0.2]) }), Pwhite(2, 4, 1)], inf) => MacRh(\scotch);

		Pseq(#[0.8, 0.3], 1).collect { |gate, ev|
			[0.25, 1, Array.fill(ev[\note].asFloat.size, gate).put(0, gate * 1.6)]
		} => MicRh(\scotch);

		{ |notes|
			notes = notes.sort { |a, b| a.asFloat > b.asFloat };
			Pseq(
				[
					notes[0..1],  // top 2 notes
					notes[2..]    // rest of the notes
					.scramble     // random order
					.clump(roundUp((notes.size - 2) / 2))  // divide into two clumps
				].flop.collect(_.flat),
				1
			)
		} => ArpegPat(\scotch);

		ModalSpec(#[0, 2, 4, 7, 9], 12, 2) => Mode(\dpent1);
		ModalSpec(#[0, 2, 5, 7, 9], 12, 2) => Mode(\dpent2);

		(
			make: { |name|
				var p;
				BP(name).free;
				p = Func(\newCh).value(name, \arpeg1, \macroRh, MBM(0)[\pzch], nil, MacRh(\scotch).v, \scotch, \scotch, nil, \d);
				p.child.fitFunc = \chordFitNotes;

				p.child.argPairs = [
					ffreq: { (~newFreq.asArray.maxItem * exprand(8.0, 12.0)).clip(1000, 12000) },
					excamp: Pkey(\gate) * 5,
					excAtk: 0.04,
					excDcy: 0.09,
					fbamp: Pwhite(0.996, 0.998, inf),
					pan: Pseq(#[-1, 1], inf, { 2.rand }) * Pstutter(1000, Pwhite(0.7, 0.9, 1)),
					env: [Env.one(20)]
				];

				p.topNote = PR(\patternTop).copy.make {
					// \restart: each ascending scale segment uses one d-pentatonic variant
					// the mode can switch only when a new segment starts
					~deg = Pn(Pwhile1({ |ev, next| next <= 31 }, Pseries({ rrand(25, 30) }, 1, { rrand(2, 5) })), inf, \restart);
					~mode = Pgate(Prand(#[dpent1, dpent2], inf), inf, \restart);
					~asPattern = {
						Pbind(
							\freq, BPStream(\deg),
							\delta, BPStream(\delta),
							\length, BPStream(\length),
							\mode, BPStream(\mode),   // ugh, why not in the real proto?
							\gate, BPStream(\gate)
						);
					};
				};
				0 => p;
				p
		}, type: \bp) => Fact(\scotchBP);

		PR(\abstractProcess).clone({
			~alwaysReset = true;
			~event = (eventKey: \default);
			~bufRecorder = nil;  // fill this in at chuck time to provide a buffer source
			~iMadeBuffers = false;

			~prep = {
				~chan = MixerChannel(~collIndex, s, 2, 2, outbus: ~master, completionFunc: { |chan|
					chan.newPostSend(~rvbmc, 0.8);
				});
				~event.put(\group, ~chan.synthgroup).put(\out, ~chan.inbus.index);
				~runningStreams = IdentitySet.new;

				#[patDelta, patDur, shortDur, longDur, pan, panWidth,
					startLo, startHi, gesture, startCenter, startWidth].do { |key|
					~makeStreamForKey.(key);
				};

				~initSynthDef.();

				if(~bufRecorder.notNil and: { BP.exists(~bufRecorder) }) {
					~buffers = BP(~bufRecorder).buffers;
				} {
					~buffers = 2.collect { |i|
						Buffer.readChannel(s, "/home/dlm/share/SC/Recordings/cues/feet101120_155745-partnering-norm.aiff",
							51766, 1449461, i
						);
					};
					~iMadeBuffers = true;
				};

				currentEnvironment
			};
			~freeCleanup = {
				~chan.free;
				if(~iMadeBuffers) { ~buffers.free };
			};

			~patDelta = Pwhite(0.8, 3.0, inf);
			~patDur = Pwhite(4.5, 7.0, inf);

			~shortDur = Pwhite(0.11, 0.18, inf);
			~longDur = Pwhite(0.4, 0.8, inf);
			~pan = Pwhite(0.25, 0.85, inf) * Prand(#[-1, 1], inf);
			~panWidth = Pwhite(0.05, 0.15, inf);
			~startCenter = 948088 + Pwhite(-40000, 40000, inf);
			~startWidth = Pwhite(500, 1200, inf);

			~tfLo = 6;
			~tfHi = 18;
			~durEnvs = (
				decel: { |ev| Env([ev[\shortDur], ev[\longDur]], [ev[\totalDur]], rrand(-1.0, -0.2)) },
				acceldecel: { |ev|
					var ratio = rrand(0.5, 0.8);
					Env(
						[ev[\longDur], ev[\shortDur], ev[\longDur]],
						[ratio, 1 - ratio] * ev[\totalDur],
						rrand(-1.0, -0.2) * #[-1, 1]
					)
				},
				steps: { |ev|
					var n = rrand(3, 7);
					Env(
						Array.series(n, ev[\shortDur], (ev[\longDur] - ev[\shortDur]) / n),
						Array.fill(n, ev[\totalDur] / n),
						\step
					)
				}
			);
			// ~gesture = Pfunc({ ~durEnvs.keys.choose });
			~gesture = Pwrand(#[decel, acceldecel, steps], #[0.6, 0.3, 0.1], inf);
			~durEnv = { |ev| ~durEnvs[ev[\gesture] ? \decel].value(ev) };
			~bufnum = Plazy({ Prand(~buffers, inf) });
			~trig = Pkey(\dur) / Ptempo();
			~amp = Pfunc({ |ev|
				ev[\dur].linlin(ev[\shortDur], ev[\longDur], 3, 0.001);
			});
			~trigRatio = 0.1;
			~depth = 0.92;

			~onePattern = {
				var dur = ~patDurStream.next,
				shortDur = ~shortDurStream.next, longDur = ~longDurStream.next,
				gesture = ~gestureStream.next;
				Pfindur(dur,
					Pmono(~defname,
						\shortDur, shortDur,
						\longDur, longDur,
						\totalDur, dur,
						\gesture, gesture,
						\dur, Plazy({ |ev| ~durEnv.(ev) }),
						\bufnum, BPStream(\bufnum),
						\tfLo, ~tfLo, \tfHi, ~tfHi,
						\trig, BPStream(\trig),
						\amp, BPStream(\amp),
						\startCenter, ~startCenterStream.next,
						\startWidth, ~startWidthStream.next,
						\startLo, max(0, Pkey(\startCenter) - Pkey(\startWidth)),
						\startHi, min(
							Pfunc({ |ev|
								if(ev[\bufnum].isKindOf(Buffer)) {
									ev[\bufnum].numFrames - 1
								} {
									Buffer.cachedBufferAt(s, ev[\bufnum]).tryPerform(\numFrames)
									?? 44100
								};
							}),
							Pkey(\startCenter) - Pkey(\startWidth)
						),
						\panCenter, ~panStream.next,
						\panWidth, ~panWidthStream.next,
						\trigRatio, BPStream(\trigRatio),
						\depth, BPStream(\depth)
					)
				)
			};

			~addOne = {
				var stream = CleanupStream(~onePattern.().asStream, e {
					~runningStreams.remove(stream);
				}), result;
				result = ~spawner.par(stream);
				// if(~runningStreams.isEmpty) { ~nextEventNow.() };  // imported from shengDrone
				~runningStreams.add(stream);
				result
			};

			~removeOne = { |stream|
				if(stream.isNil) { stream = ~runningStreams.choose };
				~spawner.suspend(stream);
				~runningStreams.remove(stream);
				currentEnvironment
			};

			~stopAdding = {
				~keepAdding = false;
				currentEnvironment
			};

			~asPattern = {
				Pspawner({ |sp|
					~spawner = sp;
					~keepAdding = true;
					while { ~keepAdding ? true } {
						~addOne.();
						sp.wait(~patDeltaStream.next);
					};
				})
			};
			~stopCleanup = {
				~spawner = nil;
				~runningStreams.clear; // not sure why I need this anyway?
			};
			// ~reset = { \resetBPStreams.eval };

			~initSynthDef = {
				~def = SynthDef(\tbuzzz, { |bufnum,
					tfmod = 0, tfLo = 5, tfHi = 5, gdurMul = 20,
					rate = 1, startLo = 0, startHi = 0, envbuf = -1, gate = 1,
					dratioLo = 0.15, dratioHi = 0.45, dRatioDensity = 8, resolution = 0.01,
					lpfreq = 19000, amp = 1,
					panCenter = 0, panWidth = 0,
					t_trig = 1, depth = 0.8, trigRatio = 0.35, out|
					var	bufFr = BufFrames.kr(bufnum),
					start = SinOsc.ar(Rand(0.07, 0.16)).range(startLo, startHi),
					tfreq = SinOsc.kr(tfmod).range(tfLo, tfHi),
					trig = Impulse.ar(tfreq),
					pan = TRand.kr(panCenter - panWidth, panCenter + panWidth, trig),
					sig = GrainBuf.ar(2, trig, gdurMul / tfreq, bufnum, rate,
						start / bufFr, // SinOsc.kr(0.1, 0, 441, start) / bufFr,
						pan: pan, envbufnum: envbuf
					),
					oneMinusDepth = 1 - depth,
					triggeredAmp = EnvGen.kr(
						Env([oneMinusDepth, 1, oneMinusDepth], [trigRatio, 1.0 - trigRatio], \sin),
						t_trig, timeScale: Latch.kr(t_trig, t_trig)
					),
					sr = SampleRate.ir,
					dratio = Lag.kr(TExpRand.kr(dratioLo, dratioHi, Dust.kr(dRatioDensity)), 0.05);
					sig = Latch.ar(sig, Impulse.ar(sr * dratio));
					sig = LPF.ar(sig.round(resolution), lpfreq, amp);
					Out.ar(out, sig * triggeredAmp * Linen.kr(gate, 0.01, 1, 0.01, doneAction: 2));
				}).add;
				~defname = ~def.name;
				currentEnvironment
			};
		}).import((shengDrone: #[nextEventNow])) => PR(\decimator);

		PR(\abstractProcess).clone {
			~bp = \dc;
			~alwaysReset = true;
			~event = (eventKey: \dummy);
			~prep = {
				if(BP.exists(~bp)) {
					~resp = SimpleController(BP(~bp)).put(\stop, e {
						BP(~collIndex).stop(0);
					});
				} {
					"BP(%): target BP(%) doesn't exist"
					.format(~collIndex.asCompileString, ~bp.asCompileString)
					.warn;
				};
				currentEnvironment
			};
			~freeCleanup = { ~resp.remove };
			~preparePlay = {
				if(BP.exists(~bp)) {
					BP(~bp).play;
				} {
					"BP(%): target BP(%) doesn't exist"
					.format(~collIndex.asCompileString, ~bp.asCompileString)
					.warn;
				}
			};
			~stopCleanup = {
				if(BP.exists(~bp)) {
					BP(~bp).stopAdding;
				} {
					"BP(%): target BP(%) doesn't exist"
					.format(~collIndex.asCompileString, ~bp.asCompileString)
					.warn;
				}
			};
			~asPattern = {
				Pbind(\dur, 1);  // keep alive only
			};
		} => PR(\decimatorDriver);

		{ |name(\susCh)|
			BP(name).free;
			Fact(\highChBP).chuck(BP(name), nil, (
				customizeHook: { |p|  // p === the new BP
					0 => p;
					p.macroRhythm = Pwhite(8.0, 12.0, inf);
					Pfuncn({ |ev| ~macroRhythmStream.next(ev) }, 1) =>.macro p;
					\shuf1 =>.arpeg p;
					\highCh =>.micro p;
					p.child.argPairs = PbindProxy(*p.child.argPairs);
					p.child.argPairs.set(\attack, 2.5, \decay, 0.8, \susLevel, 0.5, \release, 9.0);
				}
			));
			if(VC.exists(\nlet)) { VC(\nlet) => BP(name) };
			BP(name)
		} => Func(\makeSusChBP);

	} { AbstractChuckArray.defaultSubType = saveSubtype };
};