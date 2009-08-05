module xml.board;

import bcd.libxml2.parser;
import bcd.libxml2.tree;

import xml.post;

import std.cstream, std.string;

class XmlBoard
	{
	private char[] _name;
	private char[] _charset = "UTF8";
	private bool   _dirty = false;

	private XmlPost[] _posts;
	private char[][char[]] _attributes;

	/***
	  * Creates a new XmlBoard object and loads its posts
	  * 
	  * Params:
	  *	url = XML backend URL
	  *	dirty = board type (true: formatting tags are not HTML encoded)
	  */
	this (char[] contents, char[] url, bool dirty = false)
		{
		this._dirty = false;

		this.parse (contents, url);
		}

	private void parse (char[] contents, char[] url)
		{
		xmlCheckVersion (20621);

		_xmlDoc *doc = null;
		_xmlNode *root_element = null;

		//dout.writefln("URL: %s", url);

		//doc = xmlReadFile (toStringz (url), toStringz (this._charset), 0);
		doc = xmlReadMemory (toStringz (contents)
				           , contents.length
						   , toStringz (url)
						   , toStringz (this._charset)
						   , 0);
		root_element = xmlDocGetRootElement (doc);

		_xmlNode *cur_node = null;
		for (cur_node = root_element ; cur_node ; cur_node = cur_node.next)
			{
			_xmlNode *post_node = null;

			if (std.string.toString (cur_node.name) == "board")
				{
					for (post_node = cur_node.children ; post_node ; post_node = post_node.next)
					{
					if (std.string.toString (post_node.name) == "post")
						{
						this._posts ~= new XmlPost (post_node);
						}
					}
				}
			}
		}

	int opApply (int delegate (inout XmlPost) dg)
		{
		int result = 0;

		foreach (XmlPost post ; _posts.reverse)
			{
			result = dg (post);

			if (result)
				break;
			}

		return result;
		}
	}
