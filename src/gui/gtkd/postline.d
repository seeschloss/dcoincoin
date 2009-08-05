module gui.gtkd.postline;

import engine.post;
import gui.gtkd.main;

import std.utf;

import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextTag;
import gtk.TextIter;
import gtk.TextMark;

class PostLine
	{
	private Post _post;

	TextMark begin;
	TextMark end;

	this (Post post)
		{
		this._post = post;
		}

	public Post post ()
		{
		return _post;
		}

	public MessageSegment opIndex (TextIter iter)
		{
		return post[iter.getLineOffset ()];
		}

	public synchronized TextMark render (TextBuffer buffer)
		{
		TextIter iter = new TextIter ();
		buffer.getEndIter (iter);

		if (buffer.getCharCount () > 1)
			{
			buffer.insert (iter, "\n");
			}

		TextMark mark = buffer.createMark (std.string.toString (post.horloge.id), iter, true);

		foreach (int index ; post.segments.keys.sort)
			{
			MessageSegment segment = post.segments[index];

			TextMark startMark = buffer.createMark ("start", iter, true);
			TextMark endMark = buffer.createMark ("start", iter, false);

			buffer.insert (iter, segment.text);

			TextIter startIter = new TextIter ();
			buffer.getIterAtMark (startIter, startMark);

			if (segment.context & SegmentContext.MainHorloge)
				{
				if (post.self)
					{
					buffer.applyTagByName ("self", startIter, iter);
					buffer.applyTagByName ("main_horloge", startIter, iter);
					}
				else
					{
					buffer.applyTagByName ("main_horloge", startIter, iter);
					}
				}

			if (segment.context & SegmentContext.Login)
				{
				buffer.applyTagByName ("login", startIter, iter);
				}

			if (segment.context & SegmentContext.Info)
				{
				buffer.applyTagByName ("info", startIter, iter);
				}

			if (segment.context & SegmentContext.Bold)
				{
				buffer.applyTagByName ("b", startIter, iter);
				}

			if (segment.context & SegmentContext.Italic)
				{
				buffer.applyTagByName ("i", startIter, iter);
				}

			if (segment.context & SegmentContext.Underline)
				{
				buffer.applyTagByName ("u", startIter, iter);
				}

			if (segment.context & SegmentContext.Strike)
				{
				buffer.applyTagByName ("s", startIter, iter);
				}

			if (segment.context & SegmentContext.Link)
				{
				buffer.applyTagByName ("a", startIter, iter);
				}

			if (segment.context & SegmentContext.Horloge)
				{
				buffer.applyTagByName ("horloge", startIter, iter);
				}

			if (segment.context & SegmentContext.Totoz)
				{
				buffer.applyTagByName ("totoz", startIter, iter);
				}
			}

		TextMark endMark = buffer.createMark ("end-" ~ std.string.toString (post.horloge.id), iter, true);

		if (false && post.self)
			{
			TextIter beginIter = new TextIter ();
			TextIter endIter = new TextIter ();

			buffer.getIterAtMark (beginIter, mark);
			buffer.getIterAtMark (endIter,   endMark);

			buffer.applyTagByName ("self", beginIter, endIter);
			}

		if (!this.begin)
			this.begin = mark;

		if (!this.end)
			this.end   = endMark;

		return mark;
		}
	}
