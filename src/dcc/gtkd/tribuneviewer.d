module dcc.gtkd.tribuneviewer;

private import std.stdio;

private import gtk.TextView;
private import gtk.TextBuffer;
private import gtk.TextIter;
private import gtk.TextMark;
private import gtk.Widget;

private import gtkc.gtktypes;

private import gdk.Color;
private import gdk.Cursor;
private import gdk.Event;

private import glib.ListSG;

private import dcc.engine.tribune;
private import dcc.gtkd.post;
private import dcc.gtkd.main;

class TribuneViewer : TextView {
	private TextMark begin, end;

	private GtkPost[string] posts;

	this() {
		this.setEditable(false);
		this.setCursorVisible(false);
		this.setWrapMode(WrapMode.WORD);
		this.setIndent(-10);

		TextBuffer buffer = this.getBuffer();

		buffer.createTag("mainclock", "foreground-gdk", new Color(50, 50, 50));
		buffer.createTag("login", "weight", PangoWeight.BOLD, "foreground-gdk", new Color(0, 0, 100));
		buffer.createTag("clock", "weight", PangoWeight.BOLD, "foreground-gdk", new Color(0, 0, 100));

		buffer.createTag("b", "weight"       , PangoWeight.BOLD);
		buffer.createTag("i", "style"        , PangoStyle.ITALIC);
		buffer.createTag("u", "underline"    , PangoUnderline.SINGLE);
		buffer.createTag("s", "strikethrough", 1);

		TextIter iter = new TextIter();
		buffer.getEndIter(iter);
		buffer.createMark("end", iter, false);

		this.addOnButtonRelease(&this.onClick);
		this.addOnMotionNotify(&this.onMotion);
	}

	bool onClick(Event event, Widget viewer) {
		int bufferX, bufferY;

		this.windowToBufferCoords(GtkTextWindowType.WIDGET, cast(int)event.motion().x, cast(int)event.motion().y, bufferX, bufferY);

		TextIter position = new TextIter();
		this.getIterAtLocation(position, bufferX, bufferY);

		GtkPost post = this.getPostAtIter(position);
		if (post) {
			int offset = position.getLineOffset();
			if (offset <= 8) {
				writeln("Clock");
			} else {
				GtkPostSegment segment = post.getSegmentAt(offset);
				if (segment.text.length) {
					if (segment.context.clock) {
						writeln("Segment: ", segment.text);
					}
				} else if (offset > 9 && offset < post.segmentIndices.keys[0] - 1) {
					writeln("Login");
				}
			}
		}

		return true;
	}

	bool onMotion(Event event, Widget viewer) {
		int bufferX, bufferY;

		this.windowToBufferCoords(GtkTextWindowType.WIDGET, cast(int)event.motion().x, cast(int)event.motion().y, bufferX, bufferY);

		TextIter position = new TextIter();
		this.getIterAtLocation(position, bufferX, bufferY);

		GtkPost post = this.getPostAtIter(position);
		
		GdkCursorType cursor = GdkCursorType.ARROW;

		if (post) {
			int offset = position.getLineOffset();
			if (offset <= 8) {
				//writeln("Clock");
				cursor = GdkCursorType.HAND1;
			} else {
				GtkPostSegment segment = post.getSegmentAt(offset);
				if (segment.text.length) {
					if (segment.context.clock) {
						//writeln("Segment: ", segment.text);
						cursor = GdkCursorType.HAND1;
					}
				} else if (offset > 9 && offset < post.segmentIndices.keys[0] - 1) {
					//writeln("Login");
				}
			}
		}

		this.setCursor(new Cursor(cursor));

		return false;
	}

	public GtkPost getPostAtIter(TextIter position) {
		TextIter iter = new TextIter ();

		this.getBuffer().getIterAtLine(iter, position.getLine());

		ListSG marks = iter.getMarks();

		for (int i = 0 ; i < marks.length() ; i++) {
			TextMark mark = new TextMark (cast (GtkTextMark*) marks.nthData(i));

			if (mark.getName() in this.posts) {
				return this.posts[mark.getName()];
			}
		}

		return null;
	}

	void registerTribune(GtkTribune gtkTribune) {
		gtkTribune.tag = "tribune" ~ gtkTribune.tribune.name;
		this.getBuffer().createTag(gtkTribune.tag, "paragraph-background", gtkTribune.color);
	}

	void scrollToEnd() {
		this.scrollMarkOnscreen(this.getBuffer().getMark("end"));
	}

	void renderPost(GtkPost post) {
		GtkPostSegment[] segments = post.segments();

		TextBuffer buffer = this.getBuffer();
		TextIter iter = new TextIter();
		buffer.getEndIter (iter);

		if (buffer.getCharCount() > 1) {
			buffer.insert (iter, "\n");
		}

		post.begin = buffer.createMark(post.post.post_id, iter, true);

		buffer.insertWithTagsByName(iter, post.post.clock, ["mainclock"]);
		buffer.insert(iter, " ");
		if (post.post.login) {
			buffer.insertWithTagsByName(iter, post.post.login, ["login"]);
		} else {
			buffer.insertWithTagsByName(iter, post.post.short_info, ["login"]);
		}
		buffer.insert(iter, " ");

		int postStart = iter.getLineOffset();

		foreach (GtkPostSegment segment; segments) {
			int segmentStart = iter.getLineOffset();
			post.segmentIndices[segmentStart] = segment;

			TextMark startMark = buffer.createMark("start", iter, true);
			TextMark endMark = buffer.createMark("start", iter, false);

			buffer.insert(iter, segment.text);

			TextIter startIter = new TextIter();
			buffer.getIterAtMark(startIter, startMark);

			if (segment.context.bold) {
				buffer.applyTagByName("b", startIter, iter);
			}

			if (segment.context.italic) {
				buffer.applyTagByName("i", startIter, iter);
			}

			if (segment.context.underline) {
				buffer.applyTagByName("u", startIter, iter);
			}

			if (segment.context.strike) {
				buffer.applyTagByName("s", startIter, iter);
			}

			if (segment.context.clock) {
				buffer.applyTagByName("clock", startIter, iter);
			}
		}

		post.end = buffer.createMark("end-" ~ post.post.post_id, iter, true);

		TextIter postStartIter = new TextIter();
		buffer.getIterAtMark(postStartIter, post.begin);
		TextIter postEndIter = new TextIter();
		buffer.getIterAtMark(postEndIter, post.end);
		buffer.applyTagByName(post.tribune.tag, postStartIter, postEndIter);

		this.posts[post.begin.getName()] = post;

		if (!this.begin) {
			this.begin = post.begin;
		}

		if (!this.end) {
			this.end = post.end;
		}
	}
}

