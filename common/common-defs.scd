var saveSubtype = AbstractChuckArray.defaultSubType;

protect {

	#[c, db, d, eb, e, f, gb, g, ab, a, bb, b].do { |key, i|
		Mode(\default).v.copy.root_(i) => Mode(key);
		Mode(key).v.transposeRoot(0) => Mode((key ++ "0").asSymbol);
	};

	(
		keys: #[master],
		instr: "osc2.fm1porta",
		car_env: nil,
		mod_env: Env.adsr(0.01, 0.14, 1/3, 3, 3),
		make: { |name|
			var args, out;
			~target = MixerChannel(name, s, 1, 2, /*level: ,*/ outbus: ~master, completionFunc: { |chan|
				~chorus = chan.playfx(Instr("busfx.chorus2band2"), [0, 1, 3, 0.019929544097472, 0.10529309760794, 0.010555364844924, 0.84697339184144, 189.85848040307, 0.5]);
			});
			~cb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
				buf.sine1Msg(#[1]);
			});
			~mb = Buffer.alloc(s, 2048, 1, completionMessage: { |buf|
				buf.sine1Msg(#[1, 0.5, 0.25]);
			});
			args = [
				car_buf: `~cb, mod_buf: `~mb, /*mod_lev: 0.302,*/ mod_ratio: 0.5,
				mod_env: ~mod_env,
				car_vs: 0.4, mod_vs: 0.7
			];
			if(~car_env.notNil) { args = args ++ [car_env: ~car_env] };
			out = MonoPortaVoicer(1, WrapInstr(~instr), args, target: ~target);
			out.mapGlobal(\mod_lev, nil, 1.8, #[0.01, 8, \exponential]);
			out.portaTime = 0.3;
			out
		},
		free: { [~target, ~cb, ~mb].free },
		type: \voicer) => Fact(\fmbass);


	{ |instr, inputs|
		var	argAssn = instr.asInstr.getWrappedArgs, names, specs,
		newInputs = Array.newClear(argAssn.size),
		index = 0, indexSearch, failed = false;

		names = argAssn.collect({ |assn| assn.key.asSymbol });
		specs = argAssn.collect(_.value);

		inputs.do { |input|
			if((indexSearch = names.indexOf(input)).notNil) {
				index = indexSearch;
			} {
				case
				{ newInputs[index].notNil } {
					"Arg collision: '%' already received %\n"
					.format(names[index], newInputs[index])
					.warn;
					failed = true;
					index = index + 1;
				}
				{ index >= newInputs.size } {
					Error("Inputs went past argument list bounds").throw;
				}
				{
					newInputs[index] = input;
					index = index + 1;
				}
			};
		};
		if(failed) { Error("Argument list conversion failed.").throw } {
			newInputs
		};
	} => Func(\patchArgs);


	Proto {
		~prep = {
			var oscSpectrum = Array.fill((20000 / 48.midicps).asInteger, { |i| (i+1).reciprocal }),
			indexStream = Pshuf((0 .. oscSpectrum.size - 1)).asStream;
			(oscSpectrum.size div: 10).do {
				oscSpectrum.swap(indexStream.next, indexStream.next);
			};
			~todo = IdentitySet.with(\noiseBufs, \oscBufs);
			~ready = false;
			fork {
				var c = Condition.new;
				~noiseBufs = Buffer.allocConsecutive(5, s, 2048, 1);
				s.sync;
				~noiseBufs.do { |buf|
					fork {
						buf.sendCollection(
							Signal.fill(1024, { 1.0.rand2 }).asWavetable,
							action: { c.unhang }
						);
					};
					c.hang;
				};
				~doneWith.(\noiseBufs);
				~oscBufs = Buffer.allocConsecutive(8, s, 2048, 1);
				s.sync;
				~oscBufs.do { |buf, i|
					fork {
						buf.sendCollection(
							Signal.sineFill(
								1024,
								oscSpectrum.keep((20000 / (48.midicps * (2**i))).asInteger)
							).asWavetable,
							action: { c.unhang }
						);
					};
					c.hang;
				};
				~doneWith.(\oscBufs);
			};
			currentEnvironment
		};
		~freeCleanup = {
			~noiseBufs.free;
		};
		~doneWith = { |key|
			"%: done\n".postf(key);
			~todo.remove(key);
			if(~todo.isEmpty) {
				~ready = true;
				"BP(%) is ready\n".postf(~collIndex.asCompileString);
				NotificationCenter.notify(currentEnvironment, \sharedReady);
			};
			currentEnvironment
		};
		~updateWhenReady = { |bpkey|
			if(BP.exists(bpkey)) {
				if(~ready) {
					BP(bpkey).sharedReady = true;
				} {
					NotificationCenter.registerOneShot(currentEnvironment, \sharedReady, bpkey, {
						BP(bpkey).sharedReady = true;
					});
				};
			} {
				"BP(%).updateWhenReady: BP(%) does not exist."
				.format(~collIndex.asCompileString, bpkey.asCompileString)
				.warn;
			};
			currentEnvironment
		};
	} => PR(\shengShared);



	// various pattern helpers

	(
		play: {
			~action.value;
			if(~cond.notNil) { ~cond.hang }
			{ "No ~cond, ProtoEvent(\\hang) can't hang".warn }
		}, delta: 0
	) => ProtoEvent(\hang);

	Proto({
		~canEmbed = true;

		~prep = { |pattern, func|
			~pattern = pattern;
			~func = func;
			currentEnvironment
		};

		~embedInStream = { |inval|
			var stream = ~pattern.asStream, item;
			while { (item = stream.next(inval)).notNil } {
				inval = ~func.value(item).embedInStream(inval);
			};
			inval
		};

		~asStream = {
			Routine({ |inval| ~embedInStream.(inval) })
		};

		~asPattern = { currentEnvironment };

		~next = { currentEnvironment };
	}) => PR(\collectEmbed);


	Proto {
		~prep = { |args|
			// ~number = UniqueID.next;
			if(args.respondsTo(\keysValuesDo)) {
				currentEnvironment.putAll(args);
			};
			~locks = IdentitySet.new;
			// this way, makeStuff can have whatever args it needs
			// and it will pull them from the environment (after being put there by putAll)
			currentEnvironment.env.use { ~makeStuff.valueEnvir };
			currentEnvironment
		};

		~numCh = 1;
		~rate = \audio;
		~server = { Server.default };

		// user overrides
		~makeStuff = { |numCh, rate, server|
			~server = server.value;
			if((~bus = Bus.perform(rate, ~server, numCh)).isNil) {
				Error("couldn't get % bus".format(rate)).throw;
			};
			// ~bus.debug("made" + ~number);
		};

		~freeStuff = {
			var killMsgs;
			// ~bus.debug("freed" + ~number).free;
			~killNodes.do { |thing|
				if(thing.isKindOf(Node)) {
					killMsgs = killMsgs.add(thing.freeMsg)
				} {
					thing.free
				};
			};
			if(killMsgs.size > 0) {
				~server.listSendBundle(nil, [#[error, -1]] ++ killMsgs ++ [#[error, -2]])
			};
			currentEnvironment
		};

		~addNode = { |node|
			var	endFunc = e { |obj, what|
				if(what == \n_end) {
					node.removeDependant(endFunc);
					~removeLock.(node/*.debug("node ended" + ~number)*/);
				};
			};
			~locks.add(node/*.debug("added node" + ~number)*/);
			NodeWatcher.register(node);
			node.addDependant(endFunc);
		};

		~removeLock = { |obj|
			~locks.remove(obj);
			if(~locks.isEmpty) {
				~freeStuff.();
			};
		};
	} => PR(\busLock);

	PR(\busLock).clone {
		~busFreeDelay = 1;
		~freeStuff = {
			~stopThings.do(_.stop);
			~killNodes.do(_.free);
			AppClock.sched(~busFreeDelay, e { ~bus.free });
		};
	} => PR(\busFxPatLock);

	(parent: ProtoEvent(\polySynthPlayer).v.parent.copy.putAll((
		lockKey: \busLock,
		superPlay: ProtoEvent(\polySynthPlayer).v[\play],
		play: {
			var	chan = ~chan;
			~numCh ?? { ~numCh = ~chan.inChannels };
			~lock ?? { ~lock = PR(~lockKey).copy.prep((
				numCh: ~numCh, server: ~chan.tryPerform(\server) ?? { Server.default }, rate: ~busRate ? \audio
			)) };
			~bus = ~lock.bus;
			~target = ~chan.synthgroup;
			~chan = nil;
			~superPlay.();

			if(~node.notNil and: { (~node.tryPerform(\isEmpty) ? false).not }) {
				~playExtraProcess.(chan);
				~node.do { |node| ~lock.addNode(node) };
			} {
				if(~autoFreeIfNoNode != false) { ~lock.freeStuff };
			};
			if(~tempo.isNumber) { thisThread.clock.tempo = ~tempo }
		},
		playExtraProcess: { |chan|
			if(~lpcEv.size > 0) {
				~lpcEv.putAll((
					bus: chan.inbus,
					target: chan.effectgroup,
					// chan: nil,
					inbus: ~lock.bus,
					collIndex: ~collIndex,
					// effectgroup might have post-lpc effect nodes (chorus etc.)
					// so put lpc's up front
					addAction: ~lpcEv[\addAction] ?? { \addToHead }
				))
				.put(\chan, nil)  // can't set to nil in putAll
				// cuz parent: don't work in putAll #@$*$&*$&@#312
				.parent_(ProtoEvent(~lpcProto ?? { \polySynthPlayer }).v.parent)
				.play;
				if(~lpcEv[\killNode] == true) {
					~lpcEv[\node].do { |node|
						if((~lock.killNodes.tryPerform(\includes, node) ? false).not) {
							~lock.killNodes = ~lock.killNodes.add(node)
						};
					};
				} {
					~lpcEv[\node].do { |node| ~lock.addNode(node) };
				}
			} {
				~sendNode = Synth("mixers/Send" ++ ~numCh,
					[busin: ~lock.bus, busout: chan.inbus, level: 1],
					chan.effectgroup
				);
				~lock.killNodes = ~sendNode;
			};
		} //,
		// 	notifyDependents: {
		// 		~node.do { |node| ~lock.addNode(node) };
		// 	}
	))) => ProtoEvent(\polySynthBusLock);

	(parent: ProtoEvent(\polySynthBusLock).v.parent.copy.putAll((
		play: {
			var	chan = ~chan;
			~numCh ?? { ~numCh = ~chan.inChannels };
			~lock ?? { ~lock = PR(~lockKey).copy.prep((
				numCh: ~numCh, server: ~chan.tryPerform(\server) ?? { Server.default }, rate: ~busRate ? \control
			)) };
			// ~bus = ~lock.bus;
			// ~target = ~chan.synthgroup;
			// ~chan = nil;
			~superPlay.();

			if(~node.notNil and: { (~node.tryPerform(\isEmpty) ? false).not }) {
				~playExtraProcess.(chan);
				~node.do { |node| ~lock.addNode(node) };
			} {
				~lock.freeStuff;
			};
			if(~tempo.isNumber) { thisThread.clock.tempo = ~tempo }
		},
		playExtraProcess: { |chan|
			if(~lpcEv.size > 0) {
				~lpcEv.putAll((
					bus: ~lock.bus,
					target: if(chan.notNil) { chan.synthgroup } { ~target },
					// inbus: ~lock.bus,
					collIndex: ~collIndex,
					// effectgroup might have post-lpc effect nodes (chorus etc.)
					// so put lpc's up front
					addAction: ~lpcEv[\addAction] ?? { \addToHead }
				))
				.put(\chan, nil)  // can't set to nil in putAll
				// cuz parent: don't work in putAll #@$*$&*$&@#312
				.parent_(ProtoEvent(~lpcProto ?? { \polySynthPlayer }).v.parent)
				.play;
				// ~lpcEv[\node].do { |node| ~lock.addNode(node) };
				~lock.killNodes = ~lpcEv[\node];
			};
		}
	))) => ProtoEvent(\polySynthKrBusLock);

	(parent: ProtoEvent(\polySynthBusLock).v.parent.copy.putAll((
		lockKey: \busFxPatLock,
		playExtraProcess: { |chan|
			~lock.busFreeDelay = ~busFreeDelay ? 1;
			if(~fxPatEv.size > 0 and: { ~fxPatEv[\pat].notNil }) {
				~fxPatEv[\streamPlayer] = ~fxPatEv[\pat].play(
					thisThread.clock,
					Event(
						proto: (
							bus: chan.inbus,
							target: chan.effectgroup,
							chan: nil,
							inbus: ~lock.bus,
							lock: ~lock,
							collIndex: ~collIndex,
							// effectgroup might have post-lpc effect nodes (chorus etc.)
							// so put lpc's up front
							addAction: ~fxPatEv[\addAction] ?? { \addToHead }
						),
						parent: ProtoEvent(~fxProto ?? { \polySynthPlayer }).v.parent.copy
					),
					~fxPatEv[\quant]
				);
				~lock.stopThings = [~fxPatEv[\streamPlayer]];
			} {
				~sendNode = Synth("mixers/Send" ++ ~numCh,
					[busin: ~lock.bus, busout: chan.inbus, level: 1],
					chan.effectgroup
				);
				~lock.killNodes = ~sendNode;
			};
		}
	))) => ProtoEvent(\polySynthFxPatLock);


	// and, hey, why not, one more variation...
	// \freq may be a midinote (~midi == true)
	// or modal degree (~midi == false and ~mode is populated)
	(parent: ProtoEvent(\polySynthKrBusLock).v.parent.copy.putAll((
		midiNoteToFreq: ProtoEvent(\synthNote).v[\midiNoteToFreq],
		superSetArgs: ProtoEvent(\polySynthKrBusLock).v[\setArgs],
		setArgs: {

			~freq = ~freq ?? { ~note.asFloat };
			~mtranspose.notNil.if({ ~freq = ~oldFreq + ~mtranspose });
			(~midi ? false).not.if({ ~freq = ~freq.unmapMode(~mode.asMode) });
			~ctranspose.notNil.if({ ~freq = ~freq + ~ctranspose });

			~freq = ~midiNoteToFreq.value(~freq).asArray;
			~dur = ~dur ?? { ~delta ?? { ~note.dur } };
			~sustain = (~sustain ?? { ~note.length }).asArray;
			~gate = ~gate ?? { ~note.gate ?? { 1 } };

			~superSetArgs.value;
		},
		keysToPropagate: #[\instrument, \target, \bus, \midi, \mode, \timingOffset]
	))) => ProtoEvent(\synthNoteKrBusLock);


	(
		parent: ProtoEvent(\voicerNote).parent,
		superPlay: ProtoEvent(\voicerNote).parent[\play],
		playExtraProcess: ProtoEvent(\polySynthKrBusLock).v[\playExtraProcess],
		lockKey: \busLock,
		play: {
			var	chan = ~chan;
			~numCh ?? { ~numCh = ~chan.inChannels };
			~lock ?? { ~lock = PR(~lockKey).copy.prep((
				numCh: ~numCh, server: ~chan.tryPerform(\server) ?? { Server.default }, rate: ~busRate ? \control
			)) };
			~superPlay.();
			if(~nodes.notNil and: { (~nodes.tryPerform(\isEmpty) ? false).not }) {
				~playExtraProcess.(chan);
				~nodes.do { |node| ~lock.addNode(node.synth) };
			} {
				~lock.freeStuff;
			};
			if(~tempo.isNumber) { thisThread.clock.tempo = ~tempo }
		}
	) => ProtoEvent(\voicerNoteKrBusLock);

	PR(\arpeg1).clone {
		~resetArgsOnChord = false;
		~initVoicerArgs = {
			~voicerArgs = Proto.new.putAction_(e { |key, value, me|
				~voicerArgStreams ?? { ~voicerArgStreams = IdentityDictionary.new };
				~voicerArgStreams.put(key, value.asStream);
			});
			currentEnvironment
		};
		~voicerArgs_ = { |envir|
			~voicerArgs.env.keys.do { |key| ~voicerArgs.removeAt(key) };
			~voicerArgStreams = IdentityDictionary.new;
			envir.keysValuesDo { |key, value|
				~voicerArgs[key] = value;
				~voicerArgStreams[key] = value.asStream;
			};
			currentEnvironment
		};
		~resetArgStreams = {
			~voicerArgStreams.do(_.reset);
		};
		~superAsPattern = ~asPattern;
		~asPattern = { |inEvent|
			if(~resetArgsOnChord ? false) { ~resetArgStreams.() };
			~superAsPattern.(inEvent).collect { |ev|
				var extraArgs;
				if(ev[\vckey].notNil and: { VC.exists(ev[\vckey]) }) {
					ev[\voicer] = VC(ev[\vckey]).v;
					if(~voicerArgStreams[ev[\vckey]].notNil) {
						ev = ~voicerArgStreams[ev[\vckey]].next(ev);
					} {
						ev = VC(ev[\vckey]).argStreams.next(ev);
					};
				};
				ev
			};
		};
	} => PR(\arpegMultiVoicer);


	ProtoEvent(\voicerNote).copy.make {
		~play = {
			var	lag = ~lag ? 0,  // ~timingOffset !? { ~timingOffset / ~clock.tempo };
			timingOffset = ~timingOffset ? 0,
			clock = ~clock,
			voicer = ~voicer,
			bundle, releaseGate,
			iMadeNodes = ~nodes.isNil or: {
				~nodes.asArray.any { |obj| obj.isKindOf(SynthVoicerNode).not }
			};
			// ~prepNote expects ~nodes to be nil
			// if you want it to obtain nodes from the voicer
			if(iMadeNodes) { ~nodes = nil };
			~prepNote.value;
			~finish.value;	// user-definable
			(~debug == true).if({
				"\n".debug;
				["voicerNote event", ~clock.beats, ~clock.tempo].debug;
				currentEnvironment.collect({ |value| value.isFunction.not.if(value, nil) }).postcs;
			});
			releaseGate = (~releaseGate ? 0).asArray;
			if(iMadeNodes) {
				~nodes.do({ |node, i|
					var	freq = ~newFreq.wrapAt(i), length = ~length.wrapAt(i);
					Func(\schedEventBundleArray).doAction(lag, ~timingOffset, node.server,
						node.server.makeBundle(false, {
							node.trigger(freq, ~gate.wrapAt(i), ~args.wrapAt(i), node.server.latency);
					}));
					(length.notNil and: { length != inf }).if({
						// can't use schedEventBundle
						// because you must not release the VoicerNode
						// until the proper time comes
						thisThread.clock.sched(length + timingOffset, {
							voicer.releaseNode(node, freq, releaseGate.wrapAt(i),
								lag + (node.server.latency ? 0));
						});
					});
				});
			} {
				~nodes.do({ |node, i|
					var	freq = ~newFreq.wrapAt(i), length = ~length.wrapAt(i);
					Func(\schedEventBundleArray).doAction(lag, ~timingOffset, node.server,
						node.server.makeBundle(false, {
							node.set([\freq, freq] ++ ~args.wrapAt(i), node.server.latency);
							node.frequency = freq;
						})
					);
				});
			};
		};
		~releaseNote = {
			var latency;
			((~immediateOSC ? false) or: { ~voicer.target.server.latency.isNil }).if({
				~nodes.do(_.release);
				}, {
					latency = (((~lag ? 0) + (~timingOffset ? 0)) / (~clock ?? { thisThread.clock }).tempo)
					+ ~voicer.target.server.latency;
					~nodes.do(_.release(nil, latency));
			});
		};
	} => ProtoEvent(\voicerNoteSlurs);

	PR(\arpeg1).clone {
		~event = ~event.copy.put(\eventKey, \voicerNoteSlurs);
		~asPatternHook = { |out|
			if(~notifier.isNil) {
				~notifier = NotificationCenter.register(
					currentEnvironment, \childStop, \theChildItself, e {
						~lastEvent.use { ~releaseNote.value };
						// note, this assumes that child streams will not overlap
						// this is the normal case in macroRh
						~lastEvent = nil;
						~notifier.remove;
						~notifier = nil;
					}
				)
			};
			out.collect { |ev|
				if(~lastEvent.notNil and: {
					~lastEvent[\nodes].notNil and: {
						~lastEvent[\nodes].every { |n| n.isPlaying and: { n.isReleasing.not } }
					}
				}) {
					ev[\nodes] = ~lastEvent[\nodes];
				};
				~lastEvent = ev;
				ev
			};
		};
		~stopCleanup = {
			~notifier.remove;
			~notifier = nil;
			if(~lastEvent.notNil) {
				~lastEvent.use { ~releaseNote.value };
			};
		};
	} => PR(\arpeg1Slurs);


	Proto({
		~alwaysReset = true;
		~event = (eventKey: \dummy);
		~quant = 0;
		~initLevel = 0.75;
		~prep = {
			~chan = MixerChannel(~collIndex, s, 1, 2, ~initLevel, outbus: ~master, completionFunc: { |chan|
				chan.newPostSend(~rvbmc, 0.6);
			});
			~def = ~makeSynthDef.();
			currentEnvironment
		};
		~freeCleanup = { ~chan.free };
		~makeSynthDef = {
			SynthDef(\micIn, { |inbus, outbus, amp = 1, gate = 1|
				Out.ar(outbus, In.ar(inbus, 1) * Linen.kr(gate, 0.05, 1, 0.05, doneAction: 2))
			}).add;
		};
		~synthArgs = { [inbus: s.options.numOutputBusChannels, amp: 1] };
		~stopCleanup = {
			if(~node.notNil) {
				~node.release;
				~node = nil;
			};
		};
		~asPattern = {
			Pseq([
				Pfuncn({ |ev|
					if(~node.isNil) {
						~node = ~chan.play(~def.name, ~synthArgs.());
					};
					ev.put(\delta, 1)
				}, 1),
				Pn((delta: 8), inf)
			])
		};
	}) => PR(\micIn);

	(
		make: { |name|
			if(BP.exists(\mic)) {
				BP(\rec).free;
				PR(\transient_analysis_incr).chuck(BP(\rec), nil, (
					userprep: {
						// pipe mic input to me
						// this also establishes the right order of execution
						~micSend = BP(\mic).chan.newPostSend(~chan, 1);
						// this should be OK: userprep is called before startRecord
						~inputBusIndex = ~chan.inbus.index;
						~chan.level = 0;  // mute my channel, but processing continues internally
					},
					userFree: { ~micSend.free },
					numBufs: 5,
					bufDur: 30,
					recordActive: true,
					audioThru: false,
					inputParms: [hardgate: -56.dbamp],
					minPeak: -35.dbamp,
					makeFeatureDetector: {
						// onsets with \wphase: better for pitched material that doesn't articulate strongly
						SynthDef(\pv_onsets, { |outbus, fftbuf, bufnum, t_trig, faststop = 0,
							threshold = 0.267, waittime = 0.15116279069767,
							i_fftwait = 0.05|  // can't do fft analysis until the whole frame is recorded

							var	pc = PulseCount.kr(t_trig),
							start = BinaryOpUGen.new1(\control, '==', pc, 1),
							stop = BinaryOpUGen.new1(\control, '==', pc, 2),
							started = (pc > 0),
							sig = In.ar(outbus, 1),
							fft = FFT(fftbuf, sig),
							dur = Phasor.ar(start, SampleDur.ir, 0, 1000),
							onsettrig;

							// event onset
							onsettrig = Onsets.kr(fft, threshold, \wphase);
							// delayed to allow entire client fft frame to be recorded before analysis
							// BufDur.kr(fftbuf) * 0.5 is a correction for PV_Jensen's trigger lag
							SendTrig.kr(DelayN.kr(onsettrig, i_fftwait, i_fftwait), 32,
								dur - i_fftwait - (BufDur.kr(fftbuf) * 0.5));

							stop = stop + (started * A2K.kr(dur > BufDur.ir(bufnum))) + faststop;
							FreeSelf.kr(stop);
						});
					},
					buffers: { ~bufs.select { |buf| buf.status == \ready }.collect(_.buf) },
					times: { ~bufs.select { |buf| buf.status == \ready }.collect(_.ontimes) }
				));
			} {
				"BP(\\mic) doesn't exist".warn;
				nil
			};
		},
		type: \bp
	) => Fact(\recBP);

} { AbstractChuckArray.defaultSubType = saveSubtype; }