module engine.tribune;

import common;

import libiconv;

import tinycurl.tinycurl;

import engine.horloge, xml.board, xml.post;
import engine.post, engine.html;

import std.string, std.cstream, std.stream, std.conv, std.file;
import std.boxer;
import std.c.time;

int nb = 0;

class Tribune
	{
	private char[] _name;
	private char[] _back_url;
	private char[] _post_url;
	private char[] _post_template;
	private int    _period;		/// en secondes
	private char[] _cookie;
	private char[] _useragent;
	private char[] _login;
	private int    _max_length;

	private bool _moderne; /// true : UTF8, false : latin9
	private bool _sale;

	private Post[int] _posts;
	private Post[] _newPosts;

	private Horloge _last_horloge = null;

	private iconv_t _iconverter;

	private void delegate (Post post) _on_new_post;

	public int period ()
		{
		return _period;
		}

	public char[] name ()
		{
		return _name.dup;
		}

	public char[] post_url ()
		{
		return _post_url.dup;
		}

	public char[] cookie ()
		{
		return _cookie.dup;
		}

	public char[] post_template ()
		{
		return _post_template.dup;
		}

	public char[] login ()
		{
		return _login.dup;
		}

	public char[] user_agent ()
		{
		return replace (_useragent, "%v", VERSION);
		}

	public bool is_moderne ()
		{
		return _moderne;
		}

	public bool is_sale ()
		{
		return _sale;
		}

	public int max_length ()
		{
		return _max_length;
		}

	public this (char[] name,
		     char[] back_url,
	             char[] post_url,
		     char[] post_template,
		     int    period,    /// _o/* BLAM ! Pas frequency !
		     char[] cookie,
		     char[] useragent,
		     char[] login,
		     bool   moderne    = false,
		     bool   sale       = false,
			 int    max_length = 255)
		{
		this._name          = name;
		this._back_url      = back_url; 
		this._post_url      = post_url ;
		this._post_template = post_template;
		this._period        = period;
		this._cookie        = cookie;
		this._useragent     = useragent.length > 0 ? useragent : "DCoinCoin/%v";
		this._login         = login;
		this._moderne       = moderne;
		this._sale          = sale;
		this._max_length    = max_length;
		}

	public void update ()
		{
		CURLRequest curl = new CURLRequest(_back_url);
		char[] contents = curl.get (_cookie, _useragent);

		debug (1) dout.writefln ("Updating board \"%s\"...", this.name);
		debug (5) dout.writefln ("Contents: \"%s\"...", contents);
		parse (contents);
		}

	public void parse (char[] contents)
		{
		XmlBoard board = new XmlBoard (contents, _back_url, _sale);

		_newPosts.length = 0;

		foreach (XmlPost post ; board)
			{
			if (_last_horloge is null || _last_horloge.older_than (atoi (post.id)))
				{
				add_post (new Post (post, this));
				}
			}

		synchronized if (_on_new_post !is null) foreach (Post post ; _newPosts)
			{
			_on_new_post (post);
			}
		}

	public Post[int] find_posts (char[] horloge)
		{
		Post[int] posts_trouvés;

		foreach (int index, Post post ; this._posts)
			{
			if (post.match_horloge (horloge))
				{
				posts_trouvés[index] = post;
				}
			}

		return posts_trouvés;
		}

	public void add_post (Post post)
		{ 
		if (_last_horloge is null || post.horloge > _last_horloge)
			{
			post.horloge.set_indice (_last_horloge);
			_last_horloge = post.horloge;

			_posts[post.horloge.id] = post;
			_newPosts ~= post;
			}
		}

	public void on_new_post_add (void delegate (Post post) f)
		{
		_on_new_post = f;
		}

	public Box post_message (Box[] arguments)
		{
		bool result = false;

		if (arguments.length == 1 && unboxable!(char[])(arguments[0]))
			{
			char[] message = unbox!(char[])(arguments[0]);
			byte[] msgdata;

			if (is_moderne)
				msgdata = cast (byte[]) message;
			else
				msgdata = conv_sale (html_entities_encode (message));

			CURLRequest curl = new CURLRequest(post_url);
			curl.post(cookie, format (post_template, curl.escape (msgdata)), user_agent);

			result = true;
			}

		return box (result);
		}

	public Post opIndex (size_t id)
		{
		if (id in _posts)
			{
			return _posts[id];
			}
		else
			{
			return null;
			}
		}

	public Post opIndex (char[] strid)
		{
		int id = atoi (strid);

		if (id in _posts)
			{
			return _posts[id];
			}
		else
			{
			return null;
			}
		}

	/***
	  * Convertit les strings propres UTF8 en truc éventuellement sale pour la tribune
	  *
	  * Params:
	  * 	clean = string propre
	  *
	  * Returns: byte[] dans le charset d'origine de la tribune
	  */
	public byte[] conv_sale (char[] clean)
		{
		clean = strip (clean);
		
		if (_iconverter is null)
			{
			_iconverter = iconv_open ("ISO-8859-15", "UTF8");
			}

		void* input = clean.ptr;
		size_t in_length = clean.length;

		byte[] outstr;
		outstr.length = clean.length * 2; // pour être sûr /o\
		void* output = outstr.ptr;
		size_t out_length = outstr.length;

		size_t result = iconv (_iconverter, &input, &in_length, &output, &out_length);

		outstr = outstr[0 .. outstr.length - out_length];

		return outstr;
		}
	}
