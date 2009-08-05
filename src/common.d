module common;

import std.utf, std.process, std.thread, std.cstream, std.string;

public const char[] VERSION = "0.0\&alpha;";

version (Windows)
	{
	public char[] default_browser = `C:\Program Files\Mozilla Firefox\firefox.exe`;
	}
else version (linux)
	{
	public char[] default_browser = "/usr/bin/firefox";
	}
else
	{
	public char[] default_browser = "firefox";
	}

public int strlen (char[] utf8string)
	{
	return toUTF32 (utf8string).length;
	}

public void open_url (char[] url)
	{
	return;

	/+ TODO
	url = replace (url, `'`, `\'`);

	char[] command = format ("%s '%s'", default_browser, url);

	dout.writefln ("Exécution de %s : '%s'", default_browser, url);
	Thread t = new Thread (&system, &command);
	t.start();
	dout.writefln ("Résultat : %s", r);

	//int r = system ();
	+/
	}

