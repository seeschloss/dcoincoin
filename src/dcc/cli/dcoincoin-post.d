module dcc.curses.post;

private import std.stdio : stderr, stdin, writefln;
private import std.string : toStringz;
private import std.process : environment;
private import std.conv : to;

private import dcc.engine.conf;
private import dcc.engine.tribune;

extern (C) { char* setlocale(int category, const char* locale); }

void main(string[] args) {
	setlocale(0, "".toStringz());

	string tribune_name = "";
	if (args.length > 1) {
		tribune_name = args[1];
	} else {
		stderr.writeln("Usage: ", args[0], " <tribune name>");
		return;
	}

	string config_file = environment.get("HOME") ~ "/.dcoincoinrc";
	auto config = new Config(config_file);

	foreach (Tribune tribune ; config.tribunes) {
		if (tribune.name == tribune_name) {
			foreach (line; stdin.byLine) {
				tribune.post(to!string(line));
			}
		}
	}
}

