module gui.minwin.main;

import common;
import conf.conf;

import minwin.all;
import minwin.logging;
version (Windows)
	{
	import minwin.mswindows;
	}

extern (C) int MinWinMain (Application *app)
	{
	Window window = new Window ("Coin ! Coin !");
	window.quitOnDestroy = true;
	window.visible = true;

	return app.enterEventLoop ();
	}

class CoinCoin
	{
	private Configuration _configuration;

	this (Configuration configuration)
		{
		this._configuration = configuration;
		}
	}
