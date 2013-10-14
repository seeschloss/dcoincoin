module dcc.cli;

private import std.stdio;
private import std.string;
private import std.regex;
private import std.utf;
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

class NCUI {
	string config_file;
	Config config;
	NCTribune[string] tribunes;
	ulong active = 0;
	string[] tribune_names;

	WINDOW* posts_window;
	WINDOW* input_window;

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
		mvwprintw(this.input_window, 0, 2, "PLOP".toStringz());

		wrefresh(this.posts_window);
		wrefresh(this.input_window);

		scrollok(this.posts_window, true);
	}

	void set_status(string status) {
		mvwhline(this.input_window, 0, 0, 0, COLS);
		mvwprintw(this.input_window, 0, 2, this.tribune_names[this.active].toStringz());
		mvwprintw(this.input_window, 0, cast(int)(COLS - 2 - status.length), status.toStringz());

		wrefresh(this.input_window);
		wmove(this.input_window, 1, 0);
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
					auto remaining = this.tribunes.length - 1;
					foreach (NCTribune tribune; this.tribunes) {
						tribune.fetch_posts({
							remaining--;
							if (remaining == 0) {
								this.set_status("");
							}
						});
					}
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
					if (this.active < 0) {
						this.active = this.tribune_names.length - 1;
					}
					this.set_status("");
					break;
				default:
					echo();
					keypad(this.input_window, false);
					ungetch(ch);
					char[] buf;
					buf.length = 500;
					wgetnstr(this.input_window, buf.ptr, cast(int)buf.length);
					string str = to!string(buf.ptr);
					if (this.tribunes[this.tribune_names[this.active]].tribune.post(str)) {
						wclrtoeol(this.input_window);
						this.tribunes[this.tribune_names[this.active]].fetch_posts();
					} else {
						wclrtoeol(this.input_window);
					}
					break;
			}
		}

		endwin();
	}

	void display_post(NCPost post) {
		wscrl(this.posts_window, 1);

		int x = 0;
		string clock = post.post.clock;
		string user = post.post.login;

		mvwprintw(this.posts_window, this.posts_window.maxy, x, clock.toStringz());
		x += std.utf.count(clock);

		mvwprintw(this.posts_window, this.posts_window.maxy, x, " ");
		x += 1;

		wattron(this.posts_window, A_BOLD);
		mvwprintw(this.posts_window, this.posts_window.maxy, x, user.toStringz());
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
					mvwprintw(this.posts_window, this.posts_window.maxy, x, sub.toStringz());
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
}
