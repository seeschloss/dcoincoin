module dcc.gtkd.post;

private import std.conv;
private import std.string;
private import std.stdio;

private import gtk.TextMark;

private import dcc.gtkd.main;
private import dcc.engine.tribune;

struct GtkPostSegmentContext {
	bool bold = false,
		 italic = false,
		 underline = false,
		 strike = false,
		 fixed = false,
		 link = false,
		 totoz = false,
		 login = false,
		 mainClock = false;

	Clock clock;

	string link_target = "";
}

class GtkPostSegment {
	GtkPostSegmentContext context;
	string text;

	GtkPost post;
	uint offset;
}

class GtkPost {
	Post post;
	GtkTribune tribune;
	GtkPostSegment[] _segments;
	GtkPostSegment[int] segmentIndices;

	GtkPostSegment[] clockReferences;

	bool answer = false;
	GtkPost[] referencedPosts;
	GtkPost[GtkPost] referencingPosts;

	this(GtkTribune tribune, Post post) {
		this.tribune = tribune;
		this.post = post;
	}

	string id() {
		return this.post.post_id ~ "@" ~ this.tribune.tribune.name;
	}

	override string toString() {
		return this.id;
	}

	void checkIfAnswer() {
		foreach (GtkPost post ; this.referencedPosts) {
			if (post.post.mine) {
				writeln("This post ", this.post, " answers ", post.post);
				this.answer = true;
				return;
			}
		}
	}

	GtkPostSegment getSegmentAt(int offset) {
		foreach (GtkPostSegment segment; this._segments) {
			if (segment.offset <= offset && segment.offset + segment.text.count > offset) {
				return segment;
			}
		}

		return null;
	}

	GtkPostSegment[] segments() {
		if (this._segments.length > 0) {
			return this._segments;
		}

		string[] tokens = this.tokenize();

		int offset = 0;

		GtkPostSegmentContext context, previousContext;
		foreach (int i, string sub; tokens) {
			GtkPostSegment segment = new GtkPostSegment();
			segment.post = this;
			segment.offset = offset;

			bool is_clock = false;

			previousContext = context;

			foreach (Clock post_clock; this.post.clocks) {
				if (sub.strip == post_clock.text) {
					context.clock = post_clock;
				}
			}

			switch (sub.strip()) {
				case "<a>":
					context.link = true;
					break;
				case "</a>":
					context.link = false;
					break;
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

			if (context.link && segment.text) {
				context.link_target ~= segment.text;
			}
			segment.context = context;

			if (!context.link && context.link_target.length > 0) {
				// The link has been completely parsed
				segment.text = "[url]";
				segment.context.link = true;
				context.link_target = "";
			}
			
			if (segment.text && !context.link) {
				// This is a regular segment
				this._segments ~= segment;
				offset += segment.text.count;
			}

			if (context.clock != Clock.init) {
				context.clock = Clock.init;
			}
		}

		return this._segments;
	}

	// This is the same function as for the curses interface, for now...
	string[] tokenize() {
		string line = this.post.message.replace(regex(`\s+`, "g"), " ");

		// Since I can't use backreferences here...
		line = line.replace(regex(`<a href="(.*?)".*?>(.*?)</a>`, "g"), "<a>$1</a>");
		line = line.replace(regex(`<a href='(.*?)'.*?>(.*?)</a>`, "g"), "<a>$1</a>");

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

