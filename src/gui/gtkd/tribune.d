module gui.gtkd.tribune;

import common;

import engine.tribune;
import engine.post;

import gui.gtkd.main;
import gui.gtkd.threads;
import gui.gtkd.pinnipede;
import gui.gtkd.palmipede;
import gui.gtkd.postline;

import gtk.HBox, gtk.HButtonBox;
import gtk.Button;
import gtk.VBox;
import gtk.Label;
import gtk.TextBuffer, gtk.TextTag, gtk.TextIter, gtk.TextMark;
import gtk.Frame;
import gtk.ScrolledWindow;
import gtk.Widget;
import gtk.RcStyle;
import gtk.ProgressBar;
import gtk.Window;

import gtkc.gtktypes;
import gtkc.gdktypes;
import gtkc.pangotypes;

import gdk.Threads;
import gdk.Keymap;
import gdk.Color;

import gobject.ObjectG;
import gobject.Value;

import glib.ListSG;

import std.cstream;
import std.boxer;
import std.c.time;
import std.date;
import std.random;
import std.utf;

class TribuneTab : VBox
	{
	private Tribune _tribune;
	private Pinnipede _pinnipede;
	private TextBuffer _buffer;
	private Palmipede _palmipede;
	private TimerThread _thread;

	private Button _reloadButton;
	private Button _boldButton;
	private Button _italicButton;
	private Button _underlinedButton;
	private Button _strikedButton;
	private Button _momentButton;

	private ProgressBar _progress;
	private Label _nbCharacters;
	private Label _timeSinceLastPost;

	private long _last_post_time = 0;

	private CoinCoin _main;

	public Pinnipede pinnipede ()
		{
		return _pinnipede;
		}

	this (Tribune tribune, CoinCoin coincoin)
		{
		_tribune = tribune;
		_main    = coincoin;

		super (false, 5);

		_tribune.on_new_post_add (&on_new_post);

		init_interface ();

		_thread = new TimerThread (&update, &set_progress_percent);
		_thread.start ();
		}

	public void update ()
		{
		_tribune.update ();
		}

	private void init_interface ()
		{
		char[] style = `style "buttons"
		                  {
		                  GtkButtonBox::child-min-width=0
		                  GtkButtonBox::child-min-height=0
		                  }
		                class "GtkButtonBox" style "buttons"`;
		RcStyle.parseString (style);

		_pinnipede = new Pinnipede (_tribune);
		_palmipede = new Palmipede ();

		_pinnipede.add_on_segment_click (&on_segment_clicked);

		init_styles ();

		ScrolledWindow palmipedeWindow = new ScrolledWindow (null, null);
		palmipedeWindow.setPolicy (GtkPolicyType.NEVER, GtkPolicyType.NEVER);
		palmipedeWindow.setShadowType (GtkShadowType.IN);
		palmipedeWindow.add (_palmipede);

		ScrolledWindow pinnipedeWindow = new ScrolledWindow (null, null);
		pinnipedeWindow.setPolicy (GtkPolicyType.NEVER, GtkPolicyType.ALWAYS);
		pinnipedeWindow.setShadowType (GtkShadowType.IN);
		pinnipedeWindow.add (_pinnipede);

		packStart (pinnipedeWindow, true, true, 0);
		packStart (init_buttons (), false, false, 2);
		packStart (palmipedeWindow, false, false, 2);

		_palmipede.addOnKeyPress (&on_palmipede_insert);
		}

	private HBox init_buttons ()
		{
		HBox controlHBox = new HBox (false, 2);
		HButtonBox buttonsBox = new HButtonBox ();

		_reloadButton		= new Button ("R");
		_italicButton		= new Button ("i");
		_boldButton			= new Button ("b");
		_underlinedButton	= new Button ("u");
		_strikedButton		= new Button ("s");
		_momentButton		= new Button ("m");

		_momentButton.setSizeRequest (0, 0);

		_reloadButton.addOnClicked		(&on_controls_click);
		_italicButton.addOnClicked		(&on_controls_click);
		_boldButton.addOnClicked		(&on_controls_click);
		_underlinedButton.addOnClicked	(&on_controls_click);
		_strikedButton.addOnClicked		(&on_controls_click);
		_momentButton.addOnClicked		(&on_controls_click);

		_reloadButton.setTooltip 	("Reload backend", "");
		_italicButton.setTooltip	("Italic text", "");
		_boldButton.setTooltip		("Bold text", "");
		_underlinedButton.setTooltip("Underlined text", "");
		_strikedButton.setTooltip	("Striked text", "");
		_momentButton.setTooltip	("Moment", "");

		buttonsBox.add (_italicButton);
		buttonsBox.add (_boldButton);
		buttonsBox.add (_underlinedButton);
		buttonsBox.add (_strikedButton);
		buttonsBox.add (_momentButton);
		buttonsBox.add (_reloadButton);

		controlHBox.add (buttonsBox);

		_progress = new ProgressBar ();
		VBox progressBox = new VBox (false, 1);
		progressBox.add (_progress);

		_progress.setSizeRequest (-1, 3);

		_timeSinceLastPost = new Label ("∞");
		_nbCharacters = new Label ("0");

		HBox infoHBox = new HBox (false, 2);
		infoHBox.add (_nbCharacters);
		infoHBox.add (_timeSinceLastPost);

		progressBox.add (infoHBox);
		controlHBox.add (progressBox);

		return controlHBox;
		}


	struct TagColour {int rgb;}

	private TextTag createTag (TextBuffer buffer, char[] name, Box[char[]] properties)
		{
		class ColourWrapperBecauseGTKdSucks : Color
			{
			public this (TagColour colour)
				{
				super (colour.rgb);
				}

			public GdkColor* gdkHandle()
				{ // the fucking thing is "protected" in the Color class
				return gdkColor;
				}
			}

		TextTag tag = new TextTag (name);

		foreach (char[] property, Box value ; properties)
			{
			if (unboxable!(TagColour)(value))
				{ // please don't look at this
				ColourWrapperBecauseGTKdSucks c = new ColourWrapperBecauseGTKdSucks (unbox!(TagColour)(value));
				Box[] arguments = new Box[2];
				arguments[0] = box(c.gdkHandle);
				arguments[1] = box(null);
				void* data = null;
				TypeInfo[] types;
				boxArrayToArguments (arguments, types, data);
				tag.setValist (property ~ "-gdk", data);
				}
			else if (unboxable!(int)(value))
				{
				tag.setProperty (property, unbox!(int)(value));
				}
			else if (unboxable!(bool)(value))
				{
				tag.setProperty (property, cast (int) unbox!(bool)(value));
				}
			else if (unboxable!(PangoUnderline)(value))
				{
				//tag.setProperty (property, cast (int) unbox!(PangoUnderline)(value));
				}
			else if (unboxable!(PangoStyle)(value))
				{
				//tag.setProperty (property, cast (int) unbox!(PangoStyle)(value));
				}
			else if (unboxable!(PangoWeight)(value))
				{
				//tag.setProperty (property, cast (int) unbox!(PangoWeight)(value));
				}
			else
				{
				tag.setProperty (property, value.toString ());
				}
			}

		buffer.getTagTable ().tableAdd (tag);

		return tag;
		}

	private void init_styles ()
		{
		_buffer = _pinnipede.getBuffer ();
		TextIter endIter = new TextIter ();
		_buffer.getEndIter (endIter);
		_buffer.createMark ("end", endIter, false);

		Box[char[]] properties;

		properties = null;
		properties["background"] = box (TagColour (0xFFFF88));
		properties["underline"]  = box (PangoUnderline.SINGLE);
		createTag (_buffer, "highlighted_post", properties);

		properties = null;
		properties["background"] = box (TagColour (0xFF8888));
		properties["underline"]  = box (PangoUnderline.SINGLE);
		createTag (_buffer, "highlighted_wrong_clock", properties);
		
		createTag (_buffer, "highlighted_main_post", ["background": box (TagColour (0xAAAA88))]);

		properties = null;
		properties["foreground"]  = box (TagColour (0xFF0000));
		properties["style"]       = box (PangoStyle.ITALIC);
		createTag (_buffer, "info", properties);

		createTag (_buffer, "login",        ["foreground": box (TagColour (0xFF0000))]);
		createTag (_buffer, "main_horloge", ["foreground": box (TagColour (0x0000FF))]);
		createTag (_buffer, "horloge",      ["foreground": box (TagColour (0x0000FF))]);
		createTag (_buffer, "totoz",        ["foreground": box (TagColour (0x0000AA))]);

		createTag (_buffer, "self",         ["background": box (TagColour (0xFFDDAA))]);
		createTag (_buffer, "answer",       ["background": box (TagColour (0xCCCC88))]);

		properties = null;
		properties["underline"]  = box (PangoUnderline.SINGLE);
		properties["foreground"]  = box (TagColour (0x0000FF));
		createTag (_buffer, "a", properties);

		createTag (_buffer, "b", [ "weight":        box (PangoWeight.BOLD) ]);
		createTag (_buffer, "i", [ "style":         box (PangoStyle.ITALIC) ]);
		createTag (_buffer, "u", [ "underline":     box (PangoUnderline.SINGLE) ]);
		createTag (_buffer, "s", [ "strikethrough": box (true) ]);
		}

	private void on_controls_click (Button button)
		{
		if (_reloadButton == button)
			{
			_thread.update_now ();
			}
		else 
			{
			}
		}

	private void on_new_post (Post post)
		{
		append_post (post);
		}

	private void set_progress_percent (double percent)
		{
		gdkThreadsEnter ();
		
		if (_timeSinceLastPost && _last_post_time > 0)
			{
			long secs_since_last_post = (getUTCtime () - _last_post_time) / (1000);
			_timeSinceLastPost.setText (std.string.format ("%ds", secs_since_last_post));
			}

		if (_progress)
			{
			_progress.setPercentage (percent);
			}

		gdkThreadsLeave ();
		}

	private synchronized void append_post (Post post)
		{
		gdkThreadsEnter ();

		pinnipede.append_post (post);

		gdkThreadsLeave ();
		}

	private synchronized void on_palmipede_changed (TextBuffer buffer)
		{
		int length = toUTF32(buffer.getText ()).length;
		_nbCharacters.setText (std.string.format ("%s", length));

		if (length > _tribune.max_length)
			{
			_nbCharacters.modifyFg (GtkStateType.NORMAL, new Color (0xFF0000));
			}
		else
			{
			_nbCharacters.modifyFg (GtkStateType.NORMAL, new Color (0x000000));
			}

		buffer.setModified (false);
		}

	private bool on_palmipede_insert (GdkEventKey *key, Widget source)
		{
		return handle_shortcut (key);
		}

	private void post_message ()
		{
		char[] message = _palmipede.getBuffer ().getText ();
		_palmipede.getBuffer ().setText ("");

		BackgroundThread post_thread = new BackgroundThread (&_tribune.post_message, boxArray (message), &this.message_sent);
		post_thread.start ();
		}

	private void message_sent (Box result)
		{
		_last_post_time = getUTCtime ();
		debug (1) dout.writefln ("Message has been sent : %s", result);
		this.update ();
		}

	private bool handle_shortcut (GdkEventKey *key)
		{
		bool handled = false;

		if (key.state & GdkModifierType.CONTROL_MASK)
			{
			switch (Keymap.gdkKeyvalName (key.keyval))
				{
				case "r":
					_thread.update_now ();
					handled = true;
					break;
				default:
					debug (1) dout.writefln ("Pressed ^%s", Keymap.gdkKeyvalName (key.keyval));
					break;
				}
			}
		else if (Keymap.gdkKeyvalName (key.keyval) == "Return")
			{
			this.post_message ();
			handled = true;
			}

		return handled;
		}

	public void open_url (char[] url)
		{
		_main.open_url (url);
		}

	private void on_segment_clicked (MessageSegment segment)
		{
		if (SegmentContext.MainHorloge in segment)
			{
			_palmipede.insert (segment.post.horloge.toString ());
			}
		else if (SegmentContext.Link in segment)
			{
			open_url (segment.data);
			}
		else if (SegmentContext.Totoz in segment)
			{
			open_url ("http://totoz.eu/" ~ segment.data ~ ".gif");
			}
		}
	}

