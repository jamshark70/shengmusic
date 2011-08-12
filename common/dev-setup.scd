var d = thisProcess.nowExecutingPath.dirname.dirname;

~saveAddr = s.addr;
~debugAddr = DebugNetAddr("127.0.0.1", 57110);

BP.loadGui;

NotificationCenter.registerOneShot(\chucklibGui, \ready, \devSetup, e {
	~master = MixerChannel(\master, s, 2, 2, level: -20.dbamp);
	~master => MCG(7);

	[m, n].free;
	m = MixerChannel(\test1, s, 1, 2, outbus: ~master);
	n = MixerChannel(\test2, s, 2, 2, outbus: ~master);
	m => MCG(0); n => MCG(1);

	["common/common-defs.scd"].do { |file|
		(d +/+ file).loadPath;
	};
});
