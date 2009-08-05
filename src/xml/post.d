module xml.post;

import bcd.libxml2.parser;
import bcd.libxml2.tree;

import engine.horloge;

import std.cstream, std.string;

class XmlPost
	{
	private char[] _info;
	private _xmlNode *_message;
	private char[] _login;
	private char[] _id;
	private char[] _time;

	private Horloge _horloge;

	/***
	  * Creates a new XmlPost object from an _xmlNode
	  * 
	  * Params:
	  *	post_node = reference to an _xmlNode object
	  */
	this (_xmlNode *post_node)
		{
		this.parse (post_node);

		this._horloge = new Horloge (this._time, atoi (this._id));
		}

	public char[] id ()
		{
		return _id;
		}

	public char[] time ()
		{
		return _time;
		}

	public char[] info ()
		{
		return _info;
		}

	public _xmlNode *message ()
		{
		return _message;
		}

	public char[] login ()
		{
		return _login;
		}

	public Horloge horloge ()
		{
		return _horloge;
		}

	private char[] node_text (_xmlNode *node)
		{
		char[] text = std.string.toString (node.content);
		char[] name = std.string.toString (node.name);

		_xmlNode *child = null;
		for (child = node.children ; child ; child = child.next)
			{
			text ~= node_text (child);
			}

		return text;
		}

	private char[] sanitize_text (char[] text)
		{
		return strip (text);
		}

	private void parse (_xmlNode *post_node)
		{
		_xmlNode *child = null;

		for (child = post_node.children ; child ; child = child.next)
			{
			char[] node_name = std.string.toString (child.name);

			char[] node_text = node_text (child);

			switch (node_name)
				{
				case "info":
					this._info = sanitize_text (node_text);
					break;
				case "message":
					this._message = child;
					break;
				case "login":
					this._login = sanitize_text (node_text);
					break;
				default:
					break;
				}
			}

		parse_attributes (post_node);
		}

	private void parse_attributes (_xmlNode *post_node)
		{
		_xmlAttr *attribute = null;

		for (attribute = post_node.properties ; attribute ; attribute = attribute.next)
			{
			char[] attribute_name = std.string.toString (attribute.name);

			_xmlNode *node = null;
			for (node = attribute.children ; node ; node = node.next)
				{
				if (std.string.toString (node.name) == "text")
					{
					char[] node_text = std.string.toString (node.content);

					switch (attribute_name)
						{
						case "id":
							this._id = node_text;
							break;
						case "time":
							this._time = node_text;
							break;
						default:
							break;
						}
					}
				}

			}
		}
	}
