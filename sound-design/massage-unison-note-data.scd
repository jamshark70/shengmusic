m = SimpleMIDIFile.read(thisProcess.nowExecutingPath.dirname.dirname +/+ "support/fast-unison-notes.midi");

m.inspect;

m.noteEvents(0);

// 16th-note is dur==0.15 in the midi file -- scale up to 0.25
p = Pset(\sustain, Pkey(\dur), Pstretch(5/3, m.p.drop(1)));

p = Pbindf(m.p.drop(1), \dur, Pkey(\dur) * (5/3), \delta, Pkey(\dur), \sustain, Pkey(\sustain) * (5/3));

p.inspect;

q = p.asStream;
q.next(());

/*
a = Ppar([Pbind(\dur, 0.25)]);
b = Pstretch(2, a);

a.asStream.next(());
b.asStream.next(());
*/


while { (e = q.next(())).delta > 0 };

e;
q.next(());

m.p.asStream.next(())

0.14173228346457.asRational

(
a = List.new;
p.asStream.do({ |ev|
	if(ev[\midinote].isNumber) {
		a = a.add(SequenceNote(ev[\midinote], ev[\dur], ev[\sustain], 0.5));
	} {
		a.last.dur = a.last.dur + ev[\dur];
	};
}, ());
a.do(_.postln); ""
)

b = MIDIRecBuf(\unison, a, (mode: \d));
c = b.parse(0.05, 0.05);

c.dumpSeq;

d = Pbind(\voicer, VC(\tri).v, \note, Pseq(c.notes, 1), \midi, true).play(protoEvent: ProtoEvent(\voicerNote).copy);

d.stop;

c.writeArchive(thisProcess.nowExecutingPath.dirname.dirname +/+ "support/unison-parsed.txarch");

(
d = MIDIRecBuf(\unison, c.notes.collect { |note|
	var temp;
	if(note.isMemberOf(SequenceNote)) {
		// temp = note.copy;
		// temp.dur_(0) ++ (note.freq - #[12, 24]).collect { |pitch, i| SequenceNote(pitch, if(i == 1) { note.dur } { 0 }, note.length, 0.5) }
		temp = ((note.freq - #[24, 12]).collect { |pitch, i| SequenceNote(pitch, 0, note.length, #[gate, 0.5, ffreq, 800]) }) ++ note /*.copy.args_(#[gate, 0.5, ffreq, 800]) */;
		temp[0] ++ temp[1..]
	} { note }
}, (mode: \d));
)

d.notes[0].postcs;

Pseq(d.notes, 1).asStream.nextN(10, ()).do(_.postln); ""

e = "..|S.....S.S..|Ss.Ss.s.s.s.Ss..|S..S.Sssss.Ss>|
..S.Sssss.Ssssssss---|
S..S.Sss.Ssss.>|S..S.Ss---|>-->-->--|
S..S.S.S...S..|S.Ss.S..>--|
>-->--|>--->...>--|Ss-";

f = Pseq(e, 1).reject { |ch| "|\n".includes(ch) };

(
z = Pbind(
	\voicer, VC(\tri).v,
	\note, Pseq(k.notes, 1),
	\dur, Pfunc({ |ev| ev[\note].dur }),
	\midi, true,
	\ffreq, Pfunc({ |ev|
		var a = ev[\note].args, i;
		if(a.isArray and: { (i = a.indexOf(\ffreq)).notNil }) {
			a[i+1]
		} {
			max(2500, ev[\note].freq.midicps * 3)
		}
	}),
	\artic, Pclutch(f, Pkey(\dur) <= 0 && (Pdiff(Pkey(\dur)) < 0)),
	\sustain, Pfunc({ |ev| ev[\note].length }),
	\length, Pnsym1(Pkey(\artic).collect({ |ch| ch.asSymbol }), (
		'.': Pkey(\sustain) * 0.6,
		's': Pkey(\sustain) + 0.05,
		'>': Pkey(\sustain) * 0.8,
		'-': Pkey(\sustain) * 0.92
	)),
	\gate, Pif(Pfunc({ |ev| ev[\artic] == $> }), 0.6, 0.4)
).play(protoEvent: ProtoEvent(\voicerNote).copy)
)

z.stop;

Pclutch(f, Pkey(\dur) <= 0 && (Pdiff(Pkey(\dur)) < 0)).postcs

VC(\tri).v.trigger(#[38, 50, 62].midicps, 0.5, [holdtime: 1000]);
VC(\tri).v.releaseAll;

d.notes.every(_.isMemberOf(SeqChordNote))

d.writeArchive(thisProcess.nowExecutingPath.dirname.dirname +/+ "support/unison-midirecbuf.txarch");

bench { k = Object.readArchive(thisProcess.nowExecutingPath.dirname.dirname +/+ "support/unison-midirecbuf.txarch") };



c.notes.detect(_.isMemberOf(SeqChordNote)).inspect

(
var oct = Pseq([0, -24, Pshuf(#[-12, 12, 24])]).asStream;
z = Pbind(
	\voicer, VC(\tri).v,
	\note, Pseq(c.notes, 1),
	\isChord, Pfunc({ |ev|
		var a = ev[\note].args, i;
		if(a.isArray) {
			if((i = a.indexOf(\isMain)).notNil) {
				ev[\isMain] = a[i+1];
			} {
				ev[\isMain] = 0;
			};
			if((i = a.indexOf(\isChord)).notNil) {
				a[i+1]   // return value
			} {
				0
			}
		} {
			ev[\isMain] = 0;
			0
		}
	}),
	\artic, Pclutch(f, Pkey(\isMain) > 0),
	\sustain, Pfunc({ |ev| ev[\note].length }),
	\length, Pnsym1(Pkey(\artic).collect({ |ch| ch.asSymbol }), (
		'.': Pkey(\sustain) * 0.6,
		's': Pkey(\sustain) + 0.05,
		'S': Pkey(\sustain) + 0.05,
		'>': Pkey(\sustain) * 0.8,
		'-': Pkey(\sustain) * 0.92
	)),
	\dur, Pfunc({ |ev| ev[\note].dur }),
	\midi, true,
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
).play(protoEvent: ProtoEvent(\voicerNote).copy)
)

z.stop;

(VC(\tri).v.gate([
	69, 71, 76,
	81, 83, 88
].midicps.debug, 2, 0.5, [ffreq: 3000])
)



(
// so full of hacks I could just scream
PR(\abstractProcess).clone {
	~event = (eventKey: \voicerNote, midi: true);
	~alwaysReset = true;
	~printStopMsg = false;

	// ~prep = {
	// };

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
)

Fact(\triVC) => VC(\tri);

PR(\unison) => BP(\un);
Object.readArchive(thisProcess.nowExecutingPath.dirname.dirname +/+ "support/unison-parsed.txarch") => BP(\un);
VC(\tri) => BP(\un);
1 => BP(\un);

BP(\un).listVars;


// still a mistake: "main" note is not necessarily highest
b = BP(\un).midibuf;

c = b.notes.select(_.isMemberOf(SeqChordNote));

[c[0].freq, c[0].chordNotes.asFloat]

// for some, "main" is top
c.select { |note| note.chordNotes.asFloat.every(_ < 0) } [0].postcs

// after fix, all "main" notes are top
c.count { |note| note.chordNotes.asFloat.any(_ > 0) }

[64, 74, 83].sort(_ > _).differentiate

// if I mess up
b = Object.readArchive(thisProcess.nowExecutingPath.dirname.dirname +/+ "support/unison-parsed.txarch");

b.notes.do { |note|
	if(note.isMemberOf(SeqChordNote)) {
		note.args = #[gate, 0.5, isChord, 1, isMain, 1];
		note.chordNotes.do(_.args = #[gate, 0.5, isChord, 1, isMain, 0]);
	} {
		note.args = #[gate, 0.5, isChord, 0, isMain, 1];
	}
};

b.notes.do { |note|
	var abs;
	if(note.isMemberOf(SeqChordNote)) {
		if(note.chordNotes.asFloat.every(_ < 0).not) {
			abs = note.asNoteArray.asFloat.sort(_ > _);
			note.freq = abs[0];
			note.chordNotes = abs[1..].collect { |chNote, i|
				note.chordNotes[i].copy.freq_(chNote - abs[0])
			};
		}
	}
};

b => BP(\un);

BP(\un).event.finish = nil;

// suppress chord accent for last 3
(140..142).do { |i| b.notes[i].argPut(\suppressAccent, 1) };

b.dumpSeq;

b.writeArchive(thisProcess.nowExecutingPath.dirname.dirname +/+ "support/unison-parsed.txarch");


// chord accents

Fact(\madfmVC) => VC(\fm);  // 1JkRVE

Pn(#[0.25, 0.15, 0.5], 1) => MicRh(\unCh);

(
BP(\unCh).free;
\newCh.eval(\unCh, \arpeg1, \macroRh, MBM(0)[\pzch], nil, Pn(1, inf), \unCh, \block, nil, \d);
)

VC(\fm) => BP(\unCh);

p = BP(\unCh);

p.topNote = PR(\patternTop).copy.make {
	~mode = \d;
};

// ModalSpec((0..11), 12, 0) => Mode(\chrom);

BP(\un).event.finish = {
	if(~suppressAccent == 0 and: { ~isMain == 1 and: { ">S".includes(~artic) } }) {
		// roundUp: G# as topNote sounds like hell, make it A-nat
		BP(\unCh).topNote.deg = ((~freq ?? { ~note.asFloat }).first.mapMode(\d).roundUp + 7);
		BP(\unCh).triggerOneEvent(0);
	};
};

p.topNote.deg = 74;
p.child.fitFunc = \chordFitInt;

p.prepareForPlay;
p.triggerOneEvent(0);

(
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
)

VC(\fm).panic

s.sendMsg(\g_freeAll, 23);

