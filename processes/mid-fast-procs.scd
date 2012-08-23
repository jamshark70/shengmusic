forkIfNeeded {
var cond = Condition.new;

if(PR.exists(\shengShared).not) {
	loadPath(thisProcess.nowExecutingPath.dirname.dirname +/+ "common/common-defs.scd");
};

if(BP.exists(\shengShared).not) {
	PR(\shengShared) => BP(\shengShared);
	NotificationCenter.registerOneShot(BP(\shengShared).v, \sharedReady, \longch, {
		cond.unhang;
	});
	cond.hang;
};




};