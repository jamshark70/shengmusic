~performance = true; (thisProcess.nowExecutingPath.dirname +/+ "../common/dev-setup.scd").loadPath;
// (thisProcess.nowExecutingPath.dirname +/+ "../common/common-defs.scd").loadPath;

(thisProcess.nowExecutingPath.dirname +/+ "../processes/drones-and-clicks.scd").loadPath;
(thisProcess.nowExecutingPath.dirname +/+ "../processes/long-ch-procs.scd").loadPath;
(thisProcess.nowExecutingPath.dirname +/+ "../processes/mid-fast-procs.scd").loadPath;
(thisProcess.nowExecutingPath.dirname +/+ "../processes/climax-procs.scd").loadPath;
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

BP(\susCh).prepareForPlay;
BP(\susCh).triggerOneEvent(0);


(
BP(\dc).free;
PR(\decimator).chuck(BP(\dc), nil, (master: ~master, rvbmc: ~rvbmc));
0 => BP(\dc);

BP(\dc).startWidth = Pwhite(2000, 8000, inf);
BP(\dc).startCenter = (948088 + Pwhite(-40000, 40000, inf));

PR(\decimatorDriver) => BP(\dcdr);
BP(\dcdr) => MT(1);
)



Fact(\triVC) => VC(\tri);
Fact(\tripletBP) => BP(\tri);
VC(\tri) => BP(\tri);
PR(\triDriver).chuck(BP(\td), nil, (bp: \tri));

BP(\td).playMode = \accel;
BP(\td).playMode = \decel;
BP(\td).playMode = \accelrit;
BP(\td).playMode = \overlap;

BP(\td).playMode = Prand(#[accel, decel, accelrit, overlap], inf).trace;
BP(\td).dftRest = Pwhite(1.0, 2.5, inf);

// overlap is insanely way too long, use sparingly

MultiEQ(2).edit(VC(\tri).env.target);