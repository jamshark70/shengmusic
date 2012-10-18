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
								[((~freq ?? { ~note.asFloat }).first.mapMode(\d).roundUp + 7)]);
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
					p.recvNotify = NotificationCenter.register(BP(~srcBP), \accent, name, { |nextTop|
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

	} { AbstractChuckArray.defaultSubType = saveSubtype };
};