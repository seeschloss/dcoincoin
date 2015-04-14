module dcc.curses.cli;

private import std.stdio : stderr, writefln;
private import std.string : toStringz;

private import dcc.engine.tribune;

extern (C) { char* setlocale(int category, const char* locale); }

void main(string[] args) {
	setlocale(0, "".toStringz());

	string backend = "";
	bool tags_encoded = false;
	if (args.length > 2 && args[1] == "-t") {
		tags_encoded = true;
		backend = args[2];
	} else if (args.length > 1) {
		backend = args[1];
	} else {
		stderr.writeln("Usage: ", args[0], " [-t] <url>");
		return;
	}

	Tribune tribune = new Tribune(backend, tags_encoded);

	tribune.on_new_post ~= (Post post) {
		writefln("%s\t%s\t%s\t%s\t%s",
			post.post_id,
			post.tribune_time,
			post.info.length > 0 ? post.info : "-",
			post.login.length > 0 ? post.login : "-",
			post.message);
	};

	tribune.fetch_posts();
}

