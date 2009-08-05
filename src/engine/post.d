module engine.post;

import std.cstream, std.string, std.utf, std.regexp;
import std.date, std.conv;

import xml.post;

import bcd.libxml2.parser;
import bcd.libxml2.tree;

import engine.tribune;
import engine.horloge;
import common;

enum SegmentContext
	{
	None		= 1 << 0,
	Bold		= 1 << 1,
	Italic		= 1 << 2,
	Underline	= 1 << 3,
	Strike		= 1 << 4,
	Horloge		= 1 << 5,
	Link		= 1 << 6,
	Totoz		= 1 << 7,
	Login		= 1 << 8,
	Info		= 1 << 9,
	MainHorloge	= 1 << 10
	}

class MessageSegment
	{
	dchar[] _text;
	SegmentContext context;
	char[] data;
	int index;

	Post post;

	private this (dchar[] text, SegmentContext context, char[] data)
		{
		this._text = text;
		this.context = context;
		this.data = data;
		this.post = post;
		}

	static MessageSegment opCall (char[] text, SegmentContext context = SegmentContext.None, char[] data = "")
		{
		text = tr (text, "\n\r\t", "", "d");
		text = squeeze (text, " ");

		return new MessageSegment (toUTF32 (text), context, data);
		}

	public int length()
		{
		return this._text.length;
		}

	public char[] text()
		{
		return toUTF8 (this._text);
		}

	public bool opIn_r (SegmentContext context)
		{
		return (context & this.context) != 0;
		}
	}

public class Post
	{
	private Horloge	_horloge;
	private char[]	_login;
	private char[]	_info;
	private bool	_self;
	private bool	_answer;
	private MessageSegment[int] _segments;
	private int		_length = 0;

	private Post[int][char[]] _referenced_posts;
	private Post[int] _referencing_posts;
	private MessageSegment[int][Post] _referencing_clocks;

	private Tribune	_tribune;

	int debut;
	int fin;

	public Horloge horloge ()
		{
		return _horloge;
		}

	public char[] login ()
		{
		return _login;
		}

	public char[] info ()
		{
		return _info;
		}

	public Post[int][char[]] referenced_posts ()
		{
		return _referenced_posts;
		}

	public Post[int] referencing_posts ()
		{
		return _referencing_posts;
		}

	public MessageSegment[int][Post] referencing_clocks ()
		{
		return _referencing_clocks;
		}

	public bool self ()
		{
		return _self;
		}

	public void referenced_by (Post post, int index, MessageSegment clock)
		{
		this._referencing_posts[post.horloge.id] = post;

		this._referencing_clocks[post][index] = clock;
		}

	public MessageSegment opIndex (int index)
		{
		int beginning = -1;

		foreach (int i, MessageSegment s ; _segments)
			{
			if (i <= index && s.context != SegmentContext.None)
				{
				beginning = i;
				}
			}

		if (beginning >= 0)
			{
			if (beginning + _segments[beginning].text.length >= index)
				{
				return _segments[beginning];
				}
			}

		return null;
		}

	public MessageSegment[int] segments ()
		{
		return _segments;
		}

	this (XmlPost post, Tribune tribune)
		{
		_login		= strip(post.login);
		_info		= strip(post.info);
		_horloge	= post.horloge;

		this ~= MessageSegment (_horloge.toString(), SegmentContext.MainHorloge);
		this ~= MessageSegment ("\&nbsp;", SegmentContext.None);

		if (_login && _login != "Anonyme")
			{
			this ~= MessageSegment (_login, SegmentContext.Login);
			}
		else
			{
			this ~= MessageSegment (_info.length > 10 ? _info[0 .. 10] : _info, SegmentContext.Info, _info);
			}

		this ~= MessageSegment (">\&nbsp;", SegmentContext.None);

		_tribune = tribune;
		_self    = _login == _tribune.login;

		parse_xml_post (post);
		}

	private void parse_xml_post (XmlPost post)
		{
		parse_node (post.message);
		}

	private _xmlNode* parse_xml_string (char[] string)
		{
		string = "<xml>" ~ string ~ "</xml>";
		_xmlDoc *doc = xmlReadMemory (toStringz (string)
				           , string.length
						   , toStringz ("")
						   , toStringz ("UTF-8")
						   , 0);

		return xmlDocGetRootElement (doc);
		}

	private void parse_node (_xmlNode *node, SegmentContext context = SegmentContext.None, bool stop = false)
		{
		char[] name = std.string.toString (node.name);

		SegmentContext ctxt = context;

		switch (name)
			{
			case "b":
				ctxt |= SegmentContext.Bold;
				break;
			case "i":
				ctxt |= SegmentContext.Italic;
				break;
			case "u":
				ctxt |= SegmentContext.Underline;
				break;
			case "s":
				ctxt |= SegmentContext.Strike;
				break;
			case "": // CDATA
				parse_node (parse_xml_string (std.string.toString (node.content)));
				return;
			case "text":
				if (ctxt & SegmentContext.Link)
					{
					this ~= MessageSegment (" ", SegmentContext.None);
					break;
					}


				char* content = node.content;

				if (_tribune.is_sale () && !stop)
					{
					_xmlNode* n = parse_xml_string (std.string.toString (node.content));

					if (n && n.children && n.children.content)
						{
						parse_node (n, SegmentContext.None, true);
						}
					return;
					}

				char[] text = std.string.toString (content);
				
				if (text.length)
					{
					parse_segment (text, ctxt);
					}
				return;
			case "a":
				ctxt |= SegmentContext.Link;
				parse_link (node, ctxt);
				break;
			default:
				break;
			}

		_xmlNode *child = null;
		for (child = node.children ; child ; child = child.next)
			{
			parse_node (child, ctxt, stop);
			}
		}

	private void parse_link (_xmlNode* link_node, SegmentContext ctxt = SegmentContext.None)
		{
		_xmlAttr *attribute = null;

		for (attribute = link_node.properties ; attribute ; attribute = attribute.next)
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
						case "class":
							if (std.string.find (node_text, "smiley") >= 0)
								{ // hack around bouchot.org's silly backend
								ctxt ^= SegmentContext.Link;
								_xmlNode *a = null;
								for (a = link_node.children ; a ; a = a.next)
									{
									if (std.string.toString (a.name) == "text")
										{
										parse_totoz (std.string.toString (a.content));
										}
									}
								return;
								}
							break;
						case "href":
							char[] displayed_string = url_rewrite (node_text);
							this ~= MessageSegment (displayed_string, ctxt, node_text);
							break;
						default:
				if (this._tribune.name == "tifauv")
					{
					dout.writefln("Node? %s = %s", std.string.toString (node.name), std.string.toString (node.content));
					}
							break;
						}
					}
				}
			}
		}

	private void opCatAssign (MessageSegment segment)
		{
		if (segment.length > 0)
			{
			segment.index = _length;
			_segments[_length] = segment;
			_length += segment.length;
			segment.post = this;
			}
		}

	private char[] url_rewrite (char[] url)
		{
		return sub (url, r"^([a-z]+)://.*$", r"[$1]", "i");
		}

	private void parse_segment (char[] text, SegmentContext ctxt = SegmentContext.None)
		{
		RegExp re = RegExp (r"((([01]?[0-9])|(2[0-3])):[0-5][0-9](:[0-5][0-9])?([:^][0-9]|¹|²|³)?(@[0-9A-Za-z]+)?)");
		char[] string = text.dup;

		if (re.test (string))
			{
			do
				{
				if (re.pre.length)
					parse_totoz (re.pre, ctxt);

				int clock_index = _length;

				this ~= MessageSegment (re.match(0), ctxt | SegmentContext.Horloge, re.match(0));

				_referenced_posts[re.match(0)] = _tribune.find_posts (re.match(0));

				foreach (int id, Post post ; _referenced_posts[re.match(0)])
					{
					post.referenced_by (this, clock_index, this._segments[clock_index]);
					}

				string = re.post;
				}
			while (re.test (string));
			}

		parse_totoz (string, ctxt);
		}

	private void parse_totoz (char[] text, SegmentContext ctxt = SegmentContext.None)
		{
		RegExp re = RegExp (r"\[:([^\]]+)\]");
		char[] string = text.dup;

		if (re.test (string))
			{
			do
				{
				if (re.pre.length)
					this ~= MessageSegment (re.pre, ctxt);

				this ~= MessageSegment (re.match(0), ctxt | SegmentContext.Totoz, re.match(1));

				if (re.post.length)
					string = re.post;
				else
					break;
				}
			while (re.test (string));

			if (re.post.length > 1)
				this ~= MessageSegment (re.post[1 .. $], ctxt);
			}
		else
			{
			this ~= MessageSegment (string, ctxt);
			}
		}

	public bool match_horloge (char[] horloge)
		{
		return _horloge.match (horloge);
		}
	}
