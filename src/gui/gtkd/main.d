module gui.gtkd.main;

import common;
import conf.conf;

import engine.tribune;
import gui.gtkd.tribune;
import gui.gtkd.pinnipede;

import gtk.MainWindow;
import gtk.Notebook;
import gtk.Label;
import gtk.Widget;
import gtk.Main;

import gdk.Threads;

import gthread.Thread;

void main(char[][] args)
	{
	Thread.init (null);
	gdkThreadsInit ();
	gdkThreadsEnter ();
	Main.init (args);

	Configuration configuration = new Configuration (args.length > 1 ? args[1] : "");

	CoinCoin coin = new CoinCoin (configuration);
	coin.showAll ();

	Main.run ();
	gdkThreadsLeave ();
	}

class CoinCoin : MainWindow
	{
	private Configuration _configuration;

	this (Configuration configuration)
		{
		this._configuration = configuration;

		super ("Coin ! Coin !");

		init_interface ();

		addOnLeaveNotify (&on_leave);
		}

	public bool on_leave (GdkEventCrossing* event, Widget widget)
		{

		if (cast (Widget) widget)
			{
			std.cstream.dout.writefln ("Left %s", widget.getName ());
			}
		else
			{
			std.cstream.dout.writefln ("%s != %s", typeid (typeof (widget)), typeid (Pinnipede));
			}

		return 1;

		}

	public void open_url (char[] url)
		{
		url = std.string.replace (url, `\`, `\\`); // let's fix vim: `
		url = std.string.replace (url, `"`, `\"`);
		url = `"` ~ url ~ `" &`;
		char[] command = std.string.replace (_configuration["browser"], "%s", url);

		std.cstream.dout.writefln ("Launching %s...", command);
		std.process.system (command);
		}

	private void init_interface ()
		{
		this.setDefaultSize (350, 500);

		Notebook notebook = new Notebook ();
		notebook.setScrollable (true);
		notebook.setSizeRequest (200, -1);

		foreach (Tribune tribune ; this._configuration)
			{
			notebook.appendPage (new TribuneTab (tribune, this), tribune.name);
			}

		this.add (notebook);
		}
	}
