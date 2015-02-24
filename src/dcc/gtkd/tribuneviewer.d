module dcc.gtkd.tribuneviewer;

private import gtkc.gtk;

private import std.stdio;
private import std.signals;
private import std.conv;
private import std.string : format;
private import std.algorithm;
private import std.datetime : SysTime;

private import gtk.TextView;
private import gtk.TextBuffer;
private import gtk.TextIter;
private import gtk.TextMark;
private import gtk.Widget;
private import gtk.Window;
private import gtk.CssProvider;

private import gtkc.gtktypes;
private import gtkc.gdk;

private import gdk.Color;
private import gdk.Cursor;
private import gdk.Event;
private import gdk.Cairo;
private import gdk.Rectangle;

private import glib.ListSG;

private import cairo.Context;

private import gobject.Signals;

private import dcc.engine.tribune;
private import dcc.gtkd.post;
private import dcc.gtkd.main;

class TribunePreviewer : TribuneViewer {
	this() {
		super();

		this.getBuffer().createTag("status", "paragraph-background", "lightgrey");
		this.getBuffer().createTag("light", "foreground", "grey", "weight", PangoWeight.NORMAL);

		this.setValign(GtkAlign.START);
		this.setBorderWindowSize(GtkTextWindowType.BOTTOM, 2);
		this.setBorderWindowSize(GtkTextWindowType.LEFT, 2);
		this.setBorderWindowSize(GtkTextWindowType.RIGHT, 2);

		this.setIndent(-12);

		this.hide();

		this.setName("TribunePreview");
		auto css = new CssProvider();
		this.getStyleContext().addProvider(css, 600);
		css.loadFromData(`
			#TribunePreview {
				background-color: #EEEEEE;
			}
		`);

		Signals.connectData(
			this.getStruct(),
			"draw",
			cast(GCallback)&this.onDrawCallback,
			cast(void*)this,
			null,
			cast(ConnectFlags)0);
	}

	private void reset(T)(T p) {
		p = T.init;
	}

	void empty() {
		this.reset(this.posts);
		this.reset(this.postBegins);
		this.reset(this.postEnds);
		this.reset(this.segmentBegins);
		this.reset(this.segmentEnds);
		this.reset(this.postSegmentsOffsets);
		this.getBuffer().setText("");
	}

	override void renderPost(GtkPost post) {
		this.empty();

		this.setLeftMargin(0);
		this.setRightMargin(0);

		super.renderPost(post);
	}

	void showUrl(string url) {
		this.empty();

		this.setLeftMargin(5);
		this.setRightMargin(5);

		TextIter iter = new TextIter();
		auto buffer = this.getBuffer();
		buffer.getStartIter(iter);

		buffer.insert(iter, url);
	}

	void postInfo(GtkPost post) {
		this.empty();

		this.setLeftMargin(5);
		this.setRightMargin(5);

		TextIter iter = new TextIter();
		auto buffer = this.getBuffer();
		buffer.getStartIter(iter);

		buffer.insertWithTagsByName(iter, "#", ["light"]);
		buffer.insertWithTagsByName(iter, format("%s", post.post.post_id), ["b"]);

		buffer.insertWithTagsByName(iter, "   @", ["light"]);
		buffer.insertWithTagsByName(iter, format("%s", post.post.tribune.name), ["b"]);

		buffer.insertWithTagsByName(iter, "   " ~ post.post.unicodeClock, ["light"]);
		buffer.insertWithTagsByName(iter,
			format("%04d-%02d-%02d %02d:%02d:%02d",
				post.post.time.year,
				post.post.time.month,
				post.post.time.day,
				post.post.time.hour,
				post.post.time.minute,
				post.post.time.second)
			, ["b"]);

		buffer.insert(iter, "\n");

		buffer.insert(iter, "User-Agent:");
		buffer.insertWithTagsByName(iter, format(" %s", post.post.info), ["i"]);

		buffer.insert(iter, "\n");
		if (post.post.login.length > 0) {
			buffer.insert(iter, "Login: ");
			buffer.insertWithTagsByName(iter, format("%s", post.post.login), ["b"]);
		} else {
			buffer.insertWithTagsByName(iter, "(anonymous)", ["i"]);
		}
	}

	bool onDraw() {
		auto context = this.getWindow(GtkTextWindowType.WIDGET).createContext();
		context.setLineWidth(8);

		Rectangle visible;
		this.getVisibleRect(visible);

		context.setSourceRgb(0, 0, 0);
		context.moveTo(visible.x, visible.y);
		context.lineTo(visible.x, visible.y + visible.height);
		context.lineTo(visible.x + visible.width, visible.y + visible.height);
		context.lineTo(visible.x + visible.width, visible.y);
		context.stroke();

		delete context;
	
		return false;
	}

	extern(C) static gboolean onDrawCallback(GtkWidget* widgetStruct, CairoContext* cr, Widget _widget) {
		return (cast(TribunePreviewer)_widget).onDraw();
	}
}

class TribuneMainViewer : TribuneViewer {
	private GtkPost[string] highlightedPosts;
	private GtkPostSegment[GtkPostSegment] highlightedPostSegments;

	mixin Signal!(GtkPost) postClockClick;
	mixin Signal!(GtkPost) postLoginClick;
	mixin Signal!(GtkPost, GtkPostSegment) postSegmentClick;

	mixin Signal!(GtkPost) postHover;
	mixin Signal!(GtkPost) postClockHover;
	mixin Signal!(GtkPost) postLoginHover;
	mixin Signal!(GtkPost, GtkPostSegment) postSegmentHover;

	mixin Signal!(GtkPost) postHighlight;
	mixin Signal!() resetHighlight;

	Context marginContext;

	bool onDraw() {
		// Draw coloured lines in the left margin to indicate post ownership
		auto window = this.getWindow(GtkTextWindowType.WIDGET);

		//auto context = this.getWindow(GtkTextWindowType.WIDGET).createContext();

		auto p = gdk_cairo_create(window.getWindowStruct());
		auto context = new Context(p);

		context.setLineWidth(2);

		//writeln("Path: ", this.getPath());


		Rectangle visible;
		this.getVisibleRect(visible);

		TextIter startIter = new TextIter();
		TextIter stopIter = new TextIter();
		Rectangle startLocation, stopLocation;
		int startY, endY, lineHeight;
		TextBuffer buffer = this.getBuffer();

		auto scrollHeight = this.getVadjustment().getValue();

		int i = 0;
		foreach (string post_id, GtkPost post; this.posts) {
			buffer.getIterAtMark(startIter, this.postBegins[post]);

			this.getLineYrange(startIter, startY, lineHeight);

			if (startY < visible.y || startY > visible.y + visible.height) {
				continue;
			}

			if (post.post.mine) {
				context.setSourceRgb(0.5, 0.2, 0.2);
			} else if (post.answer) {
				context.setSourceRgb(1, 0.2, 0.2);
			} else {
				if (post.tribune !in this.tribuneColors) {
					Color color = new Color();
					Color.parse(post.tribune.color, color);
					this.tribuneColors[post.tribune] = color;
				}

				context.setSourceRgb(
					cast(double)this.tribuneColors[post.tribune].red/ushort.max,
					cast(double)this.tribuneColors[post.tribune].green/ushort.max,
					cast(double)this.tribuneColors[post.tribune].blue/ushort.max,
				);
			}

			buffer.getIterAtMark(stopIter, this.postEnds[post]);
			this.getLineYrange(stopIter, endY, lineHeight);

			context.moveTo(1, startY - scrollHeight);
			context.lineTo(1, endY + lineHeight - scrollHeight);
			context.stroke();
		}

		delete context;
	
		return false;
	}

	extern(C) static gboolean onDrawCallback(GtkWidget* widgetStruct, CairoContext* cr, Widget _widget) {
		return (cast(TribuneMainViewer)_widget).onDraw();
	}

	this() {
		super();

		this.setIndent(-12);

		this.getBuffer().createTag("highlightedpost", "background", "white");

		this.addOnButtonRelease(&this.onClick);
		this.addOnMotionNotify(&this.onMotion);

		this.setBorderWindowSize(GtkTextWindowType.LEFT, 2);

		Signals.connectData(
			this.getStruct(),
			"draw",
			cast(GCallback)&this.onDrawCallback,
			cast(void*)this,
			null,
			cast(ConnectFlags)0);
	}

	bool onClick(Event event, Widget viewer) {
		int bufferX, bufferY;

		auto adjustment = this.getVadjustment();

		this.windowToBufferCoords(GtkTextWindowType.WIDGET, cast(int)event.motion().x, cast(int)event.motion().y, bufferX, bufferY);

		TextIter position = new TextIter();
		this.getIterAtLocation(position, bufferX, bufferY);

		GtkPost post = this.getPostAtIter(position);
		if (post) {
			int offset = position.getLineOffset();
			if (offset <= 8) {
				this.postClockClick.emit(post);
			} else {
				GtkPostSegment segment = post.getSegmentAt(offset - this.postSegmentsOffsets[post]);
				if (segment && segment.text && segment.text.length) {
					this.postSegmentClick.emit(post, segment);
					if (segment.context.clock != Clock.init) {
						foreach (GtkPost found_post; this.findPostsByClock(segment)) {
							this.scrollToPost(found_post);
						}
					}
				} else if (offset > 9 && offset < this.postSegmentsOffsets[post]) {
					this.postLoginClick.emit(post);
				}
			}
		}

		return false;
	}

	void unHighlightEverything() {
		this.resetHighlight.emit();

		foreach (GtkPost post ; this.highlightedPosts.dup) {
			this.unHighlightPost(post);
		}

		foreach (GtkPostSegment segment ; this.highlightedPostSegments.dup) {
			this.unHighlightPostSegment(segment);
		}
	}

	void unHighlightPost(GtkPost post) {
		if (post && post.id in this.highlightedPosts && post in this.postBegins && post in this.postEnds) {
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, this.postBegins[post]);
			this.getBuffer().getIterAtMark(endIter, this.postEnds[post]);

			this.getBuffer().removeTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPosts.remove(post.id);
		}
	}

	void highlightPost(GtkPost post) {
		if (post && post.id !in this.highlightedPosts && post in this.postBegins && post in this.postEnds) {
			this.postHighlight.emit(post);

			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, this.postBegins[post]);
			this.getBuffer().getIterAtMark(endIter, this.postEnds[post]);
			this.getBuffer().applyTagByName("highlightedpost", beginIter, endIter);

			this.highlightedPosts[post.id] = post;

			this.highlightPostAnswers(post);
		}
	}

	void highlightPostAnswers(GtkPost post) {
		if (post in this.postBegins) {
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, this.postBegins[post]);
			this.getBuffer().getIterAtMark(endIter, this.postBegins[post]);
			endIter.setLineOffset(10);

			this.getBuffer().applyTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPosts[post.id] = post;

			foreach (GtkPostSegment found_segment; this.findReferencesToPost(post)) {
				this.highlightPostSegment(found_segment);
			}
		}
	}

	void highlightPostSegment(GtkPostSegment segment) {
		if (segment !in this.highlightedPostSegments && segment in this.segmentBegins && segment in this.segmentEnds) {
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, this.segmentBegins[segment]);
			this.getBuffer().getIterAtMark(endIter, this.segmentEnds[segment]);

			this.getBuffer().applyTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPostSegments[segment] = segment;
		}
	}

	void unHighlightPostSegment(GtkPostSegment segment) {
		if (segment in this.highlightedPostSegments && segment in this.segmentBegins && segment in this.segmentEnds) {
			TextIter beginIter = new TextIter();
			TextIter endIter = new TextIter();

			this.getBuffer().getIterAtMark(beginIter, this.segmentBegins[segment]);
			this.getBuffer().getIterAtMark(endIter, this.segmentEnds[segment]);

			this.getBuffer().removeTagByName("highlightedpost", beginIter, endIter);
			this.highlightedPostSegments.remove(segment);
		}
	}

	void highlightClock(GtkPostSegment segment) {
		this.highlightPostSegment(segment);

		foreach (GtkPost post; this.findPostsByClock(segment)) {
			this.highlightPost(post);
		}
	}

	Cursor[GdkCursorType] cursors;
	GdkCursorType currentCursor;

	GtkPost currentPostHover;
	GtkPost currentLoginHover, currentClockHover;
	GtkPostSegment currentSegmentHover;

	bool onMotion(Event event, Widget viewer) {
		int bufferX, bufferY;

		this.windowToBufferCoords(GtkTextWindowType.WIDGET, cast(int)event.motion().x, cast(int)event.motion().y, bufferX, bufferY);

		TextIter position = new TextIter();
		this.getIterAtLocation(position, bufferX, bufferY);

		GdkCursorType cursor = GdkCursorType.ARROW;
		GtkPost post = this.getPostAtIter(position);
		if (post != this.currentPostHover) {
			this.postHover.emit(post);

			this.currentPostHover = post;

			this.currentClockHover = null;
			this.currentLoginHover = null;
			this.currentSegmentHover = null;

			this.unHighlightEverything();
		}
		if (post) {
			int offset = position.getLineOffset();
			if (offset <= 8) {
				cursor = GdkCursorType.HAND2;
				if (post != this.currentClockHover) {
					this.unHighlightEverything();
					this.highlightPostAnswers(post);
					this.postClockHover.emit(post);

					this.currentClockHover = post;
					this.currentLoginHover = null;
					this.currentSegmentHover = null;
				}
			} else {
				GtkPostSegment segment = post.getSegmentAt(offset - this.postSegmentsOffsets[post]);
				if (segment && segment.text && segment.text.length) {
					if (segment != this.currentSegmentHover) {
						this.unHighlightEverything();
						if (segment.context.clock != Clock.init) {
							this.highlightClock(segment);
						}
						this.postSegmentHover.emit(post, segment);

						this.currentClockHover = null;
						this.currentLoginHover = null;
						this.currentSegmentHover = segment;
					} else if (segment.context.clock != Clock.init || segment.context.link) {
						cursor = GdkCursorType.HAND2;
					}
				} else if (offset > 9 && offset < this.postSegmentsOffsets[post]) {
					cursor = GdkCursorType.HAND2;
					if (post != this.currentPostHover) {
						this.postLoginHover.emit(post);

						this.currentLoginHover = post;
						this.currentClockHover = null;
						this.currentSegmentHover = null;
					}
				}
			}
		}

		if (cursor !in this.cursors) {
			this.cursors[cursor] = new Cursor(cursor);
		}

		if (cursor != this.currentCursor) {
			this.getWindow(GtkTextWindowType.TEXT).setCursor(this.cursors[cursor]);
		}

		return false;
	}
}

class TribuneViewer : TextView {
	private TextMark begin, end;

	public GtkTribune[] tribunes;

	private GtkPost[string] posts;
	private GtkPost[][SysTime] timestamps;


	Color[GtkTribune] tribuneColors;

	this() {
		this.setEditable(false);
		this.setCursorVisible(false);
		this.setWrapMode(WrapMode.WORD);

		TextBuffer buffer = this.getBuffer();

		buffer.createTag("mainclock", "foreground-gdk", new Color(50, 50, 50));

		buffer.createTag("login", "weight", PangoWeight.BOLD , "foreground-gdk", new Color(0, 0, 100));
		buffer.createTag("info",  "style" , PangoStyle.ITALIC, "foreground-gdk", new Color(0, 0, 100));

		buffer.createTag("clock", "weight", PangoWeight.BOLD , "foreground-gdk", new Color(0, 0, 100));

		buffer.createTag("a", "weight"       , PangoWeight.BOLD,
		                      "underline"    , PangoUnderline.SINGLE,
		                      "foreground-gdk", new Color(0, 0, 100));

		buffer.createTag("b", "weight"       , PangoWeight.BOLD);
		buffer.createTag("i", "style"        , PangoStyle.ITALIC);
		buffer.createTag("u", "underline"    , PangoUnderline.SINGLE);
		buffer.createTag("s", "strikethrough", 1);

		TextIter iter = new TextIter();
		buffer.getEndIter(iter);
		buffer.createMark("end", iter, false);
	}

	void scrollToPost(GtkPost post) {
		if (post in this.postEnds) {
			this.scrollToMark(this.postEnds[post], 0, 1, 0, 1);
		}
	}

	GtkPost[] findPostsByClock(GtkPostSegment segment) {
		GtkPost[] posts;

		foreach (GtkTribune tribune ; this.tribunes) {
			if (tribune.tribune.matches_name(segment.context.clock.tribune)) {
				posts ~= tribune.findPostsByClock(segment);
			}
		}

		return posts;
	}

	GtkPostSegment[] findReferencesToPost(GtkPost post) {
		GtkPostSegment[] segments;

		foreach (GtkTribune tribune ; this.tribunes) {
			segments ~= tribune.findReferencesToPost(post);
		}

		return segments;
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

	bool isScrolledDown() {
		auto adjustment = this.getVadjustment();
		return (adjustment.getValue() >= (adjustment.getUpper() - adjustment.getPageSize()) - 120)
			|| (adjustment.getPageSize() <= adjustment.getUpper());
	}

	TextIter getIterForTime(SysTime insert_time) {
		TextIter iter = new TextIter();
		TextBuffer buffer = this.getBuffer();

		auto times = this.timestamps.keys;
		times.sort!((a, b) => a < b);

		foreach (SysTime time ; times) {
			if (time > insert_time) {
				GtkPost post = this.timestamps[time][0];
				buffer.getIterAtMark(iter, this.postBegins[post]);
				iter.backwardChar();
				return iter;
			}
		}

		buffer.getEndIter(iter);
		return iter;
	}

	TextMark[GtkPost] postBegins;
	TextMark[GtkPost] postEnds;
	TextMark[GtkPostSegment] segmentBegins;
	TextMark[GtkPostSegment] segmentEnds;
	int[GtkPost] postSegmentsOffsets;

	void renderPost(GtkPost post) {
		GtkPostSegment[] segments = post.segments();

		TextBuffer buffer = this.getBuffer();
		TextIter iter = this.getIterForTime(post.post.real_time);

		if (buffer.getCharCount() > 1) {
			buffer.insert(iter, "\n");
		}

		this.postBegins[post] = buffer.createMark(post.id, iter, true);

		buffer.insert(iter, " ");
		buffer.insertWithTagsByName(iter, post.post.clock, ["mainclock"]);
		buffer.insert(iter, " ");
		if (post.post.login) {
			buffer.insertWithTagsByName(iter, post.post.login, ["login"]);
		} else if (post.post.short_info.length > 0) {
			buffer.insertWithTagsByName(iter, post.post.short_info, ["info"]);
		} else {
			buffer.insertWithTagsByName(iter, " ", ["info"]);
		}
		buffer.insert(iter, " ");

		this.postSegmentsOffsets[post] = iter.getLineOffset();

		foreach (int i, GtkPostSegment segment; segments) {
			TextMark startMark = buffer.createMark("start", iter, true);
			TextMark endMark = buffer.createMark("start", iter, false);
			this.segmentBegins[segment] = buffer.createMark("start-" ~ post.id ~ ":" ~ to!string(i), iter, true);

			buffer.insert(iter, segment.text);

			TextIter startIter = new TextIter();
			buffer.getIterAtMark(startIter, startMark);

			if (segment.context.link) {
				buffer.applyTagByName("a", startIter, iter);
			}

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

			this.segmentEnds[segment] = buffer.createMark("end-" ~ post.id ~ ":" ~ to!string(i), iter, true);
		}

		this.postEnds[post] = buffer.createMark("end-" ~ post.id, iter, true);

		TextIter postStartIter = new TextIter();
		buffer.getIterAtMark(postStartIter, this.postBegins[post]);
		TextIter postEndIter = new TextIter();
		buffer.getIterAtMark(postEndIter, this.postEnds[post]);
		buffer.applyTagByName(post.tribune.tag, postStartIter, postEndIter);

		this.posts[post.id] = post;
		this.timestamps[post.post.real_time] ~= post;

		if (!this.begin) {
			this.begin = this.postBegins[post];
		}

		if (!this.end) {
			this.end = this.postEnds[post];
		}
	}
}

