module gui.gtkd.palmipede;

import gtk.TextView;

import gtkc.gtktypes;

class Palmipede : TextView
	{
	this ()
		{
		super ();

		setEditable (true);
		setWrapMode (WrapMode.CHAR);
		}

	public void insert (char[] string)
		{
		insertText (string ~ " ");
		grabFocus ();
		}
	}
