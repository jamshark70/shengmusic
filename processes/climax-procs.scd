forkIfNeeded {
	var saveSubtype = AbstractChuckArray.defaultSubType;
	var cond = Condition.new;

	if(PR.exists(\shengShared).not) {
		loadPath(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd");
	};

	if(BP.exists(\shengShared).not) {
		PR(\shengShared) => BP(\shengShared);
		if(BP(\shengShared).ready.not) {
			NotificationCenter.registerOneShot(BP(\shengShared).v, \sharedReady, \climax, {
				cond.unhang;
			});
			cond.hang;
		};
	};

	protect {
		AbstractChuckArray.defaultSubType = \sheng;
		// unison

		// so full of hacks I could just scream
		PR(\abstractProcess).clone {
			~event = (eventKey: \voicerNote, midi: true);
			~alwaysReset = true;
			~printStopMsg = false;

			~prep = {
				~loadMIDIBuf.();
				currentEnvironment
			};

			~loadMIDIBuf = {
				~midibuf = Object.readArchive(PR(\unison).path.dirname.dirname +/+ "support/unison-parsed.txarch");
			};

			~acceptMIDIBuf = { |buf, adverb, parms|
				~midibuf = buf;
				currentEnvironment
			};

			~articString = "..|S.....S.S..|Ss.Ss.s.s.s.Ss..|S..S.Sssss.Ss>|
			..S.Sssss.Ssssssss---|
			S..S.Sss.Ssss.>|S..S.Ss---|>-->-->--|
			S..S.S.S...S..|S.Ss.S..>--|
			>-->--|>--->...>--|SS>";
			~articReader = Plazy({ Pseq(~articString, 1).select { |ch| ".sS->".includes(ch) } });

			~doublingOn_ = { |bool(false)|
				if(bool) {
					~event.finish = {
						if(~suppressAccent == 0 and: { ~isMain == 1 and: { ">S".includes(~artic) } }) {
							// roundUp: G# as topNote sounds like hell, make it A-nat
							NotificationCenter.notify(BP(~collIndex), \accent,
								[~artic, ((~freq ?? { ~note.asFloat }).first.mapMode(\d).roundUp + 7)]);
							// decouple
							// BP(\unCh).topNote.deg = ((~freq ?? { ~note.asFloat }).first.mapMode(\d).roundUp + 7);
							// BP(\unCh).triggerOneEvent(0);
						};
					};
				} {
					~event.finish = nil;
				};
			};

			~asPattern = {
				var oct = Pseq([0, -24, Pshuf(#[-12, 12, 24])]).asStream;
				Pbind(
					\note, Pseq(~midibuf.notes, 1),
					\isChord, Pfunc({ |ev|
						var a = ev[\note], i;
						ev[\suppressAccent] = a.argAt(\suppressAccent) ? 0;
						ev[\isMain] = a.argAt(\isMain) ? 0;
						a.argAt(\isChord) ? 0
					}),
					\artic, Pclutch(~articReader, Pkey(\isMain) > 0),
					\sustain, Pfunc({ |ev| ev[\note].length }),
					\length, Pnsym1(Pkey(\artic).collect({ |ch| ch.asSymbol }), (
						'.': Pkey(\sustain) * 0.6,
						's': Pkey(\sustain) + 0.05,
						'S': Pkey(\sustain) + 0.05,
						'>': Pkey(\sustain) * 0.8,
						'-': Pkey(\sustain) * 0.92
					)),
					\dur, Pfunc({ |ev| ev[\note].dur }),
					\freq, Pfunc({ |ev|
						if(ev[\isChord] > 0) {
							(ev[\note].freq + #[0, 12])
						} {
							ev[\note].freq + oct.reset.nextN(
								switch(ev[\artic], $>, 4, $S, 4, 3)
							)
						}
					}),
					\ffreq, Pfunc({ |ev|
						max(
							if(ev[\isChord] > 0) { 2500 } { 800 },
							ev[\freq].midicps * 3
						) * switch(ev[\artic], $>, 1.62, $S, 1.4, 1)
					}),
					\gate, Pif(Pfunc({ |ev| ev[\artic] == $> }), 0.7, 0.4)
				)
			};
		} => PR(\unison);

		Pn(#[0.25, 0.15, 0.5], 1) => MicRh(\unCh);

		(
			srcBP: \un,
			make: { |name|
				var p;
				BP(name).free;
				\newCh.eval(name, \arpeg1, \macroRh, MBM(0)[\pzch], nil, Pn(1, inf), \unCh, \block, nil, \d);

				p = BP(\unCh);

				p.topNote = PR(\patternTop).copy.make {
					~mode = \d;
				};

				p.child.fitFunc = \chordFitInt;

				p.child.argPairs = [
					mod_lev: Pwhite(3.5, 7.0, inf),
					mod_ratio1: Pwhite(1, 4, inf),
					mod_ratio2: Pkey(\mod_ratio1),
					car_detune: 1.006,
					mod_buf: Prand(VC(\fm).env.bufs, inf),
					keyscale: 0.001,
					pan: Pfunc({ |ev|
						var ctr = 0.5.rand2, width = (1.0 - abs(ctr)).rand,
						size = ev[\note].asFloat.size;
						Array.series(size, ctr - width, width * 2 / (size-1)).scramble
					})
				];

				if(BP.exists(~srcBP)) {
					p.recvNotify = NotificationCenter.register(BP(~srcBP), \accent, name, { |artic, nextTop|
						// slightly hacky, should put this in a method, but I'm lazy
						// I'm now inside the new BP's environment so I can do this stuff
						~topNote.deg = nextTop;
						BP(~collIndex).triggerOneEvent(0);
					}.inEnvir(p));
				};
				p.userfree = { ~recvNotify.remove };

				p.prepareForPlay;
			},
			type: \bp
		) => Fact(\unChBP);

		{ |name(\pzrhy)|
			VC(name).free;
			Fact(\pizz).chuck(VC(name), nil, (
				trigFunc: `{
					var beatsPerSec = NamedControl.kr(\beatsPerSec, 100/60),
					baseValue = NamedControl.kr(\baseValue, 0.25),
					lfoDepth = NamedControl.kr(\lfoDepth, 1),
					baseFreq = beatsPerSec / baseValue,
					lfo = LFDNoise1.kr(LFNoise1.kr(Rand(0.05, 0.09)).exprange(0.3, 1.4))
					.exprange(lfoDepth.reciprocal, lfoDepth),
					trig = Impulse.ar(baseFreq * lfo);
					trig
				}
			));
		} => Func(\makePizzRhyVC);

		MIDIRecBuf(\pzclimax, [
			[
				47, 54, 57, 62, 64, 69, 74,
				43, 50, 57, 59, 66, 67, 74, 76,
				40, 47, 52, 57, 59, 62, 68, 69, 76,
				49, 56, 57, 64, 69, 71, 76
			],
			(0.1 ! 31).put(6, 1).put(14, 1).put(23, 1).put(30, 1),
			0.5, 0.5
		].asNotes, (mode: \d, type: \ch)) => MBM(0);

		Pseq([Rest(1.5), 1.5, Rest(1.5), 1.5, 32, 11.5, 20], 1) => MacRh(\pzclimax);

		(
			make: { |name|
				var p;
				BP(name).free;
				\newCh.eval(name, \arpeg1, \macroRh, MBM(0)[\pzclimax], nil, MacRh(\pzclimax), \blockFollow, \block, nil, \d);
				p = BP(name);
				1 => p;
				p.userfree = { ~lfoDepthCtl.free };
				p.lfoDepthCtl = GenericGlobalControl(\lfoDepth, nil, 1, #[1, 3, \exp]);
				p.useGui = { |vpi| ~lfoDepthCtl => VP(vpi) };
				p.child.argPairs = { |parentEvent|
					var e = ~ampEnv.copy;
					e.times = e.times * (parentEvent[\length] / thisThread.clock.tempo);
					[
						fbamp: 0.98,
						ffreq: Pfunc({ |ev| ev[\mode].asMode.cps(ev[\note].asFloat) * rrand(6.0, 10.0) }),
						amp: 1,
						lfoDepth: BP(\pzclimax).lfoDepthCtl.asMap,
						beatsPerSec: Ptempo(),
						baseValue: 0.25,
						ctranspose: 0.51331578947368,   // sweet, in tune now!
						env: [e]
					]
				};
				p.child.makeChordPattern = { Pstutter(Pseq(#[2, 1, 1, 1000]), Pseq(~chords, 1)) };
				p.alwaysReset = true;
				p
			},
			type: \bp
		) => Fact(\pzclimaxBP);


		PR(\abstractProcess).clone {
			~event = (eventKey: \voicerNote, gate: 0.5);
			~prep = {
				~makeStreamForKey.(\bass);
			};
			~freeCleanup = { ~removeNotification.() };

			~mode = \d0;

			~bass = Pseries({ rrand(20, 27) }, Pwhite(1, 3, inf), inf).fold(20, 28);
			~freq = PnNilSafe(
				Pwhile1(
					{ |ev, next| next <= 44 },
					Pseries(
						{ |ev| ~bassStream.next(ev) },
						Pseq([Prand(#[4, 5], 1), Prand(#[2, 3], 1), Pwrand(#[1, 2, 3], #[0.1, 0.5, 0.4], inf)])
					),
					inf
				).clump(100),
				inf
			);
			~ffreq = Pfunc({ |ev|
				var top = ev[\freq].asArray.maxItem;
				ev[\mode].asMode.cps(top) * rrand(7.0, 11.0)
			});
			~amp = Pseries.fromEndpoints(0.12, 0.3, 5) ++ Pn(0.5, inf);
			~excAtk = Pn(3, 5) ++ Pn(10, inf);
			~excDcy = Pn(7, 5) ++ Pn(18, inf);
			~fbamp = 0.998;
			~pan = Pfunc({ |ev|
				var n = ev[\freq].asArray.size;
				if(n <= 1) { 0 } {
					Array.series(n, -1, 2 / (n-1)).scramble
				}
			});
			~dur = 4;
			~length = 16 * Ptempo();

			~asPattern = {
				Pbind(
					\mode, BPStream(\mode),
					\freq, BPStream(\freq),
					\ffreq, BPStream(\ffreq),
					\dur, BPStream(\dur),
					\length, BPStream(\length),
					\excAtk, BPStream(\excAtk),
					\excDcy, BPStream(\excDcy),
					\fbamp, BPStream(\fbamp),
					\pan, BPStream(\pan),
					\amp, BPStream(\amp),
				)
			};
			~addNotification = {
				~recvNotify = NotificationCenter.register(BP(~bp), \accent, ~collIndex, e { |artic|
					if(artic == $>) { BP(~collIndex).triggerOneEvent(0) };
				});
			};
			~removeNotification = { ~recvNotify.remove };
		} => PR(\sdSwells);

		(
			make: { |name|
				BP(name).free;
				PR(\bigA).chuck(BP(name), nil, (
					playUnison: true,
					onSeqStop: {
						if(VC.exists(\pzrhy)) { VC(\pzrhy).releaseAll };
						if(BP.exists(\sdSwells)) { BP(\sdSwells).removeNotification };
					},
					seqBase: [
						{	BP(\pzclimax).lfoDepthCtl.value = 1;
							VC(\pzrhy).v.globalControls[\retrigProb].value = 0.6;
							BP(\gcl).maxPoly.value = 3;
							BP(\gcl).chan.level = -3.77.dbamp;
							BP(\decelCl).chan.level = -3.77.dbamp;
							BP(\decelCl).maxPoly.value = 3;
							BP(\sd).chan.level = -2.5.dbamp;
							VC(\pzrhy).env.target.level = -7.dbamp;
							// VC(\tri).env.target.level = -9.5.dbamp;
							BP(\sdSwells).removeNotification;
							0
						},
						Quant(1),
						loopCmd: (
							id: \gclLoop,
							cmds: [
								{ rrand(3, 8) * 0.5 },
								{
									PR(\bpCmd).copy.putAll((name: \gcl, dur: rrand(8, 16) * 0.5));
								}
							]
						),
						[
							34,
							{
								BP(\sdSwells).amp = 3.dbamp * (Pseries.fromEndpoints(0.12, 0.26, 5) ++ Pn(0.334, inf));
								BP(\sdSwells).excAtk = Pn(3, 5) ++ Pn(10, inf);
								BP(\sdSwells).excDcy = Pn(7, 5) ++ Pn(18, inf);
								BP(\sdSwells).prepareForPlay;
								BP(\sdSwells).bp = \un;
								BP(\sdSwells).addNotification;
								BP(\sdSwells).reset;
								0
							}
						],
						bpCmd: (name: \un,
							prepareBP: {
								var p;  // to manipulate pzclimax
								VC(\tri).env.target.level = -9.dbamp;
								VC(\fm).env.target.level = VC(\tri).env.target.level * (-12.dbamp);

								if(BP.exists(\pzclimax)) {
									p = BP(\pzclimax);
									p.lfoDepthCtl.value = 1;
									MBM(0)[\pzch] =>.ch p;
									Pwhite(3, 6, inf) * 0.25 =>.macro p;
									p.child.makeChordPattern = { Pxrand(~chords, inf) };
									p.child.fitFunc = \chordFitNotes;
									p.topNote = PR(\patternTop).copy.make {
										~mode = \d;
										~deg = Pwhite(35, 43, inf);
									};
									p.child.ampEnv = Env(
										#[0, 1, 0.1, 0],
										#[0.01, 0.94, 0.05],
										-2, 2
									);
									if(p[\recvNotify].isNil) {
										p.recvNotify = NotificationCenter.register(BP(\un), \accent, \pzclimax, {
											BP(~collIndex).triggerOneEvent(0);
										}.inEnvir(p.env));
									};
								};
							},
							clearDoneSignal: {
								if(BP.exists(\pzclimax)) {
									BP(\pzclimax)[\recvNotify].remove;
									BP(\pzclimax)[\recvNotify] = nil;
								}
							}
						),
						\cmdSync,
						funcCmd: (func: {
							BP(\sdSwells).removeNotification;
							~iterator.findActive(\gclLoop).stop
						}),
						[
							0.5,
							bpCmd: (name: \gcl, dur: 14.5, prepareBP: { |p|
								p.maxPoly.value = 3;
							}),
							\cmdSync,
							bpCmd: (name: \decelCl, prepareBP: { |q|
								q.makeStreamForKey(\waitTime);
								q.maxPoly.value = 3;
								q.reset;
							})
						],
						subIterCmd: (
							id: \pzclimax,
							subIter: TLSequenceIterator([
								bpCmd: (name: \pzclimax,
									prepareBP: { |p|
										p.child.fitFunc = \asis;
										p.child.makeChordPattern = { Pstutter(Pseq(#[2, 1, 1, 1000]), Pseq(~chords, 1)) };
										MBM(0)[\pzclimax] =>.ch p;
										p.child.ampEnv = Env(
											#[0, 0.2, 1, 0],
											#[0.01, 0.94, 0.05],
											-4, 2
										);
										MacRh(\pzclimax) => p;
									},
									// clearDoneSignal: { { t.stop }.defer(0.05); }
								),
								\cmdSync,
								// mixerAutoSynthCmd: (
								// 	mixer: VC(\pzrhy).env.target, outName: \outbus,
								// 	name: \ctlPoint, value: 0.8, time: 0.1
								// ),
								Quant(0.25),
								// leave only pzclimax and probability-changer
								{
									BP(name).tlseq.activeCmds.do { |cmd|
										if(#[pzclimax, retrigProb].includes(cmd.tryPerform(\id)).not) {
											cmd.stop;
										};
									};
									0
								},
								bpCmd: (name: \dcdr, id: \dcdr, prepareBP: {
									BP(\dc).chan.level = -14.dbamp; // -7.4.dbamp;
									// slower than at first: this section is relaxing the energy
									BP(\dc).patDelta = Pwhite(2.5, 5.0, inf);
									BP(\dc).patDur = Pwhite(6.0, 10.0, inf);
									BP(\dc).shortDur = Pwhite(0.2, 0.4, inf);
									BP(\dc).longDur = Pwhite(0.7, 1.0, inf);
								}),
								gcAutoSynthCmd: (
									gc: BP(\pzclimax).lfoDepthCtl, name: \ctlPoint, outName: \outbus,
									value: 1, time: 24 /* sec */, curve: -2.2
								),
								bpCmd: (name: \pzclimax, prepareBP: { |p|
									// p.lfoDepthCtl.value = 1;
									MBM(0)[\pzch] =>.ch p;
									Pwhite(4, 10, inf) =>.macro p;
									p.child.makeChordPattern = { Pxrand(~chords, inf) };
									p.child.fitFunc = \chordFitNotes;
									p.topNote = PR(\patternTop).copy.make {
										~mode = \d;
										~deg = Pwhite(35, 43, inf);
									};
									p.child.ampEnv = Env(
										#[0, 1, 0.3, 0],
										#[0.01, 0.94, 0.05],
										0, 2
									);
								}),
							])
						),
						bpCmd: (name: \sd, prepareBP: { |p|
							p.setGstNow(Pseq(#[bmin, gmaj, emaj, csmin]));
							p.reset;
						}),
						15,
						// { thisThread.clock.beats.debug("gcautosynth"); 0 },
						gcAutoSynthCmd: (
							gc: BP(\pzclimax).lfoDepthCtl,
							name: \ctlEnv, outName: \outbus,
							connect: 1,
							env: Env(#[1.2, 1.9], #[8] / thisThread.clock.tempo, 4)
						),
						(12*4) + 3 + 2.5 + 1 - 24,
						// not really effective
						// { thisThread.clock.beats.debug("reduce"); VC(\pzrhy).v.globalControls[\retrigProb].value = 0.1; 0 }
						subIterCmd: (
							id: \retrigProb,
							subIter: TLSequenceIterator([
								gcAutoSynthCmd: (
									gc: BP(\pzclimax).lfoDepthCtl,
									name: \ctlEnv, outName: \outbus,
									connect: 1, time: 8,
									env: Env(#[1.9, 1.0], #[1], -4),
								),
								gcAutoSynthCmd: (
									gc: VC(\pzrhy).v.globalControls[\retrigProb],
									name: \ctlEnv, outName: \outbus,
									env: Env(#[0.6, 0.14], #[1], \sin), time: 24 / TempoClock.tempo, connect: 1
									// value: 0.1, time: 24 / TempoClock.tempo, curve: 3
								),
								\cmdSync,
								gcAutoSynthCmd: (
									gc: BP(\pzclimax).lfoDepthCtl,
									name: \ctlEnv, outName: \outbus,
									connect: 0, time: 8,
									env: Env(#[1.9, 1.0], #[1], -4),
								),
								gcAutoSynthCmd: (
									gc: VC(\pzrhy).v.globalControls[\retrigProb],
									name: \ctlEnv, outName: \outbus,
									// env: Env(#[0.14, 0.04], #[1], \sin),
									env: Env(#[0.14, 0.14, 0.015], #[0.2, 0.8], -4),
									time: 36 /* sec */, connect: 1,
									// value: 0.1, time: 24 / TempoClock.tempo, curve: 3
									clearDoneSignal: {
										"stopping everything".debug;
										BP(\pzclimax).stopNow;
										{ BP(name).tlseq.stop }.defer(0.05);
									}
								),
							])
						)
					],
					seq: {
						if(~playUnison) { ~seqBase }
						{ ~seqBase[0..1] ++ ~seqBase[x.indexOf(\cmdSync) + 1 ..] }
					}
				));

				0 => BP(name);
				BP(name)
			},
			type: \bp
		) => Fact(\climaxSeqBP);

	} { AbstractChuckArray.defaultSubType = saveSubtype };
};