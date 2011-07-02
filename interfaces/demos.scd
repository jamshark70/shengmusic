
// ChuckableBrowser.newWindow;

var dir = thisProcess.nowExecutingPath.dirname,
	win, buttons;

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

win.onClose = {
	~updaters.do { |upd| upd.remove };
	if(Platform.ideName == "none") { 0.exit };
};

buttons = ~demos.collect { |demo|
	StaticText(win, 200@50)
		.string_(demo.name)
		.align_(\center);
	
	PR(\playPauseButton).copy.prep(win, 50@50)
	.userAction_({ |view|
		if(view.currentState == 1) {
			demo.play;
		} {
			demo.stop;
		};
	});
};

win.recursiveResize.front;


~updaters = ~demos.collect { |demo, i|
	SimpleController(demo)
	.put(\done, {
		buttons[i].currentState = 0;
	})
	.put(\play, {
		buttons[i].currentState = 1;
	})
};


/*
~demos[0].dependants

~demos[0].play;
~demos[0].stop;
*/
