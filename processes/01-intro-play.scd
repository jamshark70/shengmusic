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


(
Fact(\triVC).chuck(VC(\tri), nil, (initLevel: -12.5.dbamp));
Fact(\tripletBP) => BP(\tri);
VC(\tri) => BP(\tri);
PR(\triDriver).chuck(BP(\td), nil, (bp: \tri));
1 => BP(\td);
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
)


(
if(t.isPlaying) { t.stop };
t = TLSequenceIterator([
	bpCmd: (name: \sd,
		prepareBP: { |p|
			~saveGst = p.gst;
			p.setGstNow(Pn(\bigAChord, 1).trace);
			p.gst.postcs;
		},
		clearDoneSignal: { ~isRunning = false; BP(\sd).stopNow; BP(\sd).setGstNow(~saveGst) }
	),
	0.4,
	pdefCmd: (name: \triAChord),
	gcAutoSynthCmd: (
		gc: VC(\slowTri).globalControls[\lpfreq],
		name: \ctlEnv, outName: \outbus,
		connect: 0,
		env: Env(#[900, 7500, 1700], #[1.5, 3], \sin)
	),
	\sync,
	{ "seq done".postln; 0 }
]).play;
)



// mm65-67?
(
VC(\slowTri).free;
Fact(\triVC).chuck(VC(\slowTri), nil, (env: Env.adsr(0.8, 1.2, 0.4, 2.4, curve: #[3, -1, -2])));

BP(\bigA).free;
PR(\bigA) => BP(\bigA);
)

