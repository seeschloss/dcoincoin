module gui.gtkd.pinnipede;

import engine.post;
import engine.tribune;

import gui.gtkd.postline;
import gui.gtkd.infowindow;

import gtk.TextView;
import gtk.TextIter;
import gtk.TextMark;
import gtk.TextTag;
import gtk.TextTagTable;
import gtk.Widget;

import gtkc.gtktypes;

import gdk.Cursor;
import gdk.Event;

import glib.ListSG;

import std.cstream;

class Pinnipede : TextView
	{
	private Tribune tribune;

	private MessageSegment _last_hover;
	private char[][PostLine] _highlighted_posts;
	private char[][MessageSegment][PostLine] _highlighted_segments;

	private InfoWindow _info;

	private PostLine[char[]] _posts;

	private void delegate (MessageSegment segment)[] _on_segment_click;
	private void delegate (MessageSegment segment)[] _on_segment_hover;

	private bool last_event_is_move = false;

	this (Tribune tribune)
		{
		this.tribune = tribune;

		super ();

		_info = new InfoWindow (this);

		setEditable (false);
		setCursorVisible (false);
		setWrapMode (WrapMode.WORD);

		addOnButtonRelease (&on_click);
		addOnMotionNotify (&on_hover);
		addOnSizeAllocate (&on_resize);

		setIndent (-10);
		}

	public void add_on_segment_click (void delegate (MessageSegment segment) dg)
		{
		_on_segment_click ~= dg;
		}

	public void add_on_segment_hover (void delegate (MessageSegment segment) dg)
		{
		_on_segment_hover ~= dg;
		}

	public int height = -1;

	public bool at_bottom()
		{
		return true;
		}

	public GtkWidget* gtkHandle()
		{
		return gtkWidget;
		}

	private int on_enter (GdkEventCrossing* event, Widget pinnipede)
		{
		dout.writefln ("Entered.");

		return 0;
		}

	private bool on_click (GdkEventButton* event, Widget pinnipede)
		{
		int bufferX;
		int bufferY;

		windowToBufferCoords (GtkTextWindowType.WIDGET, cast(int)event.x, cast(int)event.y, bufferX, bufferY);

		TextIter position = new TextIter ();

		getIterAtLocation (position, bufferX, bufferY);

		TextTagTable table = getBuffer ().getTagTable ();

		TextTag main_horloge = table.tableLookup ("main_horloge");
		TextTag horloge = table.tableLookup ("horloge");
		TextTag link = table.tableLookup ("a");
		TextTag totoz = table.tableLookup ("totoz");

		PostLine line = getMessageAtIter (position);
		MessageSegment segment = null;

		if (line)
			{
			segment = line[position];
			}

		if (segment)
			{
			foreach (void delegate (MessageSegment segment) dg ; _on_segment_click)
				{
				dg (segment);
				}

			if (SegmentContext.Horloge in segment)
				{
				foreach (int id, PostLine line2 ; find_posts (segment.data))
					{
					scrollToMark (line2.end, 0, 1, 0.00, 1.00);
					}
				}
			}

		return 0;
		}

	private bool on_hover (GdkEventMotion* event, Widget pinnipede)
		{
		last_event_is_move = true;
		int bufferX;
		int bufferY;

		windowToBufferCoords (GtkTextWindowType.WIDGET, cast(int)event.x, cast(int)event.y, bufferX, bufferY);

		TextIter position = new TextIter ();

		getIterAtLocation (position, bufferX, bufferY);

		TextTagTable table = getBuffer ().getTagTable ();

		TextTag main_horloge = table.tableLookup ("main_horloge");
		TextTag horloge = table.tableLookup ("horloge");
		TextTag link = table.tableLookup ("a");
		TextTag totoz = table.tableLookup ("totoz");

		PostLine line = getMessageAtIter (position);
		MessageSegment segment = null;

		if (line)
			{
			segment = line[position];
			}

		if (!segment || segment != _last_hover)
			{
			unhighlight_all ();
			}

		_last_hover = segment;

		if (main_horloge && position.hasTag (main_horloge))
			{
			if (!segment)
				{
				dout.writefln ("[:uxam]");
				}

			show_info (segment);

			PostLine[int] posts;
			posts[line.post.horloge.id] = line;
			highlight_main_posts (posts);
			setCursor (new Cursor (GdkCursorType.HAND1));
			}
		else if (horloge && position.hasTag (horloge))
			{
			if (segment && segment.context & SegmentContext.Horloge)
				{
				PostLine[int] posts = find_posts (segment.data);

				if (posts.length)
					{
					show_info (posts.values);

					highlight_main_posts (posts);
					}
				else
					{
					highlight_segment (line, segment, "highlighted_wrong_clock");
					}

				setCursor (new Cursor (GdkCursorType.HAND1));
				}
			}
		else if (link && position.hasTag (link))
			{
			if (segment && segment.context & SegmentContext.Link)
				{
				show_info (segment);

				setCursor (new Cursor (GdkCursorType.HAND1));
				}
			}
		else if (totoz && position.hasTag (totoz))
			{
			if (segment && segment.context & SegmentContext.Totoz)
				{
				show_info (segment);

				setCursor (new Cursor (GdkCursorType.FLEUR));
				}
			}
		else
			{
			setCursor (new Cursor (GdkCursorType.ARROW));
			}

		return 0;
		}

	private synchronized void highlight_main_post (PostLine main_line)
		{
		highlight_post (main_line, "highlighted_main_post");

		foreach (PostLine line, MessageSegment[int] clocks ; find_clocks_to (main_line))
			{
			foreach (int index, MessageSegment clock ; clocks)
				{
				highlight_segment (line, clock, "highlighted_post");
				}
			}
		}

	private synchronized void highlight_main_posts (PostLine[int] lines)
		{
		foreach (int id, PostLine main_line ; lines)
			{
			highlight_post (main_line, "highlighted_main_post");

			foreach (PostLine line, MessageSegment[int] clocks ; find_clocks_to (main_line))
				{
				foreach (int index, MessageSegment clock ; clocks)
					{
					highlight_segment (line, clock, "highlighted_post");
					}
				}
			}
		}

	private synchronized void highlight_segment (PostLine line, MessageSegment segment, char[] tag = "highlighted_post")
		{
		if (!(line in _highlighted_segments) || !(segment in _highlighted_segments[line]))
			{
			TextIter beginIter = new TextIter ();
			TextIter endIter = new TextIter ();

			getBuffer ().getIterAtMark (beginIter, line.begin);
			getBuffer ().getIterAtMark (endIter,   line.begin);

			beginIter.forwardChars (segment.index);
			endIter.forwardChars   (segment.index + segment.length);

			getBuffer ().applyTagByName (tag, beginIter, endIter);

			_highlighted_segments[line][segment] = tag;
			}
		}


	private void highlight_post (PostLine line, char[] tag = "highlighted_post")
		{
		if (!(line in _highlighted_posts))
			{
			TextIter beginIter = new TextIter ();
			TextIter endIter = new TextIter ();

			getBuffer ().getIterAtMark (beginIter, line.begin);
			getBuffer ().getIterAtMark (endIter, line.end);

			getBuffer ().applyTagByName (tag, beginIter, endIter);
			_highlighted_posts[line] = tag;
			}
		}

	private synchronized void unhighlight_all ()
		{
		unhighlight_posts ();
		unhighlight_segments ();
		}

	private synchronized void unhighlight_posts ()
		{
		reset_info();
		foreach (PostLine line, char[] tag ; _highlighted_posts)
			{
			unhighlight_post (line, tag);
			}
		}

	private synchronized void unhighlight_segments ()
		{
		foreach (PostLine line, char[][MessageSegment] segments ; _highlighted_segments)
			{
			foreach (MessageSegment segment, char[] tag ; segments)
				{
				unhighlight_segment (line, segment, tag);
				}
			}
		}

	private synchronized void unhighlight_segment (PostLine line, MessageSegment segment, char[] tag = "highlighted_post")
		{
		if (line in _highlighted_segments && segment in _highlighted_segments[line])
			{
			TextIter beginIter = new TextIter ();
			TextIter endIter = new TextIter ();

			getBuffer ().getIterAtMark (beginIter, line.begin);
			getBuffer ().getIterAtMark (endIter,   line.begin);

			beginIter.forwardChars (segment.index);
			endIter.forwardChars   (segment.index + segment.length);

			getBuffer ().removeTagByName (tag, beginIter, endIter);

			_highlighted_segments[line].remove (segment);
			}
		}

	private synchronized void unhighlight_post (PostLine line, char[] tag = "highlighted_post")
		{
		if (line in _highlighted_posts)
			{
			TextIter beginIter = new TextIter ();
			TextIter endIter = new TextIter ();

			getBuffer ().getIterAtMark (beginIter, line.begin);
			getBuffer ().getIterAtMark (endIter, line.end);

			getBuffer ().removeTagByName (tag, beginIter, endIter);
			_highlighted_posts.remove (line);
			}
		}

	private void on_resize (GtkAllocation* event, Widget pinnipede)
		{
		reset_info ();
		}

	private void show_info (MessageSegment segment)
		{
		_info.show (segment);
		}

	private void show_info (PostLine[] lines)
		{
		_info.show (lines);
		}

	private void reset_info ()
		{
		_info.hide ();
		}

	public TextMark append_post (Post post)
		{
		PostLine line = new PostLine (post);
		TextMark mark = line.render (getBuffer ());
		_posts[mark.getName ()] = line;

		TextIter endIter = new TextIter ();
		getBuffer ().getEndIter (endIter);
		endIter.backwardChars (80);

		TextMark a = getBuffer ().createMark ("tmp", endIter, true);

		if (moveMarkOnscreen (a))
			{
			scrollMarkOnscreen (getBuffer ().getMark ("end"));
			}

		getBuffer ().deleteMark (a);

		return mark;
		}

	public synchronized PostLine getMessageAtIter (TextIter position)
		{
		TextIter iter = new TextIter ();

		getBuffer ().getIterAtLine (iter, position.getLine ());

		ListSG marks = iter.getMarks ();

		for (int i = 0 ; i < marks.length () ; i++)
			{
			TextMark mark = new TextMark (cast (GtkTextMark*) marks.nthData (i));

			if (mark.getName () in _posts)
				{
				return _posts[mark.getName ()];
				}
			}

		return null;
		}

	public PostLine[int] find_posts (char[] horloge)
		{
		PostLine[int] posts;

		foreach (int id ; tribune.find_posts (horloge).keys.sort)
			{
			posts[id] = _posts[std.string.toString (id)];
			}

		return posts;
		}

	public PostLine[int] find_posts_to (PostLine line)
		{
		PostLine[int] lines;

		foreach (int id ; line.post.referencing_posts.keys.sort)
			{
			lines[id] = _posts[std.string.toString (id)];
			}

		return lines;
		}

	public MessageSegment[int][PostLine] find_clocks_to (PostLine line)
		{
		MessageSegment[int][PostLine] clocks_to;

		foreach (Post post, MessageSegment[int] clocks ; line.post.referencing_clocks)
			{
			PostLine line = _posts[std.string.toString (post.horloge.id)];
			clocks_to[line] = clocks;
			}

		return clocks_to;
		}

	}
