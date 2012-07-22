v = MIDIPort.at(0).sockets[0].destination;

m = SimpleMIDIFile.read("~/Documents/xinghai/sheng-piece/drafts/fast-sketch1.midi");
m = SimpleMIDIFile.read("~/Documents/xinghai/sheng-piece/drafts/long-chords-after-intro2.midi");
m = SimpleMIDIFile.read("~/Documents/xinghai/sheng-piece/drafts/middle-fast-1c.midi");

p = m.p;
p = Pbindf(m.p, \midinote, Pkey(\midinote) - v.globalControls[\transpose]);

a = (Pbind(\type, \voicerNote, \voicer, MIDIPort.at(\omni).sockets[0].destination) <> p).play;


SynthDef(\tri, { |out, freq = 440, det = 1.003, width = 0.5, gate = 1, amp = 0.1, releaseTime = 0.12|
	var sig = VarSaw.ar(freq * [1, det], width).sum * amp,
	eg = EnvGen.kr(Env.asr(0.07, 1, releaseTime), gate, doneAction: 2);
	Out.ar(out, LPF.ar(sig, ExpRand(2000, 5000), eg) ! 2)
}).add;

w = Voicer(25, \tri);
w = Voicer(25, \tri, target: MixingBoard.at(0).mixers[0].mixer);

q = Pchain(Pbind(\type, \voicerNote, \voicer, w, \delta, Pkey(\delta) * Ptempo(), \sustain, (Pkey(\sustain) * 0.9) * Ptempo()), p);

a = q.play(quant: 1);
a.stop;

TempoClock.default.tempo = 88/60

p.list[0].patternpairs

m.noteOnEvents;
576 / 3
192*2 == 384  // 384 ticks/qtr

m.noteEvents
m.noteOffEvents

Proto {
	~canEmbed = true;
	~asStream = { Routine({ |inval| ~embedInStream.(inval) }) };
	~prep = { |dur, pattern, tolerance = 0.001|
		~pattern = pattern;
		~dur = dur;
		~tolerance = tolerance;
		currentEnvironment
	};
	~embedInStream = { |inval|
		var	stream = ~pattern.asStream,
			durToDrop = ~dur.value(inval),
			now = 0, lastRemain = 100000, event;
		while {
			(now absdif: durToDrop) > ~tolerance and: {
				lastRemain.sign == (durToDrop - now).sign and: {
					(event = stream.next(inval.copy)).notNil
				}
			}
		} {
			lastRemain = durToDrop - now;
			now = now + event.delta;
		};
		stream.embedInStream(inval)
	};
} => PR(\dropdur);

a = Pchain(
	(type: \voicerNote, voicer: w),
	// don't need to scale tempo here: q already does it
	PR(\dropdur).copy.prep(160, q)
).play;

a.stop;


a = Pchain(
	(type: \voicerNote, voicer: MIDIPort.at(\omni).sockets[0].destination),
	PR(\dropdur).copy.prep(60 * 60 / 104, p)
).play;

// converting tempo
a = Pchain(
	(type: \voicerNote, voicer: MIDIPort.at(\omni).sockets[0].destination),
	PR(\dropdur).copy.prep(60 * 60 / 104, Pbindf(p, \delta, Pkey(\delta) * 96/104))
).play;

a.stop;


a = Pchain(
	(type: \voicerNote, voicer: MIDIPort.at(\omni).sockets[0].destination),
	Pbindf(p, \delta, Pkey(\delta) * 96/104)
).play;

a.stop;

a = Pbindf(PR(\dropdur).copy.prep(60 /* * 60 / 88 */, q), \dummy, 0).play;

a.stop;

// how to get just 1 of the tracks?
z = m.noteEvents(track: 4);
m.p.inspect
p = m.p.list[3];
p.patternpairs[5].list

a = Pchain(
	(type: \voicerNote, voicer: VC(\pf).v),
	Pbindf(p, \dur, Pkey(\dur) * 104/60)
).play(quant: 1);

a.stop;

Proto {
	~alwaysReset = true;
	~asPattern = {
		Pchain(
			(type: \voicerNote, voicer: VC(\pf).v),
			Pbindf(p, \dur, Pkey(\dur) * 104/60)
		)
	};
} => BP(\temppf);

1 => BP(\temppf);


// how long is it?
q.collect(_.delta).asStream.all(()).sum