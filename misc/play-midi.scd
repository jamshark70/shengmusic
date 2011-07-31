m = SimpleMIDIFile.read("~/Documents/xinghai/sheng-piece/drafts/fast-sketch1.midi");
p = m.p;

a = (Pbind(\type, \voicerNote, \voicer, MIDIPort.at(\omni).sockets[0].destination) <> p).play;


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
			now = 0, event;
		while { (now absdif: durToDrop) > ~tolerance and: {
			(event = stream.next(inval.copy)).notNil
		} } {
			now = now + event.delta;
		};
		stream.embedInStream(inval)
	};
} => PR(\dropdur);

a = Pchain(
	(type: \voicerNote, voicer: MIDIPort.at(\omni).sockets[0].destination),
	PR(\dropdur).copy.prep(60 * 60 / 104, p)
).play;

a = Pchain(
	(type: \voicerNote, voicer: MIDIPort.at(\omni).sockets[0].destination),
	PR(\dropdur).copy.prep(60 * 60 / 104, Pbindf(p, \delta, Pkey(\delta) * 96/104))
).play;

a.stop;

p.list[0].patternpairs

p.asStream.nextN(, inval )

a = Pchain(
	(type: \voicerNote, voicer: MIDIPort.at(\omni).sockets[0].destination),
	Pbindf(p, \delta, Pkey(\delta) * 96/104)
).play;

a.stop;
