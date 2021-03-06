forkIfNeeded {
	var saveSubType = AbstractChuckArray.defaultSubType;
	var cond = Condition.new;

	protect {
		AbstractChuckArray.defaultSubType = \sheng;

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
			~initLevel = -9.dbamp;
			~prep = {
				~chan = MixerChannel(~collIndex, s, 2, 2,
					level: ~initLevel,
					outbus: ~master ? topEnvironment[\master],
					completionFunc: { |chan|
						chan.newPostSend(~rvbmc ? topEnvironment[\rvbmc], -4.75.dbamp);
					};
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
					`{ LFDNoise1.kr(Rand(0.14, 0.4)).range(0.3, 0.77) }, nil, nil, nil,
					`{ NamedControl(\env, Env.adsr.asArray.extend(40, 0)) }, nil,
					`{ LFDNoise1.kr(Rand(0.08, 0.46)) },
					BP(\shengShared).noiseBufs[0], BP(\shengShared).noiseBufs.size
				]).asSynthDef.add;
				~defName = ~def.name.asSymbol;
			};

			~gst = Pseq(#[longPauses, da, longPauses], inf);
			~gestures = (
				default: Pbind(
					\dur, Pseq([Pexprand(0.4, 0.8, { rrand(2, 9) }), Pwhite(1.0, 2.7, 1)], 1),
					\sustain, Pwhite(4.0, 7.0, inf),
					\octave, 5,
					\deg, Prand(#[0, 4], inf)
				),
				fullRangeDrone: Plazy({
					Pset(\octave, Pwhite(Env(#[5, 3], #[5]).asStream.round, 5.99, inf).trunc,
						PnNilSafe(~gestures[\default], inf))
				}),
				longPauses: Pbind(
					\dur, Pseq([
						Pexprand(4.0, 9.0, { rrand(2, 5) }),
					], 1),
					\sustain, Pwhite(1.5, 4.5, inf),
					\octave, 5,
					\deg, 0
				),
				da: Pbind(
					\dur, Pexprand(0.3, 0.8, { rrand(2, 8) }),
					\sustain, Pwhite(1.5, 4.5, inf),
					\octave, 5,
					\deg, Pwrand(#[0, 4], #[0.45, 0.55], inf)
				),
				dArpeg: Pbind(
					\dur, Pexprand(0.3, 0.8, inf),
					\sustain, Pwhite(1.5, 4.5, inf),
					\octave, 5,
					\deg, Pscratch(
						Pwhile1(
							{ |inval, next| next <= 9 },
							Pseries(-14, Pseq([4, 3, Pwrand(#[1, 2, 3], #[0.45, 0.45, 0.1], inf)], 1), inf)
						),
						Pn(Plazy({
							var numforward = rrand(2, 5), numbackward = rrand(2, 4);
							Pseq([Pn(1, numforward), numbackward, Pn(-1, numbackward - 1), numbackward], 1)
						}), inf)
					)
				),
				enat: Pbind(
					\dur, Plazy({ Pn(rrand(0.3, 0.52), rrand(5, 9)) }),
					\sustain, 0.25,
					\octave, 5,
					\deg, 1,
					\amp, 0.25
				),
				ebnat: Pbind(
					\dur, Plazy({ Pn(rrand(0.2, 0.45), rrand(6, 11)) }),
					\sustain, 0.25,
					\octave, 5,
					\deg, Pstutter(Pwhite(2, 3, inf), Pseq(#[-2, 1], inf, { 2.rand })),
					\amp, 0.25
				),
				pentatonic: Pbind(
					\dur, Plazy({ Pn(rrand(0.2, 0.45), inf) }),
					\sustain, 0.25,
					\octave, 5,
					\deg, Pstutter(Pwhite(2, 3, inf), Pshuf(#[-2, 0, 1, 2, 4], 1)),
					\amp, 0.25
				),
				gb: Pbind(
					\dur, Plazy({ Pn(rrand(0.2, 0.45), { rrand(7, 12) }) }),
					\sustain, 0.25,
					\octave, 5,
					\deg, Pstutter(Pwhite(2, 3, inf), Pseq(#[3, 5], inf)),
					\amp, 0.25
				),
				gbcs: Pbind(
					\dur, Plazy({ Pn(rrand(0.2, 0.45), { rrand(12, 21) }) }),
					\sustain, 0.25,
					\octave, 5,
					\deg, Pstutter(Pwhite(2, 3, inf), Pseq(#[3, 5, 6], inf)),
					\amp, 0.25
				),
				gsbcs: Pbind(
					\dur, Plazy({ Pn(rrand(0.2, 0.45), { rrand(12, 21) }) }),
					\sustain, 0.25,
					\octave, 5,
					\deg, Pstutter(Pwhite(2, 3, inf), Pn(Pshuf(#[3.1, 5, 6], 1), inf)),
					\amp, 0.25
				),
				midRest: Pbind(
					\dur, Pwhite(2.0, 5.0, 1),
					\deg, Rest
				),
				// following is for the climax section near the end
				bmin: Pbind(
					\totalDur, 6,
					\dur, Pn(0.5, 12),
					\sustain, 0.4, // max(0.5, Pkey(\totalDur) - Ptime()),
					\octave, 3,
					\deg, Pseq([-2, 2, 5, 9, 11, 15, Pxrand(#[5, 9, 11, 15], inf)]),
					\amp, 0.25
				),
				gmaj: Pfindur(32, Pbind(
					\dur, Pseq([
						Pn(0.5, 8),
						Pexprand(0.8, 1.25, inf) * Pseg(
							Pseq([0.3, 0.9], inf),
							Pwhite(2.5, 6.0, inf),
							\exp
						)
					]),
					\sustain, Pwhite(0.25, 0.5, inf),
					\octave, 3,
					\deg, Pseq([-4, 0, 3, 7, 11, 12,
						Pseq([
							Pxrand(#[16, 18, 22, 11, 13, 7], { rrand(3, 7, inf) }),
							Pseq(#[-4, 0, 3], 1)
						], inf)
					]),
					\amp, 0.25
				)),
				emaj: Pfindur(11.5, Pbind(
					\dur, Pexprand(0.8, 1.25, inf) * Pseg(
						Pseq([0.3, 0.9], inf),
						Pwhite(2.5, 6.0, inf),
						\exp
					),
					\sustain, Pwhite(0.25, 0.5, inf),
					\octave, 3,
					\deg, Pseq([1, 5, 8, 12, 14, 18,
						Pseq([
							Pxrand(#[12, 14, 17.5, 18, 20, 21], { rrand(3, 7, inf) }),
							Pseq(#[1, 5, 8], 1)
						], inf)
					]),
					\amp, 0.25
				)),
				csmin: Pbind(
					\dur, Pexprand(0.8, 1.25, inf) * Pseg(
						Pseq([0.3, 0.9], inf),
						Pwhite(2.5, 6.0, inf),
						\exp
					),
					\sustain, Pwhite(0.25, 0.5, inf),
					\octave, 3,
					\deg, Pseq([-1, 3.5, 6, 10.5, 12,
						Pseq([
							Pxrand(#[12, 13, 17.5, 18, 22], { rrand(3, 7, inf) }),
							Pseq(#[-1, 3.5, 6], 1)
						], inf)
					]),
					\amp, 0.25
				),
				bigAChord: Pbind(
					\dur, Pexprand(0.15, 0.35, inf),
					\sustain, 7,
					\octave, 3,
					\deg, Pseq(#[-3, 4, 10, 14, 15, 18], 1),
					\amp, 0.07
				),
				eminTrans: Pbind(
					\dur, Pbeta(0.8, 1.8, 0.5, 0.5, inf),
					\sustain, 0.45,
					\octave, 5,
					\deg, \patRejectLastN.eval(Pindex(
						#[1, 2, 3,  7,  -1,  5],
						// plazy around Env().asStream is necessary
						// otherwise the envelope's stream never resets
						Pwhite(0,
							Plazy({ Env(#[0, 3], #[30], 2.4).asStream }).collect { |upper| upper.asInteger + 2 },
							inf
						)
					), 1),
					\amp, 0.25
				),
				coda: Pbind(
					\dur, Pconst({ ~codaDurPoolStream.next }, Pwhite(1.0, 3.5, inf)),
					\sustain, Pseq([Pwhite(1.2, 2.1, 1), Pn(0.25, inf)]),
					\octave, 5,
					\deg, Pseq([Plazy({ |ev| ~codaNotePoolStream.next(ev).scramble }), Pn(0, inf)]),
					\amp, Pseq([0.05, Pn(0.25, inf)]),
					\strum, Pstutter(1000, Pwhite(0.2, 0.45, 1))
				)
			);

			// need to replicate PnNilSafe logic
			// so that a gesture can choose to stop play
			~gesture = Prout({ |inval|
				var zeroDurLimit = 10, then = 0, gst;
				if(~gstStream.isNil) { ~makeStreamForKey.(\gst) };
				while { zeroDurLimit > 0 and: {
					(gst = ~gstStream.next(inval)).notNil
				} } {
					inval = ~gestures[gst].embedInStream(inval);
					if((thisThread.beats - then) < 0.00001) {
						zeroDurLimit = zeroDurLimit - 1
					} {
						zeroDurLimit = 10;
					};
					then = thisThread.beats;
				};
				inval
			});

			~degree = Pfunc({ |ev| ev[\deg].dup(3).flat });
			~root = 2;
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
			~sustainAmp = 0.6;
			~desiredSusAmp = 0.6;
			// ~envel = [Env.adsr(0.5, 0.6, 0.6, 4, curve: #[2, -1, -4])];
			~envel = Pfunc({ |ev|
				[Env.adsr(
					0.5, 0.6, ev[\sustainAmp], 4,
					peakLevel: ev[\desiredSusAmp] / ev[\sustainAmp],
					curve: #[2, -1, -4]
				)]
			});
			~excamp = 1.2;
			~amp = 0.1;

			~codaNotePool = Pseq(#[
				[-1, 0, 1, 6], [-3, 1, 3], [-2, 0, 1, 4], [-1, 0, 1],
				[0, 1, 4], [-1, 0, 1], [0, 1, 4], [-1, 0, 1],
				[-2, 3, 4], [-1, 0, 1], [0, 1]
			]);

			~codaDurPool = Pseq(#[14, 9, 5, 5,  4.5, 5.5, 5, 8,  6, 5, 300]);

			// little hack: gesture pattern can override main-calc pattern
			~asPattern = {
				var gestureEvent;
				Pchain(
					Pfunc({ |ev| ev.putAll(gestureEvent) }),
					Pif(
						Pfunc(_.isRest),
						Pfunc({ |ev| ev }),
						Pbind(
							\instrument, BPStream(\defName),
							\degree, BPStream(\degree),
							\root, BPStream(\root),
							#[freq, topFreq], BPStream(\freqStuff),
							\ffreq, BPStream(\ffreq),
							\fratio, Pkey(\ffreq) / Pkey(\topFreq),
							\ampFactor, Pkey(\ffreq).linlin(1600, 12000, 1.0, 0.08),
							\ctranspose, BPStream(\ctranspose),
							// I see... because I hacked \freq above,
							// I need to reapply ctranspose here
							\freq, Pkey(\freq) * Pkey(\ctranspose).midiratio,
							\pan, BPStream(\pan),
							\sustainAmp, BPStream(\sustainAmp),
							\desiredSusAmp, BPStream(\desiredSusAmp),
							\env, BPStream(\envel),
							\excamp, BPStream(\excamp) * Pkey(\ampFactor),
							\amp, BPStream(\amp)
						)
					),
					BPStream(\gesture).collect { |ev| gestureEvent = ev; ev }
				)
			};

			// I cannot BELIEVE this actually worked the first time!
			~nextEventNow = { |quant|
				var oldPlayer, newPlayer;
				var doIt = {
					if(~isPlaying) {
						oldPlayer = ~eventStreamPlayer;
						// make a new stream player, fix dependants etc.
						newPlayer = BP(~collIndex).asEventStreamPlayer;
						~clock.sched(0, newPlayer.refresh);
						// this doesn't kill the BP because the old dependency is already broken
						oldPlayer.stop;
					};
				};
				if(quant.isNil) {
					doIt.value
				} {
					doIt.fork(~clock, quant);
				};
				currentEnvironment
			};

			~gestureNow = { |keyPat, overrideDoneFunc|
				~override.(\gesture, Psym(Pn(keyPat, 1), ~gestures), false, overrideDoneFunc);
				~nextEventNow.();
				currentEnvironment
			};

			~setGstNow = { |gstPat, quant|
				~gst = gstPat;
				~makeStreamForKey.(\gesture);  // start 'gesture' fresh with the new choice
				~nextEventNow.(quant);         // go immediately
				currentEnvironment
			};
		} => PR(\shengDrone);

		// should abstract this into a general spawner prototype
		PR(\basicSynthChooser).clone {
			// ~event = (eventKey: \singleSynthPlayer);
			// ~initLevel: may supply at chuck time
			~requiredKeys = #[sharedReady];

			~userprep = {
				~chan.newPostSend(~rvbmc ? topEnvironment[\rvbmc], -3.32.dbamp);
				if(~initLevel.notNil) { ~chan.level = ~initLevel };
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
						// zombie armor: if DetectSilence doesn't stop the synth,
						// then this definitely will
						Line.kr(0, 1, klDcy + excDcy, doneAction: 2);
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

			~durBase = Pnaryop(\lincurve, Pwhite(0.0, 1.0, inf), #[0, 1, 0.09, 0.41, -2]);
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
			~hpfreq = (Prand(#[62, 69], inf) + (12 * Pwhite(2, 5))).midicps;
			~hprq = Pn(0.05, inf); // rrand(0.1, 0.4);
			~env = Pfunc({ [Env.adsr(0.01, rrand(0.02, 0.15), 0.05, 0.03).asArray] });
			~zzampFactor = 1/8 * (-6.dbamp);

			~patAmpEnvs = [
				Env(#[0.01, 0.8, 0.8, 0.15], [0.4, 0.2, 0.4], #[2, 0, -2])
			];
			~patAmpEnv = { ~patAmpEnvs.choose };
			~patDurEnvs = [
				Env(#[1, 2], #[1], -1.5),
				Env(#[1.5, 1, 2], #[0.35, 0.65], -1.5)
			];
			~patDurEnv = { ~patDurEnvs.choose };

			// you can mess with this
			~postPattern = {
				var dur = ~phraseDurStream.next;
				Pfindur(dur, Pbind(
					\amp, ~patAmpEnv.value.copy.duration_(dur).asStream * Pkey(\ampFactor),
					\dur, Plazy({ ~dur }) * ~patDurEnv.value.copy.duration_(dur),
					\pan, Plazy({ ~panStream.next.loop })
				))
			};

			// don't mess with this
			~asPattern = {
				Pspawner({ |sp|
					var synth, waitTime;
					block { |break|
						loop {
							synth = ~synthStream.next;
							sp.par(
								Pchain(
									~postPattern.(),
									~objects[synth][\pattern],
									(instrument: synth)
								)
							);
							waitTime = ~waitTimeStream.next;
							if(waitTime.notNil) {
								sp.wait(waitTime);
							} {
								break.();
							}
						};
					};
				})
			};

			// ~prepareArgsForOneDef = { |id|
			// 	~objects[id][\lazyPat] = Plazy({ ~objects[pattern] });
			// };
			~prepareArgsForOneDef = nil;
			~getUserArgs = nil;
		} => PR(\clicks);

		SynthDef(\klinks2, { |out, bufnum = #[0, 0], amp = 0.1,
			excfreq = 100, excDetune = 1, excAtk = 0.01, excDcy = 0.05,
			klAtk = 0, klDcy = 1,
			pan = 0|
			var exc = Osc.ar(bufnum, excfreq * [1, excDetune], Rand(0, pi) + [0, pi], amp) * Decay2.ar(
				Impulse.ar(0), excAtk, excDcy),
			specs = NamedControl.kr(\specs, #[621.62188989246, 458.28750962083, 483.12690995039, 1341.4332586515, 229.71349364755, 0.1, 0.1, 0.1, 0.1, 0.1, 0.16730279340267, 0.039352280429134, 0.13997095946335, 0.030161787383422, 0.14313835788342]).clump(5),
			sig = Klank.ar(`specs, exc, decayscale: klDcy) - Klank.ar(`specs, exc, decayscale: klAtk);
			DetectSilence.ar(sig, doneAction: 2);
			Out.ar(out, Balance2.ar(sig[0], sig[1], pan));
		}).add;

		PR(\abstractProcess).clone {
			~event = (eventKey: \polySynthPlayer);

			~prep = {
				~chan = MixerChannel(~collIndex, s, 2, 2/*, completionFunc: nil*/);
				~event[\chan] = ~chan;
				~event[\instrument] = \klinks2;

				~detuneCtl = GenericGlobalControl(\detuneRatio, nil, 1, #[1, 2, \exp]);

				currentEnvironment
			};

			~freeCleanup = { [~chan, ~detuneCtl].free };
			~useGui = { |vpi| ~detuneCtl => VP(vpi) };

			~instrument = \klinks2;
			~delta = Pwhite(1, 3, inf);
			~bufnum = Plazy({ Pxrand(BP(\shengShared).noiseBufs, inf).clump(2).collect([_]) });
			~degree = Pxrand([0, 4, Pwhite(9, 10, 1)], inf).clump(2); //Pwhite(0, 4, inf);
			~octave = 2;
			~filtOctave = 3;
			~mode = \d;
			~excfreq = Pfunc({ |ev|
				var mode = ev[\mode].asMode;
				mode.cps(ev[\degree] + (mode.scale.size * ev[\octave]))
			});
			~excAtk = 0.002;
			~excDcy = 1.5;
			~klAtk = 0.25;
			~klDcy = 7;
			~amp = 0.1;
			~detuneRatio = Plazy({ ~detuneCtl.asPattern });
			~specs = (Pkey(\excfreq) * (2 ** (Pkey(\filtOctave) - Pkey(\octave))) * (1..5) * (Pexprand(Pkey(\detuneRatio).reciprocal, Pkey(\detuneRatio), inf).clump(5))).collect([_]);

			~asPattern = {
				Pbind(
					\bufnum, BPStream(\bufnum),
					\degree, BPStream(\degree),
					\octave, BPStream(\octave),
					\mode, BPStream(\mode),
					\excfreq, BPStream(\excfreq),
					\excAtk, BPStream(\excAtk),
					\excDcy, BPStream(\excDcy),
					\klAtk, BPStream(\klAtk),
					\klDcy, BPStream(\klDcy),
					\amp, BPStream(\amp),
					\filtOctave, BPStream(\filtOctave),
					\detuneRatio, BPStream(\detuneRatio),
					\specs, BPStream(\specs),
					\delta, BPStream(\delta)
				);
			};
		} => PR(\lowbells);


		SynthDef(\zzipbpf, { |out, bufnum, freq = 440, dtune = 1.003,
			hpfreq = 800, hprq = 1, hptime = 0.002,
			amp = 0.1, gate = 1, pan = 0|
			var f = VarLag.kr(freq, hptime),
			sig = VOsc3.ar(bufnum, f / dtune, f, f * dtune, amp),
			env = NamedControl.kr(\env, Env.asr(0.02, 1, 0.02).asArray.extend(32, 0));
			sig = BPF.ar(sig, VarLag.kr(hpfreq, hptime), VarLag.kr(hprq, hptime));
			Out.ar(out, Pan2.ar(sig, pan, EnvGen.kr(env, gate, doneAction: 2)));
		}).add;

		PR(\abstractProcess).clone {
			~alwaysReset = true;
			~event = (eventKey: \default);
			~prep = {
				~chan = MixerChannel(~collIndex, s, 2, 2, ~initLevel, outbus: ~master, completionFunc: { |chan|
					chan.newPostSend(~rvbmc, 0.5);
				});
				~event.put(\out, ~chan.inbus).put(\group, ~chan.synthgroup);
				~makePMonoWrapper.();
				~makeOneChirpPattern.();
				currentEnvironment
			};
			~freeCleanup = { ~chan.free	};

			~defname = \zzipbpf;

			~chirpDur = Pwhite(1.0, 3.2, inf);
			~restDur = Pwhite(3.0, 7.0, inf);
			~phrase = Pfunc({ ~phrases.keys.choose });

			// Plazy: don't access shengShared until play time
			~bufnum = Plazy({ Prand(BP(\shengShared).noiseBufs, inf) });
			~freq = Pexprand(25, 50, inf);
			~hprq = 0.01;
			~amp = 3;
			// ~sendGate = false;
			// ~env = Env.linen(0.05, 0.08, 0.05);

			~phrases = (
				saw: Pbind(
					\hpfreq, Plazy({ Pseq([exprand(3000, 5000), exprand(1000, 2000)], rrand(3, 6), 2.rand) }),
					\delta, Plazy({ Pseq([rrand(0.08, 0.12), 0.01], inf) })
				),
				sqr: Pbind(
					\hpfreq, Plazy({ Pseq([exprand(3000, 5000), exprand(1000, 2000)], rrand(3, 6), 2.rand) }),
					\delta, Plazy({ rrand(0.06, 0.11).loop }),
					\hptime, Pkey(\delta) * 0.25
				),
				randHi: Pbind(
					\hpfreq, Pfin(
						{ rrand(5, 11) },
						Pseq([
							Pwhite(2, 3, { rrand(1, 2) }),
							1
						], inf) *.x Pexprand(800, 3000, { rrand(1, 2) })
					),
					\delta, Pexprand(0.05, 0.15, inf)
				)
			);

			~makeOneChirpPattern = {
				~oneChirpPattern = Pfindur(BPStream(\chirpDur).asStream, Psym(BPStream(\phrase), ~phrases));
			};

			~makePMonoWrapper = {
				~pmonoWrapper = Pmono(
					~defname,
					\hptime, Pfunc({ |ev|
						if(ev[\hptime].isNil) { ev.delta } { ev[\hptime] }
					}),
					\amp, BPStream(\amp)
				);
			};

			~asPattern = {
				~restDurStream ?? { ~makeStreamForKey.(\restDur) };
				Pseq([
					Pchain(
						Plazy({ ~pmonoWrapper }),  // in case you change the wrapper
						Plazy({ ~oneChirpPattern }),  // likewise
						Pbind(
							\bufnum, BPStream(\bufnum),
							\freq, BPStream(\freq),
							\hprq, BPStream(\hprq),
						)
					),
					Plazy({ |inval| Event.silent(~restDurStream.next(inval), inval) })
				], inf)
			};
		} => PR(\birds);

		{	|name(\bowedFM)|
			VC(name).free;
			Fact(\madfmVC).chuck(VC(name), nil, (
				master: ~master, rvbmc: ~rvbmc,
				initLevel: -14.dbamp
			));
			VC(name).env.use {
				~target.newPostSend(~rvbmc, 0.6);
				~target.playfx({ |outbus, feedback = 0.7|
					var sig = Instr("busfx.chorus").ar(outbus, 2, 0.015468872882259, 0.017575106248548, 0.0068811564687238, 2.7569078388645, 0.5),
					delaytime = 60/88 * 0.75, // - ControlDur.ir,
					// rolling my own pingpong delay b/c PingPong clicks at delay transition :-@
					// feedbacks = LocalIn.ar(2) * feedback,
					// delay = DelayL.ar((sig + feedbacks).rotate(1), delaytime, delaytime);
					// LocalOut.ar(delay);
					delay = PingPong.ar(
						LocalBuf((delaytime * s.sampleRate).nextPowerOfTwo, 2).clear,
						sig, delaytime, feedback
					);
					sig + delay
				});
			};
			VC(name)
		} => Func(\makeBowedBellVC);

		PR(\abstractProcess).clone {
			~event = (eventKey: \voicerNote);

			~degree = Pseq([#[35, 42], #[35, 42], #[33, 36, 41]], 1) + 7;
			~mode = \d;
			~mod_lev = 2.5;
			~mod_ratio1 = 11;
			~mod_ratio2 = Pkey(\mod_ratio1);
			~car_detune = 1.003;
			~pan = Pwhite(0.8, 1.0, inf) * Pseq(#[-1, 1], inf, { 2.rand });
			~dur = 1;
			~length = 1;
			~gate = 0.5;
			~mod_env = [Env.adsr(0.8, 0.3, 0.4, 2.8, curve: #[2, -4, -4]).releaseNode_(nil)];
			~car_env = ~mod_env;

			~doAction = {
				var event;
				if(~eventsStream.isNil) { ~reset.() };
				event = ~eventsStream.next(~event.copy);
				if(event.notNil) {
					event.play;
				} {
					"BP(%): no event to play".format(~collIndex.asCompileString).warn;
				};
			};
			~reset = {
				~eventsStream = ~makePattern.().asStream;
			};
			~makePattern = {
				Pbind(
					\mode, BPStream(\mode, resetSource: true),
					\freq, BPStream(\degree, resetSource: true),
					\dur, BPStream(\dur, resetSource: true),
					\length, BPStream(\length, resetSource: true),
					\gate, BPStream(\gate, resetSource: true),
					\mod_lev, BPStream(\mod_lev, resetSource: true),
					\mod_ratio1, BPStream(\mod_ratio1, resetSource: true),
					\mod_ratio2, BPStream(\mod_ratio2, resetSource: true),
					\car_detune, BPStream(\car_detune, resetSource: true),
					\pan, BPStream(\pan, resetSource: true),
					\mod_env, Pfunc({ ~mod_env }),
					\car_env, Pfunc({ ~car_env })
				);
			};
		} => PR(\bowed);

		PR(\abstractProcess).clone {
			~quant = 0;
			~targetBP = \sd;
			~gstPatSeq = Pbind(
				\gstPat, Pseq([
					Pn(\ebnat, 2), \gb,
					Pxrand([
						`Pseq(#[da, gb], 1),
						`Pseq(#[da, gbcs], 1),
						`Pseq(#[da, ebnat], 1)
					], inf)
				], 1),
				\override, 1
			);
			~selectors = (
				1: \gestureNow,
				0: \setGstNow
			);
			~reset = {
				~gstPatStream = ~gstPatSeq.asStream;
			};
			~doAction = {
				var event;
				if(~gstPatStream.isNil) { ~reset.() };
				if(BP.exists(~targetBP)) {
					event = ~gstPatStream.next(());
					if(event.notNil) {
						BP(~targetBP).perform(~selectors[event[\override]], event[\gstPat].value);
					} {
						"BP(%): no event to play".format(~collIndex.asCompileString).warn;
					}
				} {
					"BP(%): target BP % doesn't exist".format(~collIndex.asCompileString, ~targetBP.asCompileString).warn;
				};
			};
		} => PR(\sdGestureCtl);

		// hacking, don't want to make a BP just for one simple gesture
		Pdef(\triAChord, Pbind(
			\type, \voicerNote,
			// lazy init: this VC doesn't exist yet
			\voicer, Plazy({ Pn(VC(\slowTri).v, inf) }),
			\args, #[],
			\holdtime, 1000,
			\dur, Pwhite(0.1, 0.4, inf),
			\totalDur, 6,
			\sustain, Pkey(\totalDur) - Ptime(),
			\ffreq, 14000,
			\gate, 0.5,
			\midinote, Pseq(#[33, 21, 45, 55, 62, 64, 69, 74, 79, 85, 90, 91], 1),
			\pan, Pseries.fromEndpoints(0, 1, 12) * Pseq(#[-1, 1], inf, { 2.rand })
		));

		// quick trigger for that chord
		// the BP wrapper to run the sequence, then stop, worked ON THE FIRST TRY
		// :-O
		PR(\abstractProcess).clone {
			~quant = 0;
			~alwaysReset = true;
			~event = (eventKey: \hang);
			~prep = {
				~cond = Condition.new;
				~event[\cond] = ~cond;
				~event[\action] = e {
					~tlseq = TLSequenceIterator(~seq.value)
					.onStop_(~onSeqStop)
					.play(0, thisThread.clock);
					// oops, TLSeq doesn't go thru NotificationCenter if it's stopped explicitly
					// ~resp = NotificationCenter.registerOneShot(~tlseq, \done, ~collIndex, e { ~cond.unhang });
					~resp = SimpleController(~tlseq).put(\done, e {
						~resp.remove;
						~cond.unhang;
					});
				};
			};
			~freeCleanup = { ~resp.remove };
			~seq = [
				bpCmd: (name: \sd,
					prepareBP: { |p|
						~saveGst = p.gst;
						p.setGstNow(Pn(\bigAChord, 1).trace);
						p.reset;  // don't know why I need this, but it breaks without it
					},
					clearDoneSignal: {
						~isRunning = false;
						BP(\sd).stopNow;
						(e { BP(\sd).setGstNow(~saveGst).debug("restored saved gesture") }).defer(0.1);
					}
				),
				0.4,
				pdefCmd: (name: \triAChord),
				gcAutoSynthCmd: (
					gc: { VC(\slowTri).globalControls[\lpfreq] },
					name: \ctlEnv, outName: \outbus,
					connect: 0,
					env: Env(#[900, 7500, 1700], #[1.5, 3], \sin)
				)
			];
			~stopCleanup = { |auto|
				// auto is true if the pattern's stream
				// if(auto.not) { ~tlseq.stop };
				~tlseq.stop;
			};
			~asPattern = {
				Pn((delta: 0), 1)
			};
		} => PR(\bigA);

	} {
		AbstractChuckArray.defaultSubType = saveSubType;
	}
};