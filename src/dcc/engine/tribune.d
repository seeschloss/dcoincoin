module dcc.engine.tribune;

private import dcc.common;

private import std.net.curl;
private import std.xml;
private import std.signals;
private import std.datetime;
private import std.conv;
private import std.stdio;
private import std.string;
private import std.algorithm;
private import std.uri;
private import std.array;
private import std.regex : regex, replace, ctRegex, match;

import core.time;

class Tribune {
	string name;
	string[] aliases;
	string post_url;
	string post_format;
	string xml_url;
	string cookie;
	string ua;
	int refresh;
	bool tags_encoded;
	string color;
	string login;

	Duration time_offset;
	bool unreliable_date = false;
	SysTime last_update;

	Post[string] posts;
	void delegate (Post)[] on_new_post;
	mixin Signal!(Post) new_post;

	string last_posted_id;

	this(string xml_url, bool tags_encoded) {
		this.xml_url = xml_url;
		this.tags_encoded = tags_encoded;
	}

	this(string name, string[] aliases, string post_url, string post_format, string xml_url, string cookie, string ua, int refresh, bool tags_encoded, string color, string login) {
		this.name = name;
		this.aliases = aliases;
		this.post_url = post_url;
		this.post_format = post_format;
		this.xml_url = xml_url;
		this.cookie = cookie;
		this.ua = ua;
		this.refresh = refresh;
		this.tags_encoded = tags_encoded;
		this.color = color;
		this.login = login;
	}

	bool matches_name(string name) {
		if (name == this.name) {
			return true;
		}

		foreach (string a ; this.aliases) {
			if (name == a) {
				return true;
			}
		}

		return false;
	}

	bool fetch_posts() {
		string backend = this.fetch_backend();
		this.last_update = std.datetime.Clock.currTime(UTC());
		Post[] posts = this.parse_backend(backend).values;
		posts.sort!((a, b) => a.post_id < b.post_id);

		bool a = false;
		// Let's insert the new posts and keep track of their ids.
		string[] new_ids;
		Post last_post;
		foreach (Post post; posts) {
			if (post.post_id !in this.posts) {
				new_ids ~= post.post_id;
				this.posts[post.post_id] = post;

				if (last_post !is null && post.clock == last_post.clock) {
					if (last_post.index == 0) {
						last_post.index = 1;
					}

					post.index = last_post.index + 1;
				}

				last_post = post;
			}
		}

		// Hashtables have no sort order, so sort the new ids.
		new_ids.sort();

		// Now we can call this.on_new_post handlers on each post.
		foreach (string id ; new_ids) {
			Post post = this.posts[id];
			this.new_post.emit(this.posts[id]);
			foreach (void delegate(Post) f; this.on_new_post) {
				f(post);
			}
		}

		return true;
	}

	Post[string] parse_backend(string source) {
		check(source);
		// TODO: error handling

		auto xml = new DocumentParser(source);

		Post[string] posts;

		version (GNU) {
			// GDC seems to have problems with Unicode classes.
			auto control_chars = std.regex.ctRegex!(`[\x00-\x1F]`, "g");
		} else {
			auto control_chars = std.regex.ctRegex!(`\p{Control}`, "g");
		}

		xml.onStartTag["post"] = (ElementParser xml) {
			Post post = new Post();
			post.tribune = this;
			post.post_id = xml.tag.attr["id"];
			if (post.post_id == this.last_posted_id) {
				post.mine = true;
			}
			post.timestamp = xml.tag.attr["time"];
			xml.onEndTag["info"]    = (in Element e) {
				post.info = replace(e.text().strip(), control_chars, " ");
				post.info = this.tags_cleanup(post.info);
			};
			xml.onEndTag["message"] = (in Element e) {
				post.message = replace(e.text().strip(), control_chars, " ");

				if (this.tags_encoded) {
					post.message = this.tags_decode(post.message);
				}

				post.message = this.tags_cleanup(post.message);
			};
			xml.onEndTag["login"]   = (in Element e) {
				post.login = replace(e.text().strip(), control_chars, " ");
				post.login = this.tags_cleanup(post.login);
			};

			xml.parse();

			post.analyze_clocks();
			posts[post.post_id] = post;
		};

		xml.parse();

		return posts;
	}

	string tags_decode(string source) {
		source = std.xml.decode(source);
		return source;
	}

	string tags_cleanup(string source) {
		source = source.replace(regex(`<clock[^>]*>`, "g"), "");
		source = std.array.replace(source, `</clock>`, "");
		source = std.array.replace(source, `<![CDATA[`, "");
		source = std.array.replace(source, `]]>`, "");
		return source;
	}

	string fetch_backend() {
		auto connection = HTTP();
		connection.addRequestHeader("User-Agent", "DCoinCoin/" ~ VERSION);
		connection.operationTimeout(2.seconds);

		ubyte[] backend;
		try {
			backend = get!(HTTP, ubyte)(this.xml_url, connection);

			if (!this.unreliable_date && "date" in connection.responseHeaders) {
				try {
					SysTime now = std.datetime.Clock.currTime(UTC());
					SysTime tribuneTime = parseRFC822DateTime(connection.responseHeaders["date"]);

					this.time_offset = now - tribuneTime;
				} catch (DateTimeException e) {
				}
			}
		} catch (CurlException e) {
			return "";
		}

		if (backend.length > 0) {
			return cast(string)backend;
		} else {
			return "";
		}
	}

	bool post(string message) {
		auto connection = HTTP();
		connection.addRequestHeader("User-Agent", std.array.replace(this.ua, "%v", VERSION));
		connection.addRequestHeader("Referer", this.xml_url);
		connection.operationTimeout(2.seconds);

		if (this.cookie.length) {
			connection.addRequestHeader("Cookie", this.cookie);
		}

		string data = std.array.replace(this.post_format, "%s", message.encodeComponent());
		try {
			std.net.curl.post(this.post_url, data, connection);
			if ("x-post-id" in connection.responseHeaders) {
				this.last_posted_id = connection.responseHeaders["x-post-id"];
			}
		} catch (CurlException e) {
			return false;
		}

		return connection.statusLine.code < 300;
	}
}

struct Clock {
	string time;
	int index;
	string tribune;
	string text;
	Post post;
}

class Post {
	string post_id;
	string _timestamp;
	SysTime time;
	SysTime real_time;

	string info = "";
	string message = "";
	string login = "";

	int index = 0;

	Tribune tribune;

	Clock[] clocks;
	bool _mine;

	override string toString() {
		return this.clock ~ " " ~ this.login ~ "> " ~ this.message;
	}

	void mine(bool mine) {
		this._mine = mine;
	}

	bool mine() {
		if (this._mine) {
			return this._mine;
		}

		if (this.login.length && this.login == this.tribune.login) {
			return true;
		}

		if (this.info.length && this.info == this.tribune.ua) {
			return true;
		}

		return false;
	}

	void analyze_clocks() {
		auto clock_regex = ctRegex!(
			`(?P<time>`		// Time part: HH:MM[:SS]
				`(?:`
					`(?:[01]?[0-9])|(?:2[0-3])`		// Hour (00-23)
				`)`
				`:`
				`(?:[0-5][0-9])`					// Minute (00-59)
				`(?::(?:[0-5][0-9]))?`				// Optional seconds (00-59)
			`)`
			`(?P<index>`	// Optional index part: ¹²³, :n, or ^n
				`(?:(?:[:\^][0-9])|¹|²|³)?`
			`)`
			`(?P<tribune>`	// Optional tribune part: @tribunename
				`(?:@[A-Za-z]*)?`
			`)`
		, "g");

		if (auto match = this.message.match(clock_regex)) {
			while (!match.empty) {
				auto capture = match.front;

				int index = 1;

				if (capture["index"].length > 0) switch (to!dstring(capture["index"])[0]) {
					case ':':
					case '^':
						try {
							index = to!int(capture["index"][1 .. $]);
						}
						catch (Exception e) {
							// Let's keep index to 1.
						}
						break;
					case '¹': index = 1; break;
					case '²': index = 2; break;
					case '³': index = 3; break;
					default: break;
				}

				string clock_tribune = this.tribune.name;
				if (capture["tribune"].length > 0) {
					clock_tribune = capture["tribune"][1 .. $];
				}
				this.clocks ~= Clock(capture["time"], index, clock_tribune, capture.hit, this);

				match.popFront();
			}
		}
	}

	string timestamp() {
		return this._timestamp;
	}

	void timestamp(string s) {
		this._timestamp = s;

		if (s.length == 14) {
			int year   = to!int(s[0..4]);
			int month  = to!int(s[4..6]);
			int day    = to!int(s[6..8]);
			int hour   = to!int(s[8..10]);
			int minute = to!int(s[10..12]);
			int second = to!int(s[12..14]);

			this.time = SysTime(DateTime(year, month, day, hour, minute, second));
			this.real_time = this.time + this.tribune.time_offset;
		}
	}

	string clock() {
		return format("%02s:%02s:%02s", this.time.hour, this.time.minute, this.time.second);
	}

	string tribune_time() {
		return format("%04d%02d%02d%02d%02d%02d", this.time.year, this.time.month, this.time.day, this.time.hour, this.time.minute, this.time.second);
	}

	string unicodeClock() {
		switch (this.time.hour) {
			case 0:
			case 12:
				return this.time.minute < 30 ? "🕛" : "🕧";
			case 1:
			case 13:
				return this.time.minute < 30 ? "🕐" : "🕜";
			case 2:
			case 14:
				return this.time.minute < 30 ? "🕑" : "🕝";
			case 3:
			case 15:
				return this.time.minute < 30 ? "🕒" : "🕞";
			case 4:
			case 16:
				return this.time.minute < 30 ? "🕓" : "🕟";
			case 5:
			case 17:
				return this.time.minute < 30 ? "🕔" : "🕠";
			case 6:
			case 18:
				return this.time.minute < 30 ? "🕕" : "🕡";
			case 7:
			case 19:
				return this.time.minute < 30 ? "🕖" : "🕢";
			case 8:
			case 20:
				return this.time.minute < 30 ? "🕗" : "🕣";
			case 9:
			case 21:
				return this.time.minute < 30 ? "🕘" : "🕤";
			case 10:
			case 22:
				return this.time.minute < 30 ? "🕙" : "🕥";
			case 11:
			case 23:
				return this.time.minute < 30 ? "🕚" : "🕦";
			default:
				return "🕓";
		}
	}

	string clock_ref() {
		string clock = this.clock;

		switch (this.index) {
			case 0: break;
			case 1: clock ~= "¹"; break;
			case 2: clock ~= "²"; break;
			case 3: clock ~= "³"; break;
			default:
				clock ~= ":" ~ to!string(this.index);
				break;
		}

		return clock;
	}

	bool matches_clock(Clock clock) {
		if (clock.tribune == "" && this.tribune != clock.post.tribune) {
			return false;
		}

		if (clock.tribune != "" && !this.tribune.matches_name(clock.tribune)) {
			return false;
		}

		if (clock.text == this.clock_ref) {
			return true;
		}

		if (clock.text.length == 5 && clock.text == this.clock[0 .. 5]) {
			return true;
		}

		if (clock.time == this.clock && (clock.index == this.index || (clock.index == 1 && this.index == 0))) {
			return true;
		}

		if (clock.time == format("%02s:%02s", this.time.hour, this.time.minute) && clock.index == this.index) {
			return true;
		}

		return false;
	}

	string short_info() {
		auto max = min(10, this.info.length);
		return this.info[0 .. max];
	}
}

