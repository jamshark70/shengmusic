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
					BP(\un).event.finish = {
						if(~suppressAccent == 0 and: { ~isMain == 1 and: { ">S".includes(~artic) } }) {
							// roundUp: G# as topNote sounds like hell, make it A-nat
							BP(\unCh).topNote.deg = ((~freq ?? { ~note.asFloat }).first.mapMode(\d).roundUp + 7);
							BP(\unCh).triggerOneEvent(0);
						};
					};
				} {
					BP(\un).event.finish = nil;
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

		(make: { |name|
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

			p.prepareForPlay;
		}, type: \bp) => Fact(\unChBP);

	} { AbstractChuckArray.defaultSubType = saveSubtype };
};