module gui.gtkd.infowindow;

import engine.post;

import gui.gtkd.postline;
import gui.gtkd.pinnipede;

import gtk.Window;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextTagTable;
import gtk.VBox;
import gtk.ScrolledWindow;

import gdk.Threads;

import gtkc.gtktypes;

import std.cstream;

class InfoWindow : Window
	{
	private Pinnipede pinnipede;

	private TextView view;

	this (Pinnipede pinnipede)
		{
		super (GtkWindowType.POPUP);

		this.pinnipede = pinnipede;

		this.view = new TextView ();
		view.setBuffer (new TextBuffer (pinnipede.getBuffer ().getTagTable ()));
		view.setWrapMode (WrapMode.WORD);

		ScrolledWindow scroll = new ScrolledWindow (null, null);
		scroll.setPolicy (GtkPolicyType.NEVER, GtkPolicyType.NEVER);
		scroll.setShadowType (GtkShadowType.IN);
		scroll.add (view);

		VBox box = new VBox (true, 5);
		
		this.add (box);
		
		box.packStart (scroll, true, true, 0);
		}

	public void show (PostLine[] lines)
		{
		view.getBuffer ().setText ("");
		foreach (PostLine line ; lines)
			{
			line.render (view.getBuffer ());
			}
		show ();
		}

	public void show (MessageSegment segment)
		{
		if (segment)
			{
			if (segment.context & SegmentContext.MainHorloge)
				{
				char[] text = std.string.format ("id=%s ua=%s\ndate=%s", segment.post.horloge.id,
																		 segment.post.info,
																		 segment.post.horloge.toString ());
				view.getBuffer ().setText (text);
				}
			else if (segment.context & SegmentContext.Link)
				{
				view.getBuffer ().setText (segment.data);
				}
			else
				{
				view.getBuffer ().setText (std.string.format ("Unknown type: %s", segment.context));
				}

			show ();
			}
		}

	public void show ()
		{
		int width, height, depth;

		int rootX, rootY;

		pinnipede.getWindow (GtkTextWindowType.WIDGET).getGeometry (rootX, rootY, width, height, depth);
		pinnipede.getWindow (GtkTextWindowType.WIDGET).getOrigin (rootX, rootY);

		move (rootX, rootY);
		setDefaultSize (width, 1);
		resize (width, 1);

		//setKeepAbove (1);
		super.showAll ();
		}
	}

