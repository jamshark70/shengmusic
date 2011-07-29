// demo code for 02-slow-opening-fixed.ly

// bass note, bar 19
// focus gesture after that

WrapInstr(\dronetone, { |freq, detuneRatio = 1.003, width = 0.2,
	gate = 1, vsens = 0.8, env, envScaleUp = 1, envScaleDown = 1
	bufbase = 0, numbufs = 8, basefreq = 440, topfreq = 12543|
	var	amp = (Latch.kr(gate, gate) - 1) * vsens + 1,
		// big cpu hit with this
		// sig = Pulse.ar(freq * [1, detuneRatio], width, amp).sum,
		// instead, use my buffer-mapping magic trick
		// detuneRatio should be close to 1.0, no need to calculate multiple mappings
		baselog = log2(basefreq),
		freqmap = ((log2(freq) - baselog) / (log2(topfreq) - baselog)
			* (numbufs - 1)).clip(0, numbufs - 1.001),
		freqs = freq * [1, detuneRatio],
		// http://www.musicdsp.org/showone.php?id=8
		saw1 = Osc.ar(bufbase + freqmap, freqs, 0, amp),
		saw2 = DelayL.ar(saw1, maxdelaytime: 0.1, delaytime: width / freqs),
		sig = (saw1 - saw2).sum,
		initTrig = Impulse.kr(0),
		eg_fb = Select.kr(initTrig, [LocalIn.kr(1), 0]),
		// switch timescale when env starts going down
		goingDown = (PulseCount.kr(HPZ1.kr(eg_fb) < 0) >= 1
			+ (gate <= 0)) > 0,
		scale = Select.kr(goingDown, [envScaleUp, envScaleDown]),
		eg = EnvGen.kr(env, gate, timeScale: scale, doneAction: 2);
	LocalOut.kr(eg);
	sig * eg;
}, [\freq, \mydetune, \unipolar,
	\amp, \unipolar, EnvSpec(Env.adsr), #[0.1, 10, \exp], #[0.1, 10, \exp],
	\mybuf, #[1, 16, \lin, 1], \freq, \freq
]);

WrapInstr(\highdrone, { |bpDownRatio = 0.2, rq = 0.08, mix = 0.56,
	lpsrcfreq = 4000, lpfxfreq = 8000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01|
	var	sig = WrapInstr.wrap(\dronetone),
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfxfreq * bpDownRatio, lpfxfreq),
		filts;
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	XFade2.ar(LPF.ar(sig, lpsrcfreq), LPF.ar(filts, lpfxfreq), mix);
}, [#[0.1, 1.0, \exp], \myrq, \bipolar, \freq, \freq,
	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp]
]);

WrapInstr(\droneFiltEnv, { |bpDownRatio = 0.2, rq = 0.08, mix = 0.56,
	lpsrcfreq = 4000, lpfxfreq = 8000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01,
	fenv, gate = 1|
	var	sig = WrapInstr.wrap(\dronetone, [nil, nil, nil, gate]),
	filtenv = fenv.dereference.value,
	feg = EnvGen.kr(filtenv, gate),
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfxfreq * feg * bpDownRatio, lpfxfreq),
		filts;
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	XFade2.ar(LPF.ar(sig, lpsrcfreq * feg), LPF.ar(filts, lpfxfreq), mix);
}, [#[0.1, 1.0, \exp], \myrq, \bipolar, \freq, \freq,
	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp],
	EnvSpec(Env.one), #[0, 1]
]);

(
keys: #[master],
wrapinstr: \highdrone,
voicerargs: {
	[
		env: Env.adsr(0.9, 1.2, 0.8, 1.8), chorusFreq: `0.1, chorusDelay: `0.018,
		chorusWidth: `0.01, vsens: 0.8, lpsrcfreq: 2800, lpfxfreq: 7000,
		bufbase: `(~bufs[0].bufnum), numbufs: `(~bufs.size),
		basefreq: `(48.midicps), topfreq: `16744,
		mix: 0.3
	] ++ ~extraArgs.()
},
extraArgs: nil,
make: { |name|
	var	out;
	~target = MixerChannel(name, s, 2, 2, level: -20.dbamp, outbus: ~master);
	// // KABOOM
	// ~bufs = \makeWavetables.eval(8, s, 1024, 48, { |numharm|
	// 	Array.sawtoothAmps(numharm)
	// });

	~bufs = Buffer.allocConsecutive(8, s, 1024, 1);
//	fork {
		\modWavetables.eval(~bufs, 48, { |numharm|
//			0.1.wait;
			Array.sawtoothAmps(numharm)
		});
//	};
	out = Voicer(20, WrapInstr(~wrapinstr), ~voicerargs.value, target: ~target);
	// out.mapGlobal(\width, nil, 0.2, #[0.02, 0.98]);
	out.mapGlobal(\rq, nil, 0.08, \myrq);
	// out.mapGlobal(\mix, nil, 0.3, \bipolar);
	~widthCtl = GenericGlobalControl(\width, nil, 0.2, #[0.02, 0.98]);
	out
}, free: { [~target, ~widthCtl, ~bufs].free }, type: \voicer) => Fact(\pulseDrone);

(
keys: #[master],
make: { |name|
	var out;
	~target = MixerChannel(name, s, 1, 2, /*level: ,*/ outbus: ~master, completionFunc: { |chan|
		~chorus = chan.playfx(Instr("busfx.chorus2band2"), [0, 1, 3, 0.019929544097472, 0.10529309760794, 0.010555364844924, 0.84697339184144, 189.85848040307, 0.5]);
	});
	~cb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
		buf.sine1Msg(#[1]);
	});
	~mb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
		buf.sine1Msg(#[1, 0.5, 0.25]);
	});
	out = MonoPortaVoicer(1, WrapInstr("osc2.fm1porta"), [
		car_buf: `~cb, mod_buf: `~mb, /*mod_lev: 0.302,*/ mod_ratio: 0.5,
		mod_env: Env.adsr(0.01, 0.14, 1/3, 3, 3),
		car_vs: 0.4, mod_vs: 0.7
	], target: ~target);
	out.mapGlobal(\mod_lev, nil, 1.8, #[0.01, 8, \exponential]);
	out.portaTime = 0.3;
	out
},
free: { [~target, ~cb, ~mb].free },
type: \voicer) => Fact(\fmbass);

(
keys: #[master],
make: { |name|
	var	out;

//	VC(name).free;  // this breaks stuff
	~target = MixerChannel(name, s, 2, 2, level: -12.dbamp, outbus: ~master/*, completionFunc: {  }*/);

	~cb = Buffer(s, 2048, 1);
	~mb = Buffer(s, 2048, 1);
	// just being EXTRA careful about possible supernova crash
	fork {
		~cb.alloc;
		~mb.alloc;
		s.sync;
		~cb.sine1(#[1, 0, 0, 0, 0, 0, 0.3]);
		~mb.sine1(#[1]);
	};

	WrapInstr("osc2.fm2carpan", { |pan|
		Pan2.ar(WrapInstr.wrap("osc2.fm2car"), pan)
	}, [\bipolar]);

	out = Voicer(8, WrapInstr("osc2.fm2carpan"), [mod_lev: 4.13, mod_ratio: 5, car_detune: `1.00288, car_vs: `0.2697, mod_vs: `0.8, basefreq: `440, keyscale: `0.337, car_buf: `~cb, mod_buf: `~mb, car_env: UGenFunc({ Env.perc(0.01, NamedControl(\sustain, 1)) }), mod_env: UGenFunc({ var sus = NamedControl(\sustain, 1); Env(#[0, 1, 0.2], [0.01, sus], -4) })], target: ~target);
	out.mapGlobal(\detune, nil, 1.63, #[-5, 5]);
	out
},
free: { [~target, ~cb, ~mb].free },
type: \voicer) => Fact(\fmbell);


PR(\abstractProcess).clone {
	// nextDelta needs to be false by default for use in Pgate
	~event = (eventKey: \voicerNote, nextDelta: false);
	~alwaysReset = true;
	~printStopMsg = false;

	~mode = \d;
	~top = Pfsm([
		#[0, 1],
		Prout({ |ev|
			ev[\nextDelta] = true;  // this is a hack
			Pseq(#[7, 4], 1).embedInStream(ev)
		}), #[0, 1].weight(#[1, 3]),
		Prout({ |ev|
			ev[\nextDelta] = true;
			Pseq(#[7, 8], 1).embedInStream(ev)
		}), #[0, 1, 2, 3].weight(#[3, 2, 1, 11]),
		Pfuncn({ |ev| ev[\nextDelta] = true; 11 }), #[0, 1],
		Pfuncn({ |ev| ev[\nextDelta] = true; 11 }), #[4],
		nil, nil
	]) + 35;
	~degree = Pkey(\top);
	~gate = Pfunc({ |ev| (0.2 ! ev[\freq].size).put(0, 0.5) });
	~delta = Pgate(
		Pif(
			Pkey(\top) < 46,
			Pstutter(Pwrand(#[1, 2, 3], #[6, 3, 1].normalizeSum, inf),
				Pwhite(0.4, 0.7) * Prand(#[0.5, 1], inf)),
			Pwhite(3, 5, inf) * 0.5
		), inf, \nextDelta
	);
	~length = Pkey(\delta) * Pif(Pkey(\delta) < 1, 0.6, 1);
	~width = Pwhite(0.08, 0.18, inf);
	~lpsrcfreq = 2000;
	~lpfxfreq = Pexprand(2000, 6000, inf);  // Pexprand(3000, 12000, inf);
	~mix = Pwhite(0.6, 1.0, inf);
	~bpDownRatio = 0.7;
	~envScaleUp = 0.2;
	~envScaleDown = 0.7;

	~bottoms = (39: 34, 42: 33, 43: 37, 46: 38);

	~degree = Pn(
		(Pfin(1, Pkey(\top)) -.x Paccum(
			start: 0,
			step: Pconst(
				(Pkey(\top) - Pfunc({ |ev| ~bottoms[ev[\top]] })).asStream,
				Pwhite(1, 3, inf)
			),
			length: inf)
		).clump(100),
		inf
	);

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\top, BPStream(\top, resetSource: true),
			\freq, BPStream(\degree, resetSource: true),
			\gate, BPStream(\gate),
			\delta, BPStream(\delta, resetSource: true),
			\length, BPStream(\length),
			\width, BPStream(\width),
			\lpsrcfreq, BPStream(\lpsrcfreq),
			\lpfxfreq, BPStream(\lpfxfreq),
			\mix, BPStream(\mix),
			\bpDownRatio, BPStream(\bpDownRatio),
			\envScaleUp, BPStream(\envScaleUp),
			\envScaleDown, BPStream(\envScaleDown)
		)
	};
} => PR(\brightChords);

(
make: { |name|
	BP(name).free;
	PR(\brightChords).chuck(BP(name), nil, (
		topstutter: 100,
		// will always refresh b/c of resetSource: true
		top: Plazy({
			Pstutter(~topstutter, Pxrand(#[46, 47], inf))
		}),
		degstutter: 100,
		degree: Plazy({
			var	chordify = Pn(
				(Pfin(1, Pkey(\top)) -.x Paccum(
					start: 0,
					step: Pconst(
						(Pkey(\top) - Prand((33..40) ++ 38.5, inf)).asStream,
						Pwhite(1, 3, inf)
					),
					length: inf)
				).clump(100),
				inf
			);
			Pswitch1(Pstutter(~degstutter, chordify) ! 2, Pkey(\top) - 46)
		}),
		delta: Pseq([Pstutter(Pwhite(3, 10, 1), Pwhite(0.12, 0.28, inf)), Pwhite(0.7, 1.1, 1)], 1),
		length: Pkey(\delta) * Pif(Pkey(\delta) < 0.7, 0.3, 1)
	));
	0 => BP(name);
}, type: \bp) => Fact(\rptChords);

PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote);

	~mode = \d;
	~notes = #[35];
	~degree = Plazy({
		Pindex(
			~notes,
			if(~notes.size > 1) {
				// Pseq([0, Pshuf((1 .. ~notes.size-1), 1), Pshuf((0 .. ~notes.size-1), inf)], 1)
				PnNilSafe(Plazy({ Pshuf((0 .. ~notes.size-1), 1) }), inf)
			} {
				Pn(0, inf)
			}
		)
	});
	~dur = Pseq([
		Pwhite(1.8, 3.5, { rrand(3, 7) }),
		Pwhite(0.4, 0.9, { rrand(3, 9) })
	], inf);
	~sustain = Pwhite(7.0, 14.0, inf);
	~envScaleUp = 0.6;
	~fAtk = Pif(Pkey(\dur) >= 1.8, 0.3, 0.1);
	~fDcy = Pkey(\dur) * Pwhite(0.5, 0.75, inf);
	~fSus = 0.0;
	~fSens = 0.9;
	~gate = Pexprand(0.2, 0.7, inf);
	~lpsrcfreq = Pexprand(1800, 3200, inf);
	~lpfxfreq = Pexprand(5000, 10000, inf);

	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\degree),
			\dur, BPStream(\dur),
			\length, BPStream(\sustain),
			\envScaleUp, BPStream(\envScaleUp),
			\fAtk, BPStream(\fAtk),
			\fDcy, BPStream(\fDcy),
			\fSus, BPStream(\fSus),
			\fSens, BPStream(\fSens),
			\gate, BPStream(\gate),
			\lpsrcfreq, BPStream(\lpsrcfreq),
			\lpfxfreq, BPStream(\lpfxfreq) //,
			// \width, BPStream(\width)
		)
	};

	~setNotes = { |noteArray(#[0]), quant|
		~notes = noteArray;
		~makeStreamForKey.(\degree);
		~resetTime.(quant);
	};

	~resetTime = { |quant|
		if(~isPlaying and: { quant.notNil }) {
			~eventStreamPlayer.stop;
			~eventStreamPlayer = EventStreamPlayer(~eventStream, ~event);
			~eventStreamPlayer.play(~clock, quant: quant);
		};
	};

	~bindVoicer = { |vc|
		~vcKey = VC.keys.detect { |key| VC(key).value === vc };
		~event.put(\width, VC(~vcKey).env.widthCtl.asMap);
		currentEnvironment
	};
} => PR(\dedrone);

(
make: { |name|
	BP(name).free;
	PR(\mel1).chuck(BP(name), nil, (
		repeats: 1,
		printStopMsg: false
	));
	1 => BP(name);
	try {
		MBM(0).v[\ebass] => BP(name);
	} { |err|
		if(err.class == DoesNotUnderstandError and: { err.selector == \v }) {
			"MBM(0) doesn't exist; couldn't set melody for BP(%)."
			.format(name.asCompileString).warn;
		} {
			err.throw
		}
	};
	BP(name)
}, type: \bp) => Fact(\ebassBP);

ProtoEvent(\voicerNote).copy.make {
	~droneQuant = 1;
	~superPlay = ~play;
	~play = { |server|
		~superPlay.(server);
		if(~droneBP.notNil) {
			if(~addNotes ? false) {
				BP(~droneBP).setNotes((BP(~droneBP).notes ++ ~freq), nil);
			};
			BP(~droneBP).override(\degree, Pn(~freq, 1));
			BP(~droneBP).resetTime(~droneQuant);
		};
	};
} => ProtoEvent(\bellAccent);

PR(\abstractProcess).clone {
	~event = (eventKey: \bellAccent, droneBP: \dd);
	~alwaysReset = true;
	~mode = \d;
	~degree = 35;
	~dur = 8;
	~sustain = Pwhite(5.0, 8.0, inf);
	~gate = Pexprand(0.2, 0.7, inf);
	~pan = Pwhite(-0.9, 0.9, inf);
	~mod_lev = 4.13;
	~mod_ratio = 5;
	~addNotes = false;
	~asPattern = {
		Pbind(
			\mode, BPStream(\mode),
			\freq, BPStream(\degree, resetSource: true),
			\dur, BPStream(\dur, resetSource: true),
			\length, BPStream(\sustain),
			\sustain, Pkey(\length),
			\gate, BPStream(\gate),
			\pan, BPStream(\pan),
			\mod_lev, BPStream(\mod_lev), 
			\mod_ratio, BPStream(\mod_ratio),
			\addNotes, BPStream(\addNotes)
		)
	};
} => PR(\bellAccent);


if(MBM.exists(0).not) { MIDIBufManager(chan: nil) => MBM.prNew(0) };

MIDIRecBuf(\ebass, [
	#[40, 45, 35, 40, 38, 43, 42],
	#[3, 1, 3, 1, 1.5, 3, 3.5],
	#[2.9, 1.1, 2.9, 1.1, 1.4, 3.1, 3.5],
	0.5
].asNotes) => MBM(0);

\chuckIf.eval(ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 2), Mode, \d);
\chuckIf.eval(ModalSpec(#[0, 2, 4, 6, 7, 9, 11], 12, 2), Mode, \dlyd);

PR(\demoProto).copy.putAll((
	name: "1. Slow melody",

	prepare: {
		~master = topEnvironment[\master];  // needed for VC's
		\chuckIf.eval(Fact(\pulseDrone), VC, \pd);
		\chuckIf.eval(Fact(\pulseDrone), VC, \pdswp, nil, (
			wrapinstr: \droneFiltEnv,
			extraArgs: [fenv: `{
				var	fAtk = NamedControl.kr(\fAtk, 0.1),
				fDcy = NamedControl.kr(\fDcy, 0.2),
				fSus = NamedControl.kr(\fSus, 0.3),
				fRel = NamedControl.kr(\fRel, 5.0),
				fSens = max(0.01, NamedControl.kr(\fSens, 0.01));
				Env.adsr(fAtk, fDcy, fSus, fRel, peakLevel: fSens, bias: 1 - fSens, curve: \exp)
			}]
		));

		\chuckIf.eval(Fact(\fmbass), VC, \fmb);
		\chuckIf.eval(Fact(\fmbell), VC, \fmbell);

		VC(\pd).env.target.level = -18.dbamp;
		VC(\pdswp).env.target.level = -24.dbamp;
		VC(\fmb).env.target.level = -15.85.dbamp;
		VC(\fmbell).env.target.level = -20.dbamp;

		MixingBoard.at(0).mixers.do { |mcg, i|
			if(i < 7) { mcg.mixer = nil };
		};
		VC(\pd) => MCG(0);
		VC(\pdswp) => MCG(1);
		VC(\fmb) => MCG(2);

		VC(\pdswp).env.target.doWhenReady {
			VC(\pdswp).env.widthCtl.watch.automate({
				LFDNoise1.kr(LFNoise1.kr(0.2).exprange(0.1, 3.0)).range(0.1, 0.8)
			}, target: VC(\pdswp).env.target.synthgroup, addAction: \addToHead);
			NotificationCenter.notify(\pdAuto, \ready);
		};

		\chuckIf.eval(PR(\brightChords), BP, \bc);
		VC(\pd) => BP(\bc);
		BP(\bc).quant = 0;

		\chuckIf.eval(PR(\dedrone), BP, \dd);
		VC(\pdswp) => BP(\dd);
		BP(\dd).quant = 1;

		\chuckIf.eval(Fact(\rptChords), BP, \rpt);
		VC(\pd) => BP(\rpt);

		\chuckIf.eval(Fact(\ebassBP), BP, \bass);
		VC(\fmb) => BP(\bass);

		\chuckIf.eval(PR(\bellAccent), BP, \ba);
		VC(\fmbell) => BP(\ba);
	},
	destroy: {
		VC(#[pd, pdswp, fmb, fmbell]).free; BP(#[bc, rpt, dd, bass, ba]).free;
	},

	go: {
		var	cond = Condition.new;
		fork {
			~tlseq.stop;
			~prepare.();
			NotificationCenter.registerOneShot(\pdAuto, \ready, \go, {
				cond.unhang;
			});
			cond.hang;
			TempoClock.default.tempo = 72/60;
			~tlseq = ~makeSeq.();
			~tlseq.play;
			~stopper = NotificationCenter.register(~tlseq, \done, \demo1, e {
				~stop.();
			});
		};
	},

	end: {
		// don't switch the order of these lines, unless you like infinite recursion
		~stopper.remove;
		VC(\pd).env.widthCtl.stopWatching.stopAuto;
		~tlseq.stop;
	},

	makeSeq: {
		TLSequenceIterator([
			Quant(1, -0.25),
			bpCmd: (name: \ba, quant: 1, prepareBP: { |bp|
				bp.degree = Pseq([#[35, 42], 36, 43, Pxrand((35..45), inf) + #[0, 7]], 1);
				bp.dur = Pseq(#[9, 4, 7, 16, 8, 8, 10, 6.5, 1.5], 1);
				bp.leadTime = 0.02;
				bp.addNotes = Pn(true, 3) ++ Pn(false, inf);
				BP(\dd).setNotes(#[], nil);
			}),
			bpCmd: (name: \dd, quant: 1, id: \drone/*, prepareBP: { |bp|
				bp.makeStreamForKey(\dur);
				bp.override(\dur, Pn(0, 1));
			}*/),
			9,
			{
				// BP(\dd).setNotes(#[36, 42, 35], 1);
				4
			},
			{
				// BP(\dd).setNotes(#[43, 36, 42, 35], 1);
				BP(\bc).topGate = 0.25;
				5
			},
			loopCmd: (
				id: \chords,
				bpStream: \bc,
				waitStream: Pseq([0, Pwhite(2, 5, inf)]).asStream,
				cmds: [
					{ ~waitStream.next },
					{
						var next = ~bpStream.next;
						if(next.notNil) {
							PR(\bpCmd).copy
								.put(\name, next)
								.put(\quant, 1)
						}
						// else, returns nil and loopCmd will stop
					},
					\cmdSync
				]//,
				//clearDoneSignal: { "loopcmd stopped".debug }
			),
			24,
			funcCmd: (func: {
				~iterator.findActive(\chords).bpStream = Pseq([\rpt, Prand(#[bc, rpt], inf)]).asStream;
			}),
			15,  // takes us to m.15, bt.2 of slow-melody score
			funcCmd: (
				dur: 5,
				func: {
					BP(#[bc, rpt]).do { |bp| bp.mode = \dlyd };
				},
				clearDoneSignal: {
					BP(#[bc, rpt]).do { |bp| bp.mode = \d };
				}
			),
			13,
			bpCmd: (name: \bass, quant: 1, prepareBP: _.reset),
			// bass note here
			9,
			funcCmd: (func: {
				~iterator.findActive(\chords).putAll((bpStream: nil, repeats: 0));
			}),
			4 + 9,
			funcCmd: (
				func: {
					~iterator.activeCmds.copy.do { |cmd|
						if(cmd.id == \drone) { cmd.stop };
					};
				}
			)
		])
	}
));

