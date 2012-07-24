
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
