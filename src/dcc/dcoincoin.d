module dcc.cli;

private import std.stdio;
private import std.string;
private import std.regex;
private import std.utf : count;
private import std.conv;
private import std.algorithm : filter;

private import core.thread;

private import dcc.conf;
private import dcc.tribune;
private import dcc.uput;

private import deimos.ncurses.ncurses;

extern (C) { char* setlocale(int category, const char* locale); }

void main(string[] args) {
	setlocale(0, "".toStringz());

	NCUI ui = new NCUI(".dcoincoinrc");
	ui.loop();
}

void init_colors() {
	init_pair( 1, COLOR_WHITE,   COLOR_BLACK);
	init_pair( 2, COLOR_RED,     COLOR_BLACK);
	init_pair( 3, COLOR_GREEN,   COLOR_BLACK);
	init_pair( 4, COLOR_YELLOW,  COLOR_BLACK);
	init_pair( 5, COLOR_BLUE,    COLOR_BLACK);
	init_pair( 6, COLOR_MAGENTA, COLOR_BLACK);
	init_pair( 7, COLOR_CYAN,    COLOR_BLACK);

	init_pair( 8, COLOR_BLACK, COLOR_WHITE  );
	init_pair( 9, COLOR_BLACK, COLOR_RED    );
	init_pair(10, COLOR_BLACK, COLOR_GREEN, );
	init_pair(11, COLOR_BLACK, COLOR_YELLOW );
	init_pair(12, COLOR_BLACK, COLOR_BLUE   );
	init_pair(13, COLOR_BLACK, COLOR_MAGENTA);
	init_pair(14, COLOR_BLACK, COLOR_CYAN   );
}

struct Stop {
	int offset;
	int start;
	int length;
	NCPost post;
	attr_t attributes;
	short color;
	NCPost referenced_post;
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
	Stop[] stops;
	int offset;

	this(string config_file) {
		this.config_file = config_file;

		this.config = new Config(".dcoincoinrc");

		this.init_ui();

		int n = 2;
		foreach (Tribune tribune ; this.config.tribunes) {
			this.tribunes[tribune.name] = new NCTribune(this, tribune);
			this.tribune_names ~= tribune.name;

			this.tribunes[tribune.name].color = n;
			// Pick a color starting from index 1
			n++;
			if (n >= 7) {
				n = 2;
			}
		}
	}

	void init_ui() {
		initscr();
		start_color();
		init_colors();

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

	void highlight_post(NCPost post) {
		if (post.offset > this.offset - this.posts_window.maxy) {
			int line = this.posts_window.maxy - (this.offset - post.offset);
			wattron(this.posts_window, post.tribune.color(true));
			mvwprintw(this.posts_window, line, 0, "#");
			wattroff(this.posts_window, post.tribune.color(true));
			wrefresh(this.posts_window);
		}
	}

	void unhighlight_post(NCPost post) {
		if (post.offset > this.offset - this.posts_window.maxy) {
			int line = this.posts_window.maxy - (this.offset - post.offset);
			wattron(this.posts_window, post.tribune.color());
			mvwprintw(this.posts_window, line, 0, "*");
			wattroff(this.posts_window, post.tribune.color());
			wrefresh(this.posts_window);
		}
	}

	void highlight_stop(Stop stop) {
		int line = this.posts_window.maxy - (this.offset - stop.offset);
		wmove(this.posts_window, line, stop.start);
		wchgat(this.posts_window, stop.length, A_REVERSE, 0, null);

		wmove(this.input_window, 1, 0);
		wrefresh(this.posts_window);
		wrefresh(this.input_window);

		if (stop.referenced_post) {
			this.highlight_post(stop.referenced_post);
		}
	}

	void unhighlight_stop(Stop stop) {
		int line = this.posts_window.maxy - (this.offset - stop.offset);
		wmove(this.posts_window, line, stop.start);

		wchgat(this.posts_window, stop.length, stop.attributes, stop.color, null);

		wmove(this.input_window, 1, 0);
		wrefresh(this.posts_window);
		wrefresh(this.input_window);

		if (stop.referenced_post) {
			this.unhighlight_post(stop.referenced_post);
		}
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
					if (!this.prev_stop()) {
						// We're at the top... scroll?
					}
					break;
				case KEY_DOWN:
					if (!this.next_stop()) {
						// We're at the bottom... scroll?
					}
					break;
				case 0x0A:
					string prompt = "> ";
					string initial_text = this.current_stop !is Stop.init ? this.current_stop.post.post.clock ~ " " : "";

					mvwprintw(this.input_window, 1, 0, prompt.toStringz());
					string text = uput(this.input_window, 1, cast(int)prompt.count, COLS - cast(int)prompt.count, initial_text, true);
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

	void adjust_stop() {
		if (this.current_stop.offset < this.offset) {
			next_stop();
		}
	}

	bool prev_stop() {
		Stop previous_stop = this.current_stop;
		if (this.current_stop is Stop.init) {
			this.current_stop = this.stops[$ - 1];
		} else foreach_reverse (Stop stop; this.stops) {
			if (stop.offset > this.offset - this.posts_window.maxy) {
				if ((stop.offset < this.current_stop.offset) ||
					(stop.offset == this.current_stop.offset && stop.start < this.current_stop.start)) {
					this.current_stop = stop;
					break;
				}
			}
		}

		this.unhighlight_stop(previous_stop);
		this.highlight_stop(this.current_stop);

		return this.current_stop.offset != previous_stop.offset || this.current_stop.start != previous_stop.start;
	}

	bool next_stop() {
		Stop previous_stop = this.current_stop;
		if (this.current_stop is Stop.init) foreach (Stop stop; this.stops) {
			if (stop.offset > this.offset - this.posts_window.maxy) {
				this.current_stop = stop;
				break;
			}
		} else foreach (Stop stop; this.stops) {
			if (stop.offset > this.offset - this.posts_window.maxy) {
				if ((stop.offset > this.current_stop.offset) ||
					(stop.offset == this.current_stop.offset && stop.start > this.current_stop.start)) {
					this.current_stop = stop;
					break;
				}
			}
		}

		this.unhighlight_stop(previous_stop);
		this.highlight_stop(this.current_stop);

		return this.current_stop.offset != previous_stop.offset || this.current_stop.start != previous_stop.start;
	}

	void display_post(NCPost post) {
		wscrl(this.posts_window, 1);
		this.offset++;

		post.offset = this.offset;

		int x = 0;
		string clock = post.post.clock;
		string user = post.post.login;

		wattron(this.posts_window, post.tribune.color());
		mvwprintw(this.posts_window, this.posts_window.maxy, x, "*");
		x += 1;
		wattroff(this.posts_window, post.tribune.color());
		mvwprintw(this.posts_window, this.posts_window.maxy, x, "%.*s", clock);
		int clock_len = cast(int)std.utf.count(clock);
		ulong current_attributes;
		short pair;
		int opts;
		wattr_get(this.posts_window, &current_attributes, &pair, cast(void*)&opts);

		Stop post_stop = Stop(this.offset, x, clock_len, post, current_attributes, pair);
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

		bool has_clocks = false;
		foreach (int i, string sub; tokens) {
			auto length = sub.count;

			// No need to scroll ourselves if the word is
			// longer than screen, we'll let ncurses take
			// care of wrapping it where it likes.
			// But if it's smaller and it's going to end
			// outside the screen, then scroll and print
			// it with some indentation.
			if (x + length >= COLS && length < COLS) {
				x = 2;
				sub = sub.stripLeft();
				length = sub.count;
				wscrl(this.posts_window, 1);
				this.offset++;
			}

			bool is_clock = false;
			auto clock_regex = regex(`((([01]?[0-9])|(2[0-3])):([0-5][0-9])(:([0-5][0-9]))?([:\^][0-9]|¹|²|³)?)`);
			if (sub.strip().match(clock_regex)) {
				wattr_get(this.posts_window, &current_attributes, &pair, cast(void*)&opts);
				if (!(current_attributes & A_BOLD)) {
					wattron(this.posts_window, A_BOLD);
					is_clock = true;
				}

				has_clocks = true;

				wattr_get(this.posts_window, &current_attributes, &pair, cast(void*)&opts);

				this.stops ~= Stop(this.offset, x, cast(int)sub.count, post, current_attributes, pair, post.tribune.find_referenced_post(sub.strip()));
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

			if (is_clock) {
				wattroff(this.posts_window, A_BOLD);
			}

			if (length >= COLS) {
				// Then the text will have wrapped several times.
				this.offset += x/COLS;
				x = x%COLS;
			}
		}

		if (!has_clocks) {
			this.stops ~= post_stop;
		}

		wattroff(this.posts_window, A_BOLD);
		wattroff(this.posts_window, A_REVERSE);
		wattroff(this.posts_window, A_UNDERLINE);

		wrefresh(this.posts_window);

		post.lines = this.offset - post.offset + 1;

		adjust_stop();
	}
}

class NCTribune {
	Tribune tribune;
	NCUI ui;
	int _color;
	NCPost[] posts;

	this(NCUI ui, Tribune tribune) {
		this.ui = ui;
		this.tribune = tribune;
		this.tribune.on_new_post ~= &this.on_new_post;
	}

	void color(int c) {
		this._color = c;
	}

	ulong color(bool invert = false) {
		return COLOR_PAIR(invert ? this._color + 7 : this._color);
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
		NCPost p = new NCPost(this, post);
		this.posts ~= p;
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

	NCPost find_referenced_post(string clock) {
		foreach_reverse(NCPost post; this.posts) {
			if (post.post.clock == clock) {
				return post;
			}
		}

		return null;
	}
}

class NCPost {
	NCTribune tribune;
	Post post;

	int offset;
	int lines;

	this(NCTribune tribune, Post post) {
		this.tribune = tribune;
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
