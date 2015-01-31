module dcc.gtkd.tribuneviewer;

private import std.stdio;
private import std.signals;
private import std.conv;

private import gtk.TextView;
private import gtk.TextBuffer;
private import gtk.TextIter;
private import gtk.TextMark;
private import gtk.Widget;
private import gtk.Window;

private import gtkc.gtktypes;

private import gdk.Color;
private import gdk.Cursor;
private import gdk.Event;

private import glib.ListSG;

private import gobject.Signals;

private import dcc.engine.tribune;
private import dcc.gtkd.post;
private import dcc.gtkd.main;

class TribuneViewer : TextView {
	private TextMark begin, end;

	public GtkTribune[] tribunes;

	private GtkPost[string] posts;

	private GtkPost[string] highlightedPosts;
	private GtkPostSegment[GtkPostSegment] highlightedPostSegments;

	mixin Signal!(GtkPost) postClockClick;
	mixin Signal!(GtkPost) postLoginClick;
	mixin Signal!(GtkPost, GtkPostSegment) postSegmentClick;

	mixin Signal!(GtkPost) postHover;
	mixin Signal!(GtkPost) postClockHover;
	mixin Signal!(GtkPost) postLoginHover;
	mixin Signal!(GtkPost, GtkPostSegment) postSegmentHover;

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

		buffer.createTag("highlightedpost", "background", "white");

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
				this.postClockClick.emit(post);
			} else {
				GtkPostSegment segment = post.getSegmentAt(offset);
				if (segment && segment.text && segment.text.length) {
					this.postSegmentClick.emit(post, segment);
				} else if (offset > 9 && offset < post.segmentIndices.keys[0] - 1) {
					this.postLoginClick.emit(post);
				}
			}
		}

		return true;
	}

	void unHighlightEverything() {
		foreach (GtkPost post ; this.highlightedPosts.dup) {
			this.unHighlightPost(post);
		}

		foreach (GtkPostSegment segment ; this.highlightedPostSegments.dup) {
			this.unHighlightPostSegment(segment);
		}
	}

	void unHighlightPost(GtkPost post) {
		if (post && post.id in this.highlightedPosts) {
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, post.begin);
			this.getBuffer().getIterAtMark(endIter, post.end);

			this.getBuffer().removeTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPosts.remove(post.id);
		}
	}

	void highlightPost(GtkPost post) {
		if (post && post.id !in this.highlightedPosts) {
			writeln("Post: ", post.id);
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, post.begin);
			this.getBuffer().getIterAtMark(endIter, post.end);

			this.getBuffer().applyTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPosts[post.id] = post;
		}
	}

	void highlightPostSegment(GtkPostSegment segment) {
		if (segment !in this.highlightedPostSegments) {
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, segment.begin);
			this.getBuffer().getIterAtMark(endIter, segment.end);

			this.getBuffer().applyTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPostSegments[segment] = segment;
		}
	}

	void unHighlightPostSegment(GtkPostSegment segment) {
		if (segment in this.highlightedPostSegments) {
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, segment.begin);
			this.getBuffer().getIterAtMark(endIter, segment.end);

			this.getBuffer().removeTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPostSegments.remove(segment);
		}
	}

	void highlightClock(GtkPostSegment segment) {
		this.highlightPostSegment(segment);

		foreach (GtkTribune tribune ; this.tribunes) {
			foreach (GtkPost post; tribune.findPostsByClock(segment)) {
				this.highlightPost(post);

				foreach (GtkPostSegment found_segment; post.tribune.findReferencesToPost(post)) {
					this.highlightPostSegment(found_segment);
				}
			}
		}
	}

	bool onMotion(Event event, Widget viewer) {
		int bufferX, bufferY;

		this.windowToBufferCoords(GtkTextWindowType.WIDGET, cast(int)event.motion().x, cast(int)event.motion().y, bufferX, bufferY);

		TextIter position = new TextIter();
		this.getIterAtLocation(position, bufferX, bufferY);

		GdkCursorType cursor = GdkCursorType.ARROW;
		GtkPost post = this.getPostAtIter(position);

		this.unHighlightEverything();
		if (post) {
			this.postHover.emit(post);

			int offset = position.getLineOffset();
			if (offset <= 8) {
				cursor = GdkCursorType.HAND2;
				this.highlightPost(post);
				this.postClockHover.emit(post);
			} else {
				GtkPostSegment segment = post.getSegmentAt(offset);
				if (segment && segment.text && segment.text.length) {
					if (segment.context.clock != Clock.init) {
						cursor = GdkCursorType.HAND2;
						this.highlightClock(segment);
					}
					this.postSegmentHover.emit(post, segment);
				} else if (offset > 9 && offset < post.segmentIndices.keys[0] - 1) {
					cursor = GdkCursorType.HAND2;
					this.postLoginHover.emit(post);
				}
			}
		}


		this.getWindow(GtkTextWindowType.TEXT).setCursor(new Cursor(cursor));

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
		buffer.getEndIter(iter);

		if (buffer.getCharCount() > 1) {
			buffer.insert(iter, "\n");
		}

		post.begin = buffer.createMark(post.id, iter, true);

		buffer.insertWithTagsByName(iter, post.post.clock, ["mainclock"]);
		buffer.insert(iter, " ");
		if (post.post.login) {
			buffer.insertWithTagsByName(iter, post.post.login, ["login"]);
		} else {
			buffer.insertWithTagsByName(iter, post.post.short_info, ["login"]);
		}
		buffer.insert(iter, " ");

		int postStart = iter.getLineOffset();

		foreach (int i, GtkPostSegment segment; segments) {
			int segmentStart = iter.getLineOffset();
			post.segmentIndices[segmentStart] = segment;

			TextMark startMark = buffer.createMark("start", iter, true);
			TextMark endMark = buffer.createMark("start", iter, false);
			segment.begin = buffer.createMark("start-" ~ post.id ~ ":" ~ to!string(i), iter, true);

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

			if (segment.context.clock != Clock.init) {
				buffer.applyTagByName("clock", startIter, iter);
			}

			segment.end = buffer.createMark("end-" ~ post.id ~ ":" ~ to!string(i), iter, true);
		}

		post.end = buffer.createMark("end-" ~ post.id, iter, true);

		TextIter postStartIter = new TextIter();
		buffer.getIterAtMark(postStartIter, post.begin);
		TextIter postEndIter = new TextIter();
		buffer.getIterAtMark(postEndIter, post.end);
		buffer.applyTagByName(post.tribune.tag, postStartIter, postEndIter);

		this.posts[post.id] = post;

		if (!this.begin) {
			this.begin = post.begin;
		}

		if (!this.end) {
			this.end = post.end;
		}
	}
}

