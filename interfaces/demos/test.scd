
Proto {
	~name = "test";

	~play = {
		"running test".postln;
		currentEnvironment.changed(\play);
	};

	~stop = {
		"stopping test".postln;
		currentEnvironment.changed(\done);
	};
}
