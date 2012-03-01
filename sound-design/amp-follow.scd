// real problem: not catching the onset properly

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);
s.addr = ~debugAddr;
s.addr = ~saveAddr;

\supernova.eval;

BP.loadGui;

~master = MixerChannel(\master, s, 2, 2, level: -20.dbamp);
~master => MCG(7);

(
[m, n].free;
m = MixerChannel(\test1, s, 1, 2, outbus: ~master);
n = MixerChannel(\test2, s, 2, 2, outbus: ~master);
m => MCG(0); n => MCG(1);
)


// basic amp-follow test
// What's amp's range?

g = GenericGlobalControl(\amp, nil, 0); g => VP(0);

a = g.watch.automate({
	var mic = SoundIn.ar(0),
	micamp = Amplitude.kr(mic, attackTime: 0.01, releaseTime: 0.01);
	micamp
});

a = g.automate({
	var mic = SoundIn.ar(0),
	micamp = Amplitude.kr(mic, attackTime: 0.002, releaseTime: 0.1),
	descending = HPZ1.kr(micamp) < 0,
	trig = Trig1.kr(descending, 0.25),  // don't print too often!
	peak = A2K.kr(Peak.ar(mic, trig));
	[peak, micamp].collect { |sig, i|
		sig.poll(trig, #["peak", "\tamp"][i]);
	};
	micamp
});

a.trace;

g.stopWatching.stopAuto;

PeakMonitor(Bus(\audio, 8, 1, s));

b = Buffer.alloc(s, 5 * 44100/64, 2);

a = {
	var mic = SoundIn.ar(0),
	micamp = Amplitude.kr(mic, attackTime: 3, releaseTime: 6),
	peak = A2K.kr(Peak.ar(mic, Impulse.ar(64))),
	frames = BufFrames.ir(b),
	phase = Line.kr(0, frames, frames * ControlDur.ir, doneAction:2);
	DC.kr(0).poll(Done.kr(phase), "done");
	BufWr.kr([peak, micamp], b, phase, loop: 0);
	0
}.play;


b.getToFloatArray(wait: -1, action: { |data|
	x = data;
	defer { p = x.plot(numChannels: 2 /*, minval, maxval */) };
});

p.parent.name = "5 attack, 15 release";

g.free;

g.free;
g = [att: 3, rel: 6, amp: 1].clump(2).collect { |pair|
	GenericGlobalControl(pair[0], nil, pair[1], [1, 20])
};
g.do { |gc| gc => VP(0) };

a = m.play({ |att = 3, rel = 6, amp = 1|
	var mic = SoundIn.ar(0),
	micamp = Amplitude.kr(mic, attackTime: 3, releaseTime: 6),
	sig = Formlet.ar(
		Impulse.ar(LFDNoise1.kr(0.5).exprange(45, 200)),
		LFDNoise1.kr(LFNoise1.kr(0.2232312).exprange(0.7, 3.0)).exprange(200, 800),
		0.01, 0.03,
		micamp * amp
	);
	sig
}, [att: g]);

a.trace;

a.free;

(0..1).do { |i| g[i].spec = #[0.01, 3, \exp] };


b.free;
b = Buffer.alloc(s, 5 * 44100, 1);

f = {
	var mic = SoundIn.ar(0),
	frames = BufFrames.ir(b),
	phase = Line.ar(0, frames, BufDur.ir(b), doneAction:2);
	DC.kr(0).poll(Done.kr(phase), "done");
	BufWr.ar(mic, b, phase, loop: 0);
	0
};

c.free;
c = BasicMIDIControl(\omni, 64, { |val|
	var stopper;
	if(val > 0 and: { a.isNil }) {
		a = f.play.debug("playing");
		stopper = OSCFunc({ |msg|
			"synth ended".debug;
			a = nil;
		}, '/n_end', s.addr, nil, [a.nodeID]).oneShot;
	};
});


a.trace;


a = m.play({ |att = 3, rel = 6, amp = 1|
	var mic = PlayBuf.ar(1, b, loop: 1),
	micamp = Amplitude.kr(mic, attackTime: 3, releaseTime: 6),
	// sig = Formlet.ar(
	// 	Impulse.ar(LFDNoise1.kr(0.5).exprange(45, 200)),
	// 	LFDNoise1.kr(LFNoise1.kr(0.2232312).exprange(0.7, 3.0)).exprange(200, 800),
	// 	0.02, 0.04,
	// 	micamp * amp
	// );
	sig = SinOsc.ar(220, 0, micamp * amp);
	sig
}, [att: g]);

a.free;

PeakMonitor(~master);

g.collect(_.value)
[ 0.1080834661669, 0.1080834661669, 5.7874015748031 ]



// related: harmonizer
// ok, maybe I just need to filter out /nopitch
// if it comes too quickly after /pitch (and too quickly before)

// k.free;
// k = Buffer.readAndQuery(s, Qitch.filenameSymbol.asString.dirname.dirname +/+ "extraqitchfiles/QspeckernN1024SR44100.wav");

// ~buf.free;
// ~buf = Buffer.readAndQuery(s, thisProcess.nowExecutingPath.dirname +/+ "flute-notes2.aiff");

(
BP(\fl).free;
Proto({
	~event = (eventKey: \default);
	~alwaysReset = true;
	~prep = {
		~buf = Buffer.readAndQuery(s,
			thisProcess.nowExecutingPath.dirname +/+ "flute-notes2.aiff");
		~chan = m;
		// ~event[\chan] = m;
		~resp = OSCFunc(e { |msg|
			if(~synth.notNil and: { msg[1] == ~synth.nodeID }) {
				~synth = nil;
				BP(~collIndex).stopNow;
			};
		}, '/n_end', s.addr);
		currentEnvironment;
	};
	~freeCleanup = { [~buf, ~resp].free };
	~stopCleanup = {
		if(~synth.notNil) { ~synth.free; ~synth = nil };
	};
	~asPattern = {
		Pseq([
			Pfuncn({
				var ev;
				if(~synth.isNil) {
					~synth = m.play(\bufGrain, [bufnum: ~buf, time: ~buf.duration]);
				};
				Event.silent(0)
			}, 1),
			Pn(Event.silent(4), inf)
		])
	};
}) => BP(\fl);
BP(\fl) => MT(1);
0 => BP(\fl);
)

g = GenericGlobalControl(\hfthresh, nil, 0.98, #[0.01, 1, -4]);
g => VP(0);

(
a.free;
a = m.playfx({ |outbus, lowmidi = 64, himidi = 91, hfThresh = 0.98|
	var mic = SoundIn.ar(0), // In.ar(outbus, 1),
	freq, hasFreq, floatmidi, semitone, onGate, offGate, state;
	#freq, hasFreq = Tartini.kr(mic, threshold: 0.93, n: 1024, k: 0, overlap: 256, smallCutoff: 0.5);
	floatmidi = freq.cpsmidi;
	semitone = floatmidi.round;
	offGate = hasFreq < hfThresh;
	onGate = (1 - offGate) * InRange.kr(semitone, lowmidi, himidi) * Trig1.kr(HPZ1.kr(semitone).abs, 0.075);
	// this is just to suppress extra off gates
	state = SetResetFF.kr(onGate, offGate);
	SendReply.kr(onGate, '/pitch', [freq, semitone, hasFreq, floatmidi - semitone]);
	SendReply.kr(state <= 0, '/nopitch');
	0
}, args: [hfThresh: g]);
)

a.trace;
a.free;


z.free;
z = m.play {
	SinOsc.ar(
		Demand.kr(Impulse.kr(5), 0, Dxrand(#[64, 65, 67, 69, 70, 72, 74, 76, 77], inf)).midicps,
		0,
		0.1
	)
};



ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 5) => Mode(\f);

~p = PbindProxy(
	\instrument, \default,
	\top, Pkey(\midiPitch).mapMode(\f),
	\degree, Pkey(\top) + Pn(Pseries(0, Pwrand(#[-1, -2, -3], #[0.1, 0.55, 0.35], { rrand(3, 5) }), inf).clump(100), inf),
	\freq, Pfunc({ |ev| Mode(ev[\mode]).cps(ev[\degree]) * ev[\offset].midiratio }),
	\dur, 1,
	\sustain, inf
);

p = ~p.asStream;

~p.set(\degree, Pkey(\top) + #[-7, 0, 7]);

~p.set(\degree, Pkey(\top) + Pn(Pseries(0, Pwrand(#[-1, -2, -3], #[0.1, 0.55, 0.35], { rrand(3, 5) }), inf).clump(100), inf));

// e = Event(proto: (mode: \f, freq: { Mode(~mode).cps(~degree) }));
e = ProtoEvent(\polySynthPlayer).copy.proto_((mode: \f, chan: n, immediateOSC: true));

// f = p.next(e.copy.put(\midiPitch, rrand(67, 79))).play;
// f.release;
// f.node.do(_.release);

~saveEvent.play;

// debug posting only
(
o.do(_.free);
o = [
	OSCFunc({ |msg, time|
		msg.debug(time);
	}, '/pitch', s.addr),
	OSCFunc({ |msg, time|
		msg.debug("\t" ++ time);
	}, '/nopitch', s.addr)
];
)


(
o.do(_.free);
~saveEvent = ();
o = [
	OSCFunc({ |msg, time|
		var freq, midi, confidence, offset,
		playFunc = {
			if(~saveEvent.atFail(\node, nil).notNil) {
				~saveEvent[\node].do(_.release);
			};
			~saveEvent = p.next(e.copy.put(\midiPitch, midi).put(\offset, offset));
			Post << "\n" << ~saveEvent << "\n\n";
			~saveEvent.play;
			msg.debug(time);
		};
		#freq, midi, confidence, offset = msg[3..];
		case(
			{ midi.inclusivelyBetween(64, 91).not }, { nil },
			{ Mode(\f).includes(midi) }, playFunc,
			// { (freq.cpsmidi % 1.0) absdif: 0.5 > 0.1 }, playFunc
			{ midi.asInteger.asMIDINote.debug("rejected") }
		);
	}, '/pitch', s.addr),
	OSCFunc({ |msg, time|
		if(~saveEvent.atFail(\node, nil).notNil) {
			~saveEvent[\node].do(_.release);
			~saveEvent[\node] = nil;
		};
		msg.debug("\t" ++ time);
	}, '/nopitch', s.addr);
];
)

(1921..1923).do(s.sendMsg(\n_free, _))

~saveEvent.node.do(_.release);

a.free;



// hasFreq is weird?

b.free;
b = Buffer.alloc(s, (10 * 44100 / 64).roundUp.asInteger, 2);

f = {
	var mic = SoundIn.ar(0),
	frames = BufFrames.kr(b),
	phase = Line.kr(0, frames, frames * ControlDur.ir, doneAction: 2),
	done = Done.kr(phase),
	freq, hasFreq;
	#freq, hasFreq = Tartini.kr(mic, threshold: 0.93, n: 1024, k: 0, overlap: 256, smallCutoff: 0.5);
	// RecordBuf.kr([freq, (hasFreq >= 0.92) * (freq >= 261)], b, loop: 0);
	RecordBuf.kr([freq, hasFreq], b, loop: 0);
	// (frames * ControlDur.ir).poll(Impulse.kr(0));
	// frames.poll(Impulse.kr(0));
	done.poll(done, "done");
	0
};

a = nil;

a = f.play;
a.free;

b.getToFloatArray(wait: -1, action: { |data|
	x = data;
	defer { data.plot(numChannels: 2) };
});

89.cpsmidi
(midinote: 41.3).play;

(2093..2095).do(s.sendMsg(\n_free, _));

x[3000..3999].plot(numChannels: 2);

y = x[3001, 3003 .. 3999];
y.maxItem
y.minItem



// process: drives another proc by triggerOneEvent
(
PR(\abstractProcess).clone {
	~event = (eventKey: \dummy);
	~alwaysReset = true;
	~serverID = \default;
	~quant = 0;

	~lowmidi = 64;
	~himidi = 91;
	~hfThresh = 0.992;
	~mode = \f;

	// defaults to first hardware input
	~micbus = { Server.named[~serverID].options.numOutputBusChannels };

	~prep = {
		if(~serverID == \default) { ~serverID = Server.default.name };
		~makeSynthDef.();
	};
	~freeCleanup = { ~clearResp.() };

	~pitchAction = { |msg, time|
		// need to abstract this
		// case
		// { midi.inclusivelyBetween(64, 91).not } { nil },
		// { Mode(\f).includes(midi) } {
		// 	~pitchAction.(freq, midi, confidence, offset, time)
		// },
		// // { (freq.cpsmidi % 1.0) absdif: 0.5 > 0.1 }, playFunc
		// { midi.asInteger.asMIDINote.debug("rejected") };
		[time, msg].debug("pitchAction");
	};
	~noPitchAction = { |msg, time|
		[time, msg].debug("\tnoPitchAction");
	};

	~stopCleanup = {
		if(~synth.notNil) {
			~synth.free;
			~synth = nil;
		};
		~clearResp.();
	};
	~preparePlay = { ~makeSynth.() };

	~makeSynth = {
		if(~synth.isNil) {
			~synth = Synth(~defName, [
				inbus: ~micbus.(), lowmidi: ~lowmidi, himidi: ~himidi, hfThresh: ~hfThresh
			], Server.named[~serverID]);
			~makeResp.();
		};
	};

	~makeSynthDef = {
		~defName = \pitchTrack; // ("track" ++ ~collIndex).asSymbol;
		SynthDef(~defName, { |inbus, lowmidi = 64, himidi = 91, hfThresh = 0.98|
			var mic = In.ar(inbus, 1),
			freq, hasFreq, floatmidi, semitone, onGate, offGate, state;
			var trigs;
			#freq, hasFreq = Tartini.kr(mic, threshold: 0.93, n: 1024, k: 0, overlap: 256, smallCutoff: 0.5);
			floatmidi = freq.cpsmidi;
			semitone = floatmidi.round;
			offGate = hasFreq < hfThresh;
			// debug form here, revert later (no less efficient in server)
			trigs = [(1 - offGate), InRange.kr(semitone, lowmidi, himidi), Trig1.kr(HPZ1.kr(semitone).abs, 0.075)];
			onGate = trigs.reduce('*');
			// trigs.do { |t, i| t.poll(HPZ1.kr(t).abs, "trig %".format(i)) };
			// this is just to suppress extra off gates
			state = SetResetFF.kr(onGate, offGate);
			SendReply.kr(onGate, '/pitch', [freq, semitone, hasFreq, floatmidi - semitone]);
			SendReply.kr(state <= 0, '/nopitch');
		}).add;
	};

	~makeResp = {
		if(~synth.isNil) {
			"BP(%): Can't make responders without synth".format(~collIndex.asCompileString).warn;
		} {
			if(~resps.notNil) { ~clearResp.() };
			~resps = [
				// OSCFunc(e { |msg, time|
				// 	~pitchAction.(msg, time)
				// }, '/pitch', s.addr, argTemplate: [~synth.nodeID]),
				// OSCFunc(e { |msg, time|
				// 	~noPitchAction.(msg, time);
				// }, '/nopitch', s.addr, argTemplate: [~synth.nodeID]);
				OSCFunc(e(~pitchAction), '/pitch', s.addr, argTemplate: [~synth.nodeID]),
				OSCFunc(e(~noPitchAction), '/nopitch', s.addr, argTemplate: [~synth.nodeID]);
			];
		};
	};

	~clearResp = {
		~resps.free;
		~resps = nil;
	};

	~asPattern = {
		// just to keep the green light lit
		Pbind(\dur, 4);
	};
} => PR(\pitchtrack);
)

BP(\pt).free;
PR(\pitchtrack) => BP(\pt);

BP(\pt).hfThresh = 0.992;
