
// ChuckableBrowser.newWindow;

var dir = thisProcess.nowExecutingPath.dirname,
	win, buttons;


Proto {
	~name = "demo";

	~play = {
		~go.();
		currentEnvironment.changed(\play);
	};

	~stop = {
		~end.();
		currentEnvironment.changed(\done);
	};
} => PR(\demoProto);

(dir +/+ "../common/transports.scd").loadPath;

~demos = (dir +/+ "demos/*.scd").pathMatch.collect { |path|
	var result;
	try {
		result = path.loadPath;
	} { |error|
		error.reportError;
		"^^^^ ERROR while loading %\n".postf(path);
	};
	result
};


win = ResizeFlowWindow("demos", Rect(500, 50, 500, 700));
StaticText(win, 220@40)
	.string_("Close this window to end program");
win.startRow;

win.onClose = e {
	~updaters.do { |upd| upd.remove };
	~demos.do { |demo| demo.destroy };
	~board.free;
	~master.free;
	if(Platform.ideName == "none") { s.quit; 0.exit };
};

buttons = ~demos.collect { |demo|
	var	btn;

	StaticText(win, 200@50)
		.string_(demo.name)
		.align_(\center);
	
	btn = PR(\playPauseButton).copy.prep(win, 50@50)
	.userAction_({ |view|
		if(view.currentState == 1) {
			demo.play;
		} {
			demo.stop;
		};
	});
	win.startRow;
	btn
};

win.recursiveResize.front;


~updaters = ~demos.collect { |demo, i|
	SimpleController(demo)
	.put(\done, {
		{ buttons[i].currentState = 0 }.defer;
	})
	.put(\play, {
		{ buttons[i].currentState = 1 }.defer;
	})
};


~board = \makeEmptyMixer8.eval;

{
	var	bounds = ~board.w.bounds;
	~board.w.bounds = bounds.moveTo(bounds.left, Window.screenBounds.height - 50 - bounds.height);
	bounds = win.bounds;
	win.bounds = bounds.moveTo(bounds.left, Window.screenBounds.height - 50 - bounds.height);
}.defer(1.5);

s.boot;
s.makeGui;
s.doWhenBooted({
	~master ?? { ~master = MixerChannel(\master, s, 2, 2, level: 1) };
	~master => MCG(7);
});


/*
~demos[0].dependants

~demos[0].play;
~demos[0].stop;
*/
