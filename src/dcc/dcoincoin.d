module dcc.cli;

private import std.stdio;
private import std.string;
private import std.regex;
private import std.utf : count;
private import std.conv;

private import core.thread;

private import dcc.conf;
private import dcc.tribune;

private import deimos.ncurses.ncurses;

extern (C) { char* setlocale(int category, const char* locale); }

void main(string[] args) {
	setlocale(0, "".toStringz());

	NCUI ui = new NCUI(".dcoincoinrc");
	ui.loop();
}

struct Stop {
	int offset;
	int start;
	int length;
	string text;
}

class NCUI {
	string config_file;
	Config config;
	NCTribune[string] tribunes;
	ulong active = 0;
	string[] tribune_names;

	WINDOW* posts_window;
	WINDOW* input_window;

	Stop current_stop;
	Stop[int] stops;
	int offset;

	this(string config_file) {
		this.config_file = config_file;

		this.config = new Config(".dcoincoinrc");

		this.init_ui();

		foreach (Tribune tribune ; this.config.tribunes) {
			this.tribunes[tribune.name] = new NCTribune(this, tribune);
			this.tribune_names ~= tribune.name;
		}

		this.set_status("");
	}

	void init_ui() {
		initscr();

		int input_height = 2;

		this.posts_window = newwin(LINES - input_height, 0, 0, 0);
		this.input_window = newwin(2, COLS, LINES - input_height, 0);

		mvwhline(this.input_window, 0, 0, 0, COLS);

		wrefresh(this.posts_window);
		wrefresh(this.input_window);

		scrollok(this.posts_window, true);
	}

	void set_status(string status) {
		mvwhline(this.input_window, 0, 0, 0, COLS);
		mvwprintw(this.input_window, 0, 2, "%.*s", this.tribune_names[this.active]);
		mvwprintw(this.input_window, 0, cast(int)(COLS - 2 - status.length), "%.*s", status);

		wmove(this.input_window, 1, 0);
		wrefresh(this.input_window);
	}

	void highlight_stop(Stop stop) {
		int line = this.posts_window.maxy - (this.offset - stop.offset);
		wmove(this.posts_window, line, stop.start);
		wchgat(this.posts_window, stop.length, A_REVERSE, 0, null);

		wmove(this.input_window, 1, 0);
		wrefresh(this.posts_window);
		wrefresh(this.input_window);
	}

	void unhighlight_stop(Stop stop) {
		int line = this.posts_window.maxy - (this.offset - stop.offset);
		wmove(this.posts_window, line, stop.start);
		wchgat(this.posts_window, stop.length, A_NORMAL, 0, null);

		wmove(this.input_window, 1, 0);
		wrefresh(this.posts_window);
		wrefresh(this.input_window);
	}

	void loop() {
		while (true) {
			wmove(this.input_window, 1, 0);

			noecho();
			keypad(this.input_window, true);
			auto ch = wgetch(this.input_window);
			switch (ch) {
				case 0x20:
					this.set_status("O");
					this.tribunes[this.tribune_names[this.active]].fetch_posts({
						this.set_status("");
					});
					/*
					auto remaining = this.tribunes.length - 1;
					foreach (NCTribune tribune; this.tribunes) {
						tribune.fetch_posts({
							remaining--;
							if (remaining == 0) {
								this.set_status("");
							}
						});
					}
					*/
					break;
				case KEY_RIGHT:
					this.active++;
					if (this.active >= this.tribune_names.length) {
						this.active = 0;
					}
					this.set_status("");
					break;
				case KEY_LEFT:
					this.active--;
					// This should be an ulong, but the compiler will optimize
					// this out anyway, and it's cleared and safer.
					if (this.active < 0 || this.active >= this.tribune_names.length) {
						this.active = this.tribune_names.length - 1;
					}
					this.set_status("");
					break;
				case KEY_UP:
					int start = this.offset;

					if (this.current_stop !is Stop.init) {
						start = this.current_stop.offset - 1;
					}

					this.set_status(to!string(start));

					for (int i = start; i >= 0; i--) {
						if (i in this.stops) {
							this.unhighlight_stop(this.current_stop);
							this.current_stop = this.stops[i];
							this.highlight_stop(this.stops[i]);
							break;
						}
					}
					break;
				case KEY_DOWN:
					int start = this.offset - this.posts_window.maxy;

					if (this.current_stop !is Stop.init) {
						start = this.current_stop.offset + 1;
					}

					this.set_status(to!string(start));

					for (int i = start; i <= this.offset; i++) {
						if (i in this.stops) {
							this.unhighlight_stop(this.current_stop);
							this.current_stop = this.stops[i];
							this.highlight_stop(this.stops[i]);
							break;
						}
					}
					break;
				case 0x0A:
					string pre = "";

					this.set_status("plop: " ~ this.current_stop.text);
					string text = uput(this.input_window, 1, 0, COLS, this.current_stop.text ~ " ", true);
					if (this.tribunes[this.tribune_names[this.active]].tribune.post(text)) {
						wmove(this.input_window, 1, 0);
						wclrtoeol(this.input_window);
						this.tribunes[this.tribune_names[this.active]].fetch_posts();
					}
					break;
				default:
					break;
			}
		}

		endwin();
	}

	void display_post(NCPost post) {
		wscrl(this.posts_window, 1);
		this.offset++;

		int x = 0;
		string clock = post.post.clock;
		string user = post.post.login;

		mvwprintw(this.posts_window, this.posts_window.maxy, x, "%.*s", clock);
		int clock_len = cast(int)std.utf.count(clock);
		this.stops[this.offset] = Stop(this.offset, x, clock_len, clock);
		x += clock_len;

		mvwprintw(this.posts_window, this.posts_window.maxy, x, " ");
		x += 1;

		wattron(this.posts_window, A_BOLD);
		mvwprintw(this.posts_window, this.posts_window.maxy, x, "%.*s", user);
		wattroff(this.posts_window, A_BOLD);

		x += std.utf.count(user);

		mvwprintw(this.posts_window, this.posts_window.maxy, x, "> ");
		x += 2;

		string[] tokens = post.tokenize();

		foreach (int i, string sub; tokens) {
			auto length = std.utf.count(sub);
			auto end = x + length;

			// No need to scroll ourselves if the word is
			// longer than screen, we'll let ncurses take
			// care of wrapping it where it likes.
			// But if it's smaller and it's going to end
			// outside the screen, then scroll and print
			// it with some indentation.
			if (end >= COLS && length < COLS) {
				x = 1;
				wscrl(this.posts_window, 1);
				this.offset++;
			}

			switch (sub.strip()) {
				case "<b>":
					wattron(this.posts_window, A_BOLD);
					break;
				case "</b>":
					wattroff(this.posts_window, A_BOLD);
					break;
				case "<i>":
					wattron(this.posts_window, A_REVERSE);
					break;
				case "</i>":
					wattroff(this.posts_window, A_REVERSE);
					break;
				case "<u>":
					wattron(this.posts_window, A_UNDERLINE);
					break;
				case "</u>":
					wattroff(this.posts_window, A_UNDERLINE);
					break;
				default:
					mvwprintw(this.posts_window, this.posts_window.maxy, x, "%.*s", sub);
					x += length;
					break;
			}
		}

		wattroff(this.posts_window, A_BOLD);
		wattroff(this.posts_window, A_REVERSE);
		wattroff(this.posts_window, A_UNDERLINE);

		wrefresh(this.posts_window);
	}
}

class NCTribune {
	Tribune tribune;
	NCUI ui;

	this(NCUI ui, Tribune tribune) {
		this.ui = ui;
		this.tribune = tribune;
		this.tribune.on_new_post ~= &this.on_new_post;
	}

	string[] tokenize(string line) {
		line = line.replace(regex(`\s+`, "g"), " ");
		line = line.replace(regex(`<a href=['"](.*?)['"]>.*?</a>`, "g"), "<$1>");

		string[] tokens = [""];

		bool next = false;
		foreach (char c; line) {
			switch (c) {
				case '<':
				case ' ':
					tokens ~= "";
					break;
				case '>':
					next = true;
					break;
				default:
					break;
			}

			tokens[$-1] ~= c;

			if (next) {
				next = false;
			}
		}

		return tokens;
	}

	void on_new_post(Post post) {
		NCPost p = new NCPost(post);
		synchronized {
			this.ui.display_post(p);
		}
	};

	void fetch_posts(void delegate() callback = null) {
		core.thread.Thread t = new core.thread.Thread({
			this.tribune.fetch_posts();
			if (callback) {
				callback();
			}
		});
		t.start();
	}
}

class NCPost {
	Post post;
	this(Post post) {
		this.post = post;
	}

	string[] tokenize() {
		string line = this.post.message.replace(regex(`\s+`, "g"), " ");
		line = line.replace(regex(`<a href=['"](.*?)['"]>.*?</a>`, "g"), "<$1>");
		line = std.array.replace(line, "&lt;", "<");
		line = std.array.replace(line, "&gt;", ">");
		line = std.array.replace(line, "&amp;", "&");

		string[] tokens = [""];

		bool next = false;
		foreach (char c; line) {
			switch (c) {
				case '<':
				case ' ':
					tokens ~= "";
					break;
				case '>':
					next = true;
					break;
				default:
					break;
			}

			tokens[$-1] ~= c;

			if (next) {
				tokens ~= "";
				next = false;
			}
		}

		return tokens;
	}
}

int _uput_default_exit;
string uput(WINDOW* w, int y, int x, int length, string whole, bool ins, out int exit = _uput_default_exit) {
/*
+------------------------[ WHAT YOU PUT IN ]-------------------------------+
|UPUT(y, x, length, fg, bg, whole, ins, permitted)                        |
+--------------------------------------------------------------------------+
|y -> Row where INPUT will start                                           |
|x -> Column where INPUT will start                                        |
|length -> Maximum length of INPUT                                         |
|whole -> String to be edited                                              |
|ins -> TRUE or FALSE for INSERT on/off                                    |
+---------------------[ WHAT YOU GET BACK ]--------------------------------+
|                                                                          |
| If UPUT is exited by the user pressing ESCAPE, then the FUNCTION will    |
| return the original string it was given (ie: no changes are made).  If   |
| UPUT is exited any other way (TAB, SHIFT-TAB, UP, DOWN, ENTER), then     |
| the edited string is returned.                                           |
|                                                                          |
| In either case, the SHARED variable "keyflag%" is returned with a value  |
| which is dependent on HOW UPUT was exited, following the chart below     |
|                                      +-----------------------------------+
| ESCAPE     -> keyflag = 5            |The values are based on the KEYPAD!|
| ENTER      -> keyflag = 0            +--------------+--------+-----------+
| UP ARROW   -> keyflag = 8            |       (7)    | UP(8)  | (9)       |
| DOWN ARROW -> keyflag = 2            +--------------+--------+-----------+
| TAB        -> keyflag = 6            |   SHFT-TAB(4)| ESC(5) |TAB(6)     |
| SHIFT-TAB  -> keyflag = 4            +--------------+--------+-----------+
|                                      |       (1)    | DOWN(2)|  (3)      |
|                                      +--------------+--------+-----------|
|                                      |    ENTER(0)  |                    |
+--------------------------------------+-----------------------------------+
*/
	int flag = 0, curspos=0, counter;
	dchar ky;
	bool exitflag=false;
	string tempwhole = whole.dup;
	
	keypad(w, true);

	do {
		wmove(w, y,x);
		for (counter=0; counter < length; counter++) {
			waddch(w, ' ');
		}
		wmove (w, y,x);
		waddstr(w, whole.toStringz());
		wmove(w, y, x + curspos);

		if (ins) {
			curs_set(2);
		} else {
			curs_set(1);
		}
		
		wrefresh(w);
		wget_wch(w, &ky);
		
		switch (ky) {
			case KEY_LEFT:
				if (curspos != 0) {
					curspos--;
				}
				break;
			case KEY_RIGHT:
				if (curspos != length-1 && curspos < whole.length) {
					curspos++;
				}
				break;
			case KEY_HOME:
				//case KEY_A1: =KEY_HOME on Linux so not required 
				curspos = 0;
				break;
			case KEY_END:
				//case KEY_C1: =KEY_END on Linux so not required
				whole = whole.stripRight();
				curspos = cast(int)whole.length;
				if (whole.length == length) {
					curspos--;
				}
				break;
			case KEY_IC: //insert key
				ins = !ins;
				if (ins) {
					curs_set(2);
				} else {
					curs_set(1);
				}
				break;
			case KEY_DC: //delete key
				if (curspos > whole.length - 1) {
					break;
				}

				dstring utf32 = to!dstring(whole.dup);
				whole = to!string(utf32[0 .. curspos] ~ utf32[curspos + 1 .. $]);
				break;
			case 127:
			case KEY_BACKSPACE:
				if (curspos > 0) {
					dstring utf32 = to!dstring(whole.dup);
					whole = to!string(utf32[0 .. curspos - 1] ~ utf32[curspos .. $]);
					curspos--;
				}
				break;
			case 10: // enter
				flag=0;
				exitflag=true;
				break;
			case KEY_UP: // up-arrow
				flag=8;
				exitflag=true;
				break;
			case KEY_DOWN: // down-arrow
				flag=2;
				exitflag=true;
				break;
			case 9: // tab
				flag=6;
				exitflag=true;
				break;
			case KEY_BTAB: // shift-tab
				flag=4;
				exitflag=true;
				break;
			case 27: //esc
				// esc twice to get out, otherwise eat the chars that don't work
				// from home or end on the keypad
				wget_wch(w, &ky);
				if (ky == 27) {
					whole = tempwhole.dup;
					flag = 5;
					exitflag = true;
				} else if (ky == '[') {
					wget_wch(w, &ky);
					wget_wch(w, &ky);
				} else {
					unget_wch(ky);
				}
				break;
			default:
				dchar ch = cast(dchar)ky;
				if (ins) {
					if (curspos < whole.length) {
						if (whole.length < length) {
							dstring utf32 = to!dstring(whole.dup);
							whole = to!string(utf32[0 .. curspos] ~ to!dstring(ch) ~ utf32[curspos .. $]);
						} else {
							curspos--;
						}
					} else {
						whole ~= ch;
					}
				} else {
					if (curspos < whole.length) {
						dstring utf32 = to!dstring(whole.dup);
						whole = to!string(utf32[0 .. curspos] ~ to!dchar(ch) ~ utf32[curspos .. $]);
					} else {
						whole ~= ch;
					}
				}

				if (curspos < length-1) {
					curspos++;
				}
		}
	} while (!exitflag);

	exit = flag;
	return whole.stripRight();
}
