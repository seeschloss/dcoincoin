module dcc.gtkd.post;

private import std.string;

private import gtk.TextMark;

private import dcc.gtkd.main;
private import dcc.engine.tribune;

struct GtkPostSegmentContext {
	bool bold = false,
		 italic = false,
		 underline = false,
		 strike = false,
		 fixed = false,
		 clock = false,
		 link = false,
		 totoz = false;
}

struct GtkPostSegment {
	GtkPostSegmentContext context;
	string text;
}

class GtkPost {
	Post post;
	TextMark begin, end;
	GtkTribune tribune;

	this(GtkTribune tribune, Post post) {
		this.tribune = tribune;
		this.post = post;
	}

	GtkPostSegment[] segmentize() {
		string[] tokens = this.tokenize();
		GtkPostSegment[] segments;

		GtkPostSegmentContext context;
		foreach (int i, string sub; tokens) {
			GtkPostSegment segment;

			bool is_clock = false;

			foreach (Clock post_clock; this.post.clocks) {
				if (sub.strip == post_clock.text) {
					context.clock = true;
				}
			}

			switch (sub.strip()) {
				case "<b>":
					context.bold = true;
					break;
				case "</b>":
					context.bold = false;
					break;
				case "<i>":
					context.italic = true;
					break;
				case "</i>":
					context.italic = false;
					break;
				case "<u>":
					context.underline = true;
					break;
				case "</u>":
					context.underline = false;
					break;
				case "<s>":
					context.strike = true;
					break;
				case "</s>":
					context.strike = false;
					break;
				default:
					segment.text ~= sub.dup;
					break;
			}

			segment.context = context;

			if (segment.text) {
				segments ~= segment;
			}

			if (context.clock) {
				context.clock = false;
			}
		}

		return segments;
	}

	// This is the same function as for the curses interface, for now...
	string[] tokenize() {
		string line = this.post.message.replace(regex(`\s+`, "g"), " ");

		// Since I can't use backreferences here...
		line = line.replace(regex(`<a href="(.*?)".*?>(.*?)</a>`, "g"), "<$1>");
		line = line.replace(regex(`<a href='(.*?)'.*?>(.*?)</a>`, "g"), "<$1>");

		line = std.array.replace(line, "&lt;", "<");
		line = std.array.replace(line, "&gt;", ">");
		line = std.array.replace(line, "&amp;", "&");

		string[] tokens = [""];

		bool next = false;
		foreach (char c; line) {
			switch (c) {
				case '<':
					tokens ~= "";
					break;
				case '{':
				case '[':
				case '(':
				case ' ':
				case ',':
					tokens ~= "";
					next = true;
					break;
				case ']':
				case '>':
					next = true;
					break;
				default:
					break;
			}

			tokens[$-1] ~= c;

			if (next) {
				tokens ~= "";
				next = false;
			}
		}

		return tokens;
	}
}

