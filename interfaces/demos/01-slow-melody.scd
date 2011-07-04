// demo code for 02-slow-opening-fixed.ly

WrapInstr(\highdrone, { |freq, detuneRatio = 1.003, width = 0.2,
	bpDownRatio = 0.2, rq = 0.08, mix = 0.56, lpsrcfreq = 4000, lpfxfreq = 8000,
	chorusFreq = 0.1, chorusDelay = 0.018, chorusWidth = 0.01,
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
		ffreqs = LFDNoise1.kr(LFNoise1.kr(0.1 ! 7).range(0.25, 4).reciprocal)
			.exprange(lpfxfreq * bpDownRatio, lpfxfreq),
		filts,
		initTrig = Impulse.kr(0),
		eg_fb = Select.kr(initTrig, [LocalIn.kr(1), 0]),
		// switch timescale when env starts going down
		goingDown = (PulseCount.kr(HPZ1.kr(eg_fb) < 0) >= 1
			+ (gate <= 0)) > 0,
		scale = Select.kr(goingDown, [envScaleUp, envScaleDown]),
		eg = EnvGen.kr(env, gate, timeScale: scale, doneAction: 2);
	LocalOut.kr(eg);
	// scale.poll(HPZ1.kr(scale).abs > 0);
	sig = sig + DelayL.ar(sig, 0.1, SinOsc.kr(chorusFreq, 0, chorusWidth, chorusDelay));
	filts = BPF.ar(sig, ffreqs, rq);
	filts = Splay.ar(filts, spread: 1, level: 1, center: 0, levelComp: false);
	sig = XFade2.ar(LPF.ar(sig, lpsrcfreq), LPF.ar(filts, lpfxfreq), mix);
	sig * eg;
}, [\freq, \mydetune, \unipolar, #[0.1, 1.0, \exp], \myrq, \bipolar, \freq, \freq,
	#[0.05, 0.5, \exp], #[0.003, 0.05, \exp], #[0.001, 0.04, \exp],
	\amp, \unipolar, EnvSpec(Env.adsr), #[0.1, 10, \exp], #[0.1, 10, \exp],
	\mybuf, #[1, 16, \lin, 1], \freq, \freq
]);

(
make: { |name|
	var	out;
	~target = MixerChannel(name, s, 2, 2, level: -20.dbamp);
	// // supernova: KABOOM
	// ~bufs = \makeWavetables.eval(8, s, 1024, 48, { |numharm|
	// 	Array.sawtoothAmps(numharm)
	// });
	~bufs = Buffer.allocConsecutive(8, s, 1024, 1);
	\modWavetables.eval(~bufs, 48, { |numharm|
		Array.sawtoothAmps(numharm)
	});

	out = Voicer(20, WrapInstr(\highdrone), [
		env: Env.adsr(0.9, 1.2, 0.8, 1.8), chorusFreq: `0.1, chorusDelay: `0.018,
		chorusWidth: `0.01, vsens: 0.8, lpsrcfreq: 2800, lpfxfreq: 7000,
		bufbase: `(~bufs[0].bufnum), numbufs: `(~bufs.size),
		basefreq: `(48.midicps), topfreq: 16744,
		mix: 0.3
	], target: ~target);
	out.mapGlobal(\rq, nil, 0.08, \myrq);
	~widthCtl = GenericGlobalControl(\width, nil, 0.2, #[0.02, 0.98]);
	out
}, free: { [~target, ~widthCtl, ~bufs].free }, type: \voicer) => Fact(\pulseDrone);

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

\chuckIf.eval(ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 2), Mode, \d);

PR(\demoProto).copy.putAll((
	name: "1. Slow melody",

	prepare: {
		\chuckIf.eval(Fact(\pulseDrone), VC, \pd);

		MixingBoard.at(0).mixers.do { |mcg| mcg.mixer = nil };
		VC(\pd) => MCG(0);

		VC(\pd).env.target.doWhenReady {
			VC(\pd).env.widthCtl.watch.automate({
				LFDNoise1.kr(LFNoise1.kr(0.2).exprange(0.1, 3.0)).range(0.1, 0.8)
			}, target: VC(\pd).env.target.synthgroup, addAction: \addToHead);
			NotificationCenter.notify(\pdAuto, \ready);
		};

		\chuckIf.eval(PR(\brightChords), BP, \bc);
		VC(\pd) => BP(\bc);
		BP(\bc).quant = 0;

		\chuckIf.eval(Fact(\rptChords), BP, \rpt);
		VC(\pd) => BP(\rpt);
	},
	destroy: {
		VC(\pd).free; BP(#[bc, rpt]).free;
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
			Quant(1),
			funcCmd: (
				id: \drone,
				setDoneSignal: { ~doneSignal = true },
				func: {
					VC(\pd).v.setArgDefaults([\vsens, 0.95]);
					VC(\pd).v.trigger([62, 74].midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
				},
				clearDoneSignal: {
					VC(\pd).v.release([62, 74].midicps);
				}
			),
			9,
			funcCmd: (
				id: \drone,
				setDoneSignal: { ~doneSignal = true },
				func: {
					VC(\pd).v.trigger(64.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
				},
				clearDoneSignal: {
					VC(\pd).v.release(64.midicps);
				}
			),
			4,
			funcCmd: (
				id: \drone,
				setDoneSignal: { ~doneSignal = true },
				func: {
					VC(\pd).v.trigger(76.midicps, 0.02, [envScaleUp: 2.4, envScaleDown: 2.4, width: VC(\pd).env.widthCtl.asMap]);
				},
				clearDoneSignal: {
					VC(\pd).v.release(76.midicps);
				}
			),
			{ BP(\bc).topGate = 0.25; 5 },
			loopCmd: (
				id: \chords,
				bpStream: \bc,
				waitStream: Pseq([0, Pwhite(2, 5, inf)]).asStream,
				cmds: [
					{ ~waitStream.next },
					{
						var next = ~bpStream.next;
						if(next.notNil) { PR(\bpCmd).copy.put(\name, next) }
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
			30,
			funcCmd: (func: {
				~iterator.findActive(\chords).putAll((bpStream: nil, repeats: 0));
			}),
			funcCmd: (
				doneSignal: true,
				func: {
					NotificationCenter.registerOneShot(
						~iterator.findActive(\chords), \done, currentEnvironment, e {
							~stop.();
						}
					)
				},
				clearDoneSignal: {
					~iterator.activeCmds.copy.do { |cmd|
						if(cmd.id == \drone) { cmd.stop };
					};
				}
			)	
		])
	}
));

