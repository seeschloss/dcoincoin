module dcc.gtkd.tribuneviewer;

private import std.stdio;

private import gtk.TextView;
private import gtk.TextBuffer;
private import gtk.TextIter;
private import gtk.TextMark;
private import gtkc.gtktypes;
private import gdk.Color;

private import dcc.engine.tribune;
private import dcc.gtkd.post;
private import dcc.gtkd.main;

class TribuneViewer : TextView {
	private TextMark begin, end;

	this() {
		this.setEditable(false);
		this.setCursorVisible(false);
		this.setWrapMode(WrapMode.WORD);
		this.setIndent(-10);

		TextBuffer buffer = this.getBuffer();

		buffer.createTag("mainclock", "foreground-gdk", new Color(50, 50, 50));
		buffer.createTag("login", "weight", PangoWeight.BOLD, "foreground-gdk", new Color(0, 0, 100));
		buffer.createTag("clock", "weight", PangoWeight.BOLD, "underline", PangoUnderline.SINGLE, "foreground-gdk", new Color(0, 0, 100));

		buffer.createTag("b", "weight"       , PangoWeight.BOLD);
		buffer.createTag("i", "style"        , PangoStyle.ITALIC);
		buffer.createTag("u", "underline"    , PangoUnderline.SINGLE);
		buffer.createTag("s", "strikethrough", true);

		TextIter iter = new TextIter();
		buffer.getEndIter(iter);
		buffer.createMark("end", iter, false);
	}

	void registerTribune(GtkTribune gtkTribune) {
		gtkTribune.tag = "tribune" ~ gtkTribune.tribune.name;
		this.getBuffer().createTag(gtkTribune.tag, "paragraph-background", gtkTribune.color);
	}

	void scrollToEnd() {
		this.scrollMarkOnscreen(this.getBuffer().getMark("end"));
	}

	void renderPost(GtkPost post) {
		string[] tokens = post.tokenize();
		GtkPostSegment[] segments = post.segmentize();

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

		foreach (GtkPostSegment segment; segments) {
			TextMark startMark = buffer.createMark("start", iter, true);
			TextMark endMark = buffer.createMark("start", iter, false);

			buffer.insert(iter, segment.text);

			TextIter startIter = new TextIter();
			buffer.getIterAtMark(startIter, startMark);

			if (segment.context.bold) {
				buffer.applyTagByName("b", startIter, iter);
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

		if (!this.begin) {
			this.begin = post.begin;
		}

		if (!this.end) {
			this.end = post.end;
		}
	}
}

