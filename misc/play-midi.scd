m = SimpleMIDIFile.read("~/Documents/xinghai/sheng-piece/drafts/fast-sketch1.midi");
p = m.p;

a = (Pbind(\type, \voicerNote, \voicer, MIDIPort.at(\omni).sockets[0].destination) <> p).play;
