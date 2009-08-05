module conf.conf;

import conf.ini;
import engine.tribune;
import common;

import std.file, std.path, std.conv, std.string;
import std.c.stdlib;

bool toBool (char[] string)
	{
	bool result = false;

	switch (strip (string))
		{
		case "true":
		case "yes":
		case "1":
		case "vrai":
		case "oui":
			result = true;
			break;
		case "false":
		case "no":
		case "0":
		case "faux":
		case "non":
		case "":
			result = false;
			break;
		default:
			result = false;
			break;
		}

	return result;
	}

class Configuration
	{
	private const char[] DCOINCOIN_FILE = "dcoincoin.ini";

	private char[]	_base_dir;
	private char[]	_base_file;

	private Tribune[] _tribunes;

	private char[][char[]] _conf;

	private Ini	_ini;

	this (char[] dir)
		{
		if (dir.length == 0)
			{
			if (exists ("." ~ sep ~ DCOINCOIN_FILE))
				{
				_base_dir = ".";
				}
			else
				{
				version (Windows)
					{
					_base_dir = std.conv.toString (getenv ("HOMEDRIVE")) ~ std.conv.toString (getenv ("HOMEPATH"));
					}
				else
					{
					_base_dir = std.conv.toString (getenv ("HOME"));
					}
				}
			}
		else
			{
			_base_dir	= dir;
			}

		_base_file	= _base_dir ~ sep ~ DCOINCOIN_FILE;

		if (exists (_base_dir) && isdir (_base_dir))
			{
			if (exists (_base_file))
				{
				_ini = new Ini (_base_file);

				load_conf ();
				}
			else
				{
				throw new ConfigurationException
					("File does not exist : " ~ _base_file);
				}
			}
		else
			{
			throw new ConfigurationException
				("Directory does not exist : " ~ _base_dir);
			}
		}

	private void load_conf ()
		{
		if (!_ini)
			{
			return;
			}

		foreach (IniSection section ; _ini)
			{
			if (section.name == "dcoincoin")
				{ // conf générale
				foreach (IniKey key ; section)
					{
					_conf[strip (key.name)] = strip (key.value);
					}
				}
			else
				{ // conf d'une tribune

				char[] name	= strip (section.name);
				char[] backend	= strip (section["backend"]);
				char[] posturl	= strip (section["posturl"]);
				char[] tmplate	= strip (section["template"]);
				char[] period	= strip (section["period"]);
				char[] cookies	= strip (section["cookies"]);
				char[] uagent	= strip (section["useragent"]);
				char[] login	= strip (section["login"]);
				bool   modern	= toBool (section["moderne"]);
				bool   sale     = toBool (section["sale"]);
				char[] max_length = strip (section["max_length"]);

				int    int_period = 30;
				try {int_period = toInt (period);}
				catch (Error e) {}

				int int_max_length = 255;
				try {int_max_length = toInt (max_length);}
				catch (Error e) {}


				Tribune tribune = new Tribune (name,
						               backend,
						               posturl,
							       tmplate,
							       int_period,
							       cookies,
							       uagent,
							       login,
							       modern,
							       sale,
								   int_max_length);

				_tribunes ~= tribune;
				}
			}
		}

	int opApply (int delegate (inout Tribune) dg)
		{
		int result = 0;

		foreach (Tribune tribune ; _tribunes)
			{
			result = dg (tribune);

			if (result)
				break;
			}

		return result;
		}

	char[] opIndex (char[] key)
		{
		if (key in _conf)
			{
			return _conf[key];
			}
		else
			{
			return "";
			}
		}
	}

class ConfigurationException : Exception
	{
	this (char[] message)
		{
		super (message);
		}
	}
