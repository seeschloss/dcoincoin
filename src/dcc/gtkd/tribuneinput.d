module dcc.gtkd.tribuneinput;

private import std.stdio;
private import std.string : format;

private import gtk.TextView;
private import gtk.TextBuffer;
private import gtk.TextIter;
private import gtk.TextMark;
private import gtk.CssProvider;

private import gtkc.gtktypes;

private import gdk.Color;

private import dcc.engine.tribune;
private import dcc.gtkd.main;

class TribuneInput : TextView {
	GtkTribune[string] tribunes;
	TextBuffer buffer;
	CssProvider css;

	this() {
		this.buffer = this.getBuffer();
		this.setEditable(true);
		this.setWrapMode(WrapMode.CHAR);

		this.setName("TribuneInput");

		this.css = new CssProvider();
		this.getStyleContext().addProvider(css, 600);

		this.setBorderWindowSize(GtkTextWindowType.TOP, 2);
	}

	int lineHeight() {
		int y, height;
		TextIter iter = new TextIter();
		this.getBuffer().getEndIter(iter);

		this.getLineYrange(iter, y, height);

		return height;
	}

	void setCurrentTribune(GtkTribune tribune) {
		if (tribune.tag !in this.tribunes) {
			this.buffer.createTag(tribune.tag, "paragraph-background", tribune.color);
			this.tribunes[tribune.tag] = tribune;
		}

		this.css.loadFromData(format(`
			#TribuneInput {
				margin-top: 2px;
				background-color: %s;
			}
		`, tribune.color));
	}
}

