~performance = true; (thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;
// (thisProcess.nowExecutingPath.dirname +/+ "../common/common-defs.scd").loadPath;

~liveSheng = false;
// ~liveSheng = true;

(
#["../processes/drones-and-clicks.scd", "../processes/long-ch-procs.scd", "../processes/mid-fast-procs.scd", "../processes/climax-procs.scd"].do { |path|
	(thisProcess.nowExecutingPath.dirname +/+ path).loadPath;
};
)

TempoClock.tempo = 100/60;

TempoClock.default.gui;

BP(\shengShared).free;
PR(\shengShared) => BP(\shengShared);

MixingBoard.at(0).postSettings;

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);

s.addr = ~debugAddr;
s.addr = ~saveAddr;


VC.freeType(\sheng);
BP.freeType(\sheng);


BP(\mic).free; PR(\micIn).chuck(BP(\mic), nil, (master: ~master, rvbmc: ~rvbmc));
BP(\mic) => MT(1);


(
// drones
BP(\sd).free;
PR(\shengDrone) => BP(\sd);
0 => BP(\sd);
BP(\sd) => MT(1);

BP(\sdg).free;
PR(\sdGestureCtl) => BP(\sdg);
BP(\sdg) => MT(1);

// bells
\makeBowedBellVC.eval;
BP(\bw).free;
PR(\bowed) => BP(\bw);
VC(\bowedFM) => BP(\bw);
0 => BP(\bw);
BP(\bw) => MT(1);

BP(\sd) => MCG(0);
VC(\bowedFM) => MCG(1);
)


// long chords section
(
BP(\cl).free;
PR(\clicks).chuck(BP(\cl), nil, (master: ~master, rvbmc: ~rvbmc));
// BP(\cl) => MCG(3);
0 => BP(\cl);
BP(\cl) => MT(1);

BP(\birds).free;
PR(\birds).chuck(BP(\birds), nil, (master: ~master, rvbmc: ~rvbmc));
0 => BP(\birds);
BP(\birds) => MT(1);

BP(\cl) => MCG(2);
BP(\birds) => MCG(3);
BP(\cl).chan.level = 0;
BP(\birds).chan.level = 0;
)




// play clicks before m17
// fade in both slowly (birds after)

// retriggered pizzes
(
if(~liveSheng == true) { Fact(\recBP) => BP(\rec) } { BP(\rec).free };

VC(\nlet).free;
Fact(\noiseletVC) => VC(\nlet);

Fact(\highChBP).chuck(BP(\firstPitch), nil, (
	customizeHook: { |proc|
		0 => proc;
		MBM(0)[\simpleCh] => proc;
		Pwhite(14.0, 20.0, 3) =>.macro proc;
		\asis1 =>.arpeg proc;
		proc.child.fitFunc = \asis;
		\slowHighCh =>.micro proc;
		proc.child.event.ctranspose = 12;
	}
));
VC(\nlet) => BP(\firstPitch);
BP(\firstPitch) => MT(1);

VC(\pz).free;
Fact(\pizz) => VC(\pz);
VC(\pz) => MCG(4);
VC(\pz).env.target.level = 0;
VC(\pz) => VP(0);

BP(\pz).free;
Fact(\pzBP) => BP(\pz);
VC(\pz) => BP(\pz);

BP(\pzr).free;
PR(\chordRunner).chuck(BP(\pzr), nil, (bp: \pz));
BP(\pzr) => MT(1);
)

BP(\pzr).put(\first, true);


// c. m36, bring up retrigProb, then, quickly...

(
VC(\lpizz).free;
Fact(\lowpizz).chuck(VC(\lpizz), nil, (initLevel: -12.dbamp));

BP(\lowCh).free;
Fact(\lowChBP) => BP(\lowCh);
VC(\lpizz) => BP(\lowCh);
0 => BP(\lowCh);
BP(\lowCh) => MT(1);

Pfin(2, MacRh(\lowCh).asPattern) =>.macro BP(\lowCh);
)

(
BP.all.stop;
~lowch = TLSequenceIterator([
	{
		VC(\lpizz).globalControls[\retrigProb].value = 0.12;
		0
	},
	bpCmd: (name: \lowCh, prepareBP: _.reset),
	\cmdSync,
	{
		VC(\lpizz).globalControls[\retrigProb].value = 1;
		(type: \voicerNote, voicer: VC(\lpizz), freq: [31, 43].midicps, pan: 0, baseDur: 20, env: [Env.one(4)], amp: 2, retrigProb: 1, ffreq: 31.midicps * 16, fbamp: 0.98).play;
		0
	}
]).play;
)


// m40: play \cl, \pz
// m45: stop

\makeSusChBP.eval;

BP.all.do(_.stop(0));
BP(\susCh).prepareForPlay;
BP(\susCh).triggerOneEvent(0);


(
BP(\dc).free;
PR(\decimator).chuck(BP(\dc), nil, (
	master: ~master, rvbmc: ~rvbmc, bufRecorder: if(BP.exists(\rec)) { \rec } { nil },
	initLevel: -7.dbamp,
	startCenter: Pfunc({ |ev| ~bufTimes[ev[\bufindex]].choose * s.sampleRate + 1500 })
));
0 => BP(\dc);

// BP(\dc).startWidth = Pwhite(2000, 8000, inf);
// BP(\dc).startCenter = (948088 + Pwhite(-40000, 40000, inf));

PR(\decimatorDriver) => BP(\dcdr);
BP(\dcdr) => MT(1);
)

// \dc --> -10 dB

(
Fact(\triVC).chuck(VC(\tri), nil, (initLevel: -12.5.dbamp));
Fact(\tripletBP) => BP(\tri);
VC(\tri) => BP(\tri);
PR(\triDriver).chuck(BP(\td), nil, (bp: \tri));
1 => BP(\td);
BP(\td) => MT(1);
)

BP(\td).dftRest = Pwhite(3, 7, inf);

// m.52: play \td


BP(\td).playMode = Pseq([\accelrit, Prand(#[accel, decel, accelrit], inf)]);
BP(\td).dftRest = Pwhite(1.0, 2.5, inf);

BP(\td).playMode = Prand(#[accel, decel, accelrit], inf).trace;

BP(\td).playMode = Prand(#[accel, decel, accelrit, overlap], inf);
BP(\td).dftRest = Pwhite(1.0, 2.5, inf);

g = GenericGlobalControl(\lpfreq, nil, 2000, \freq); g => VP(0);
h = GenericGlobalControl(\hprq, nil, 1, \myrq); h => VP(0);

a = VC(\slowTri).env.target.playfx({ |outbus| RLPF.ar(In.ar(outbus, 2), g.kr, h.kr) });

a.trace

a.free;



// around m. 61
(
MIDIRecBuf(\lowChGshp, [
	#[28, 40, 47, 54, 56, 62, 69],
	(0.1 ! 7).put(6, 1), 0.1, 0.5
].asNotes, (type: \ch, mode: \d)) => BP(\lowCh);
Pn(13, 1) =>.macro BP(\lowCh);
VC(\lpizz).env.target.level = -18.8.dbamp;
)




// mm65-67? THIS IS REALLY WAY TOO LOUD
(
VC(\slowTri).free;
Fact(\triVC).chuck(VC(\slowTri), nil, (
	env: Env.adsr(0.8, 1.2, 0.4, 2.4, curve: #[3, -1, -2]),
	initLevel: -12.5.dbamp
));

BP(\bigA).free;
PR(\bigA) => BP(\bigA);
BP(\bigA) => MT(1);
)


// drones, new notes
(
BP(\efg).free;
PR(\e_fs_g) => BP(\efg);
VC(\nlet) => BP(\efg);
0 => BP(\efg);
BP(\efg) => MT(1);

BP(#[sd, efg]).do(_.reset);
BP(\sd).setGstNow(\eminTrans);
)

// play efg and sd together



// introduce rhythm: play this, fade out sd
(
BP(\sd8).free;
Fact(\sd8BP) => BP(\sd8);
BP(\sd8) => MT(1);
)

BP(\sd8).v[\setGstNow].postcs

BP(\sd8).setGstNow(\d16, 1);

BP(\sd8).setGstNow(Pseq([Pn(\d16, { rrand(3, 7) }), \triad8], inf), 1);

// m97: G#

// rhythmic clicks
(
BP(\gcl).free;
PR(\gridClicks).chuck(BP(\gcl), nil, (master: ~master/*, initLevel: -9.dbamp*/));
1 => BP(\gcl);
BP(\gcl) => MT(1);
BP(\gcl).chan.level = -12.dbamp;
)


// existing procs:
// Fact('oscilBP'), Fact('flzgBP'), Fact('slowMelBP'), Fact('rpt16BP'), Fact('sd8BP')
// PR('gridClicks'), PR('fastlow')
// Voicer: Fact('madfmVC')
//
// Fact.all.select { |fact| fact.path.containsi("mid-fast") };
// PR.all.select { |fact| fact.path.containsi("mid-fast") };
// Func.all.select { |fact| fact.path.notNil and: { fact.path.containsi("mid-fast") } };

(
\makeOnePizzVC.eval;  //??
\chuckIf.eval(Fact(\triVC), VC, \tri);
Fact(\madfmVC) => VC(\fm);
\makeflzgVC.eval(\flzg);
\makeBassVC.eval(\qb);

VC(\tri).v.set([lpfreq: 3000]);
VC(\flzg).v.set([lpfreq: 2540]);

Fact(\rpt16BP) => BP(\rp);
BP(\rp).leadTime = 0.01;
BP(\rp) => MT(1);

BP(\sbs).free;
PR(\sbass) => BP(\sbs);
VC(\qb) => BP(\sbs);
BP(\sbs) => MT(1);
BP(\sbs).quant = AbsoluteTimeSpec(Pfunc({ BP(\rp).nextBeat + BP(\rp).leadTime }));
VC(\qb).env.target.level = 0;

VC(\onePizz).env.target.level = -20.dbamp;
VC(\tri).env.target.level = -10.8.dbamp;
VC(\fm).env.target.level = -18.dbamp;
)

// MOVE QUICKLY

VC(\qb).env.target.automate(\level, \ctlPoint, [value: -12.dbamp, time: 9, curve: 3]);

MacRh(\rpt16syncop) => BP(\rp);

BP(\sbs).dur = BP(\sbs).dur2; BP(\sbs).length = BP(\sbs).length2;

MacRh(\rpt16syncop2) => BP(\rp);

// f*** up the harmony *evil grin*
BP(\rp).topNote.mode = Pxrand(Mode.keys.asArray.select { |key| key.asString.last == $0 }, inf);
BP(\sbs).mode = Pfunc({ BP(\rp).lastEvent.top.mode });


// BP(#[rp, sbs]).stop;


// low fm, melody counterpont
(
\makeFMLowVC.eval;
BP(\fastlow).free;
PR(\fastlow) => BP(\fastlow);
BP(\fastlow) => VC(\fmlow);
BP(\fastlow) => MT(1);
VC(\fmlow).env.target.level = -10.dbamp;

\makeNletMelVC.eval;
Fact(\slowMelBP) => BP(\slowmel);
BP(\slowmel) => VC(\nletmel);
BP(\slowmel) => MT(1);
1 => BP(\slowmel);
BP(\slowmel).repeats = inf;
BP(\slowmel).macro = Pwhite(1, 4, inf);
VC(\nletmel).env.target.level = -8.6.dbamp;

if(VC.exists(\onePizz).not) { \makeOnePizzVC.eval };
Fact(\scotchBP) => BP(\scotch);
BP(\scotch) => VC(\onePizz);
1 => BP(\scotch);
BP(\scotch) => MT(1);
Pwxrand(#[1, 2, 3, 4, 5], #[2, 2, 4, 4, 3].normalizeSum, inf) =>.macro BP(\scotch);
)

// FADE FASTLOW

// unison
// needs rhythmic pizz embellishment in places, preparing for big chords
(
\chuckIf.eval(Fact(\triVC), VC, \tri, nil, (initLevel: -12.5.dbamp));
PR(\unison) => BP(\un);
VC(\tri) => BP(\un);
1 => BP(\un);
BP(\un) => MT(1);

\chuckIf.eval(Fact(\madfmVC), VC, \fm);  // 1JkRVE
Fact(\unChBP) => BP(\unCh);
VC(\fm) => BP(\unCh);
1 => BP(\unCh);
BP(\un).doublingOn = true;

\makePizzRhyVC.eval;
Fact(\pzclimaxBP) => BP(\pzclimax);
VC(\pzrhy) => BP(\pzclimax);

\chuckIf.eval(PR(\clicks), BP, \cl, nil, (master: ~master, rvbmc: ~rvbmc));
\chuckIf.eval(PR(\gridClicks), BP, \gcl, nil, (master: ~master, rvbmc: ~rvbmc));
1 => BP(\gcl);

PR(\gridClicks).chuck(BP(\decelCl), nil, (
	master: ~master, rvbmc: ~rvbmc,
	dur: Plazy({ Env([rrand(0.08, 0.12), rrand(0.35, 0.5)], [~latestPhraseDur], \exp) })
));

if(VC.exists(\onePizz).not) { \makeOnePizzVC.eval };
BP(\sdSwells).free;
PR(\sdSwells) => BP(\sdSwells);
VC(\onePizz) => BP(\sdSwells);

BP(\climaxSeq).free;
Fact(\climaxSeqBP) => BP(\climaxSeq);
BP(\climaxSeq) => MT(1);
)

BP(#[fastlow, slowmel, scotch]).stop(1);
BP(\climaxSeq).play;

BP(\climaxSeq).playUnison = false;



(
BP(\sd8).setGstNow(\d8DescMany);
BP(\sd8).makeStreamForKey(\endDegreeMany);
BP(\sd8).makeStreamForKey(\gesture);
BP(\sd8).reset;
BP(\sd8).chan.level = -9.dbamp;

BP(\efg).freq = Ppatlace([
	Pseries(42, Pwhite(-2, -1, inf), inf),
	Pseries(43, Pwhite(1, 2, inf), inf)
], inf).collect(_.unmapMode(\d));

BP(\sd8).addDependant(BP(\efg).v);
BP(\efg)[\update] = { |obj, what, more|
	if(more == \stopped) {
		BP(~collIndex).stop(0);
		BP(\sd8).removeDependant(BP(~collIndex).v);
	};
};
)

// play sd8 and efg together

// fade in clicks and birds (in fully by cadenza)



(
BP(\sd).makeStreamForKey(\codaNotePool);
BP(\sd).makeStreamForKey(\codaDurPool);
BP(\sd).setGstNow(\coda);
BP(\sd).reset;
BP(\sd).chan.level = -6.dbamp;
BP(\dc).chan.level = -19.dbamp;
)