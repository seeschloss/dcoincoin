module dcc.curses.curses;

private import std.stdio;
private import std.string;
private import std.regex;
private import std.utf : count;
private import std.conv : to;
private import std.algorithm : sort, find;
private import std.file : exists, copy;
private import std.process : environment;

private import core.thread : Thread;
private import core.time : dur, msecs, Duration;

private import std.parallelism;

private import dcc.engine.conf;
private import dcc.engine.tribune;
private import dcc.curses.uput;

private import deimos.ncurses.ncurses;
private import deimos.ncurses.panel;

private static import std.utf;
private static import std.array;

extern (C) { char* setlocale(int category, const char* locale); }

void main(string[] args) {
	setlocale(0, "".toStringz());

	string config_file = environment.get("HOME") ~ "/.dcoincoinrc";

	if (!config_file.exists()) {
		foreach (string prefix; ["/usr", "/usr/local"]) {
			string rc = prefix ~ "/share/doc/dcoincoin/dcoincoinrc";
			if (rc.exists()) {
				try {
					rc.copy(config_file);
					stderr.writeln("Initialized ", config_file, " with ", rc, ".");
					break;
				}
				catch (Exception e) {
					// Nothing special to do here.
				}
			}
		}
	}

	if (args.length == 2) {
		config_file = args[1];
	}

	if (!config_file.exists()) {
		stderr.writeln("Configuration file ", config_file, " does not exist.");
		return;
	}

	NCUI ui = new NCUI(config_file);

	if (ui.tribunes.length == 0) {
		endwin();
		stderr.writeln("You should try to configure at least one tribune!");
	} else {
		ui.loop();
	}
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
	NCTribune[] tribunes_ordered;
	Duration[NCTribune] reload_remaining;
	ulong active = 0;

	WINDOW* posts_window;
	WINDOW* input_window;
	WINDOW* preview_window;

	PANEL* main_panel;
	PANEL* preview_panel;

	Stop current_stop;
	Stop[] stops;
	int offset;

	ulong[string] colors;

	bool display_enabled = false;

	this(string config_file) {
		this.config_file = config_file;

		this.config = new Config(this.config_file);

		this.init_ui();

		int n = 2;
		// Create all tribunes, then fetch their posts without displaying
		// them, and once all this is done then display the latest posts.
		foreach (Tribune tribune ; this.config.tribunes) {
			this.tribunes[tribune.name] = new NCTribune(this, tribune);

			this.tribunes[tribune.name].color = n;
			n++;
			if (n >= 7) {
				n = 2;
			}
		}

		this.tribunes_ordered = this.tribunes.values;

		foreach (ref tribune; this.tribunes.values) {
			tribune.tribune.fetch_posts();

			n_tribunes--;

			if (n_tribunes == 0) {
				this.display_all_posts();
				this.posts_to_display.length = 0;
			}
		}
		
		this.display_all_posts();
		this.start_timers();
	}

	void reload_tick() {
		foreach (tribune ; this.tribunes) {
			if (tribune !in this.reload_remaining) {
				this.reload_remaining[tribune] = dur!("seconds")(tribune.tribune.refresh);
			}

			this.reload_remaining[tribune] -= 10.msecs;

			if (this.reload_remaining[tribune] <= 0.msecs) {
				tribune.fetch_posts();
				this.reload_remaining[tribune] = dur!("seconds")(tribune.tribune.refresh);
			}
		}

		this.set_status("");
	}

	void redraw_all_posts() {
		endwin();
		refresh();
		this.init_ui();
		this.display_all_posts();
	}

	void display_all_posts() {
		this.stops.length = 0;
		this.current_stop = Stop.init;
		this.offset = 0;
		NCPost[] posts;
		foreach (NCTribune tribune; this.tribunes) {
			posts ~= tribune.posts;
		}

		if (posts.length > 0) {
			posts.sort!((a, b) {
				if (a.post.timestamp == b.post.timestamp) {
					return a.post.post_id < b.post.post_id;
				} else {
					return a.post.timestamp < b.post.timestamp;
				}
			});

			this.display_enabled = true;
			if (this.posts_window.maxy > 0) {
				auto start = this.posts_window.maxy > posts.length ? 0 : posts.length - this.posts_window.maxy;
				foreach (NCPost post; posts[$-this.posts_window.maxy .. $]) {
					this.display_post(this.posts_window, post, true, false);
				}
			}

			set_stop(this.stops[$ - 1]);
		}
	}

	void start_timers() {
		task({
			this.display_enabled = true;
			while (true) {
				Thread.sleep(10.msecs);
				this.reload_tick();
			}
		}).executeInNewThread();
	}

	void init_ui() {
		initscr();
		start_color();
		this.init_colors();

		curs_set(0);

		int input_height = 2;

		this.posts_window = newwin(LINES - input_height, 0, 0, 0);
		this.input_window = newwin(2, 0, LINES - input_height, 0);

		this.preview_window = newwin(4, 0, 0, 0);

		this.main_panel = new_panel(posts_window);
		this.preview_panel = new_panel(preview_window);

		top_panel(this.main_panel);
		update_panels();
		doupdate();

		mvwhline(this.input_window, 0, 0, 0, COLS);

		wrefresh(this.posts_window);
		wrefresh(this.input_window);

		scrollok(this.posts_window, true);
	}

	void init_colors() {
		init_pair( 1, COLOR_WHITE,   COLOR_BLACK);
		init_pair( 2, COLOR_RED,     COLOR_BLACK);
		init_pair( 3, COLOR_GREEN,   COLOR_BLACK);
		init_pair( 4, COLOR_YELLOW,  COLOR_BLACK);
		init_pair( 5, COLOR_BLUE,    COLOR_BLACK);
		init_pair( 6, COLOR_MAGENTA, COLOR_BLACK);
		init_pair( 7, COLOR_CYAN,    COLOR_BLACK);

		init_pair( 8, COLOR_WHITE, COLOR_WHITE  );
		init_pair( 9, COLOR_WHITE, COLOR_RED    );
		init_pair(10, COLOR_WHITE, COLOR_GREEN, );
		init_pair(11, COLOR_WHITE, COLOR_YELLOW );
		init_pair(12, COLOR_WHITE, COLOR_BLUE   );
		init_pair(13, COLOR_WHITE, COLOR_MAGENTA);
		init_pair(14, COLOR_WHITE, COLOR_CYAN   );

		this.colors["white"]   = COLOR_PAIR(1);
		this.colors["red"]     = COLOR_PAIR(2);
		this.colors["green"]   = COLOR_PAIR(3);
		this.colors["yellow"]  = COLOR_PAIR(4);
		this.colors["blue"]    = COLOR_PAIR(5);
		this.colors["magenta"] = COLOR_PAIR(6);
		this.colors["cyan"]    = COLOR_PAIR(7);

		this.colors["rev-white"]   = COLOR_PAIR(8);
		this.colors["rev-red"]     = COLOR_PAIR(9);
		this.colors["rev-green"]   = COLOR_PAIR(10);
		this.colors["rev-yellow"]  = COLOR_PAIR(11);
		this.colors["rev-blue"]    = COLOR_PAIR(12);
		this.colors["rev-magenta"] = COLOR_PAIR(13);
		this.colors["rev-cyan"]    = COLOR_PAIR(14);
	}

	void set_status(string status) {
		synchronized(this) {
			int y, x;
			getyx(this.input_window, y, x);

			mvwhline(this.input_window, 0, 0, 0, COLS);

			int col = 2;

			foreach (i, tribune; this.tribunes_ordered) {
				if (i == this.active) {
					auto style = tribune.updating ? A_REVERSE | A_BOLD : A_REVERSE;
					mvwprintw(this.input_window, 0, col, "%s", tribune.tribune.name.toStringz());
					mvwchgat(this.input_window, 0, col, cast(int)tribune.tribune.name.length, style, cast(short)tribune.ncolor(false), cast(void*)null);

					col += cast(int)tribune.tribune.name.length + 1;
				} else {
					auto style = tribune.updating ? A_REVERSE : A_BOLD;
					mvwprintw(this.input_window, 0, col, "%s", tribune.tribune.name[0 .. 1].toStringz());
					mvwchgat(this.input_window, 0, col, 1, style, cast(short)tribune.ncolor(false), cast(void*)null);

					col += 2;
				}
			}

			mvwprintw(this.input_window, 0, cast(int)(COLS - 2 - status.length), "%s", status.toStringz());

			wmove(this.input_window, y, x);
			wrefresh(this.input_window);
		}
	}

	void highlight_post(NCPost post, NCPost origin) {
		if (post.offset > this.offset - this.posts_window.maxy) {
			int line = this.posts_window.maxy - (this.offset - post.offset);
			mvwprintw(this.posts_window, line, 0, ">");
			mvwchgat(this.posts_window, line, 0, 1 + 8, A_BOLD, cast(short)post.tribune.ncolor(true), cast(void*)null);
			wnoutrefresh(this.posts_window);
		}

		int scrollresult = scrollok(this.preview_window, true);

		int result1 = wclear(this.preview_window);
		int result2 = wresize(this.preview_window, post.lines, COLS);
		append_post(this.preview_window, post, false, 0);
		wresize(this.preview_window, post.lines + 1, COLS);
		mvwhline(this.preview_window, post.lines, 0, 0, COLS);

		wnoutrefresh(this.preview_window);
		top_panel(this.preview_panel);
		update_panels();
		doupdate();
	}

	void show_info(NCPost post) {
		synchronized(this) {
			wmove(this.input_window, 1, 0);
			wclrtoeol(this.input_window);
		}
		string post_info = format("[%s] id=%s ua=%s", post.tribune.tribune.name, post.post.post_id, post.post.info);
		if (post_info.count > this.input_window.maxx) {
			post_info = post_info[0 .. this.input_window.maxx];
		}
		mvwprintw(this.input_window, 1, 0, "%s", post_info.toStringz());
		wrefresh(this.input_window);
	}

	void unhighlight_post(NCPost post) {
		if (post.offset > this.offset - this.posts_window.maxy) {
			int line = this.posts_window.maxy - (this.offset - post.offset);
			mvwprintw(this.posts_window, line, 0, " ");
			mvwchgat(this.posts_window, line, 0, 1, A_NORMAL, cast(short)post.tribune.ncolor(true), cast(void*)null);
			mvwchgat(this.posts_window, line, 1, 8, A_NORMAL, cast(short)1, cast(void*)null);
			wnoutrefresh(this.posts_window);
		}

		top_panel(this.main_panel);
		update_panels();
		doupdate();
	}

	void highlight_stop(Stop stop) {
		if (stop == Stop.init) {
			return;
		}

		int line = this.posts_window.maxy - (this.offset - stop.offset);
		wmove(this.posts_window, line, stop.start);
		wchgat(this.posts_window, stop.length, A_REVERSE, 0, null);

		wmove(this.input_window, 1, 0);
		wnoutrefresh(this.posts_window);
		wnoutrefresh(this.input_window);

		if (stop.referenced_post) {
			this.highlight_post(stop.referenced_post, stop.post);
		}

		show_info(stop.post);
	}

	void unhighlight_stop(Stop stop) {
		int line = this.posts_window.maxy - (this.offset - stop.offset);
		wmove(this.posts_window, line, stop.start);

		wchgat(this.posts_window, stop.length, stop.attributes, stop.color, null);

		wmove(this.input_window, 1, 0);
		wnoutrefresh(this.posts_window);
		wnoutrefresh(this.input_window);

		if (stop.referenced_post) {
			this.unhighlight_post(stop.referenced_post);
		} else {
			doupdate();
		}
	}

	void loop() {
		scope (exit) {
			endwin();
		}

		this.set_status("");

		while (true) {
			wtimeout(this.input_window, 100);
			wmove(this.input_window, 1, 0);

			noecho();
			keypad(this.input_window, true);
			auto ch = wgetch(this.input_window);
			switch (ch) {
				case KEY_RESIZE:
					this.redraw_all_posts();
					this.set_status("");
					break;
				case 0x20:
					this.set_status("O");
					this.tribunes_ordered[this.active].fetch_posts();
					this.set_status("");
					break;
				case KEY_RIGHT:
					this.active++;
					if (this.active >= this.tribunes_ordered.length) {
						this.active = 0;
					}
					this.set_status("");
					break;
				case KEY_LEFT:
					this.active--;
					// This should be an ulong, but the compiler will optimize
					// this out anyway, and it's cleared and safer.
					if (this.active < 0 || this.active >= this.tribunes_ordered.length) {
						this.active = this.tribunes_ordered.length - 1;
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
						// We're at the bottom... unselect everything.
						unhighlight_stop(this.current_stop);
						this.current_stop = Stop.init;
					}
					break;
				case KEY_HOME:
					foreach (Stop stop; this.stops) {
						if (stop.offset >= this.offset - this.posts_window.maxy) {
							if ((stop.offset < this.current_stop.offset) ||
									(stop.offset == this.current_stop.offset && stop.start < this.current_stop.start)) {
								set_stop(stop);
								break;
							}
						}
					}
					break;
				case KEY_END:
					set_stop(this.stops[$ - 1]);
					break;
				case 0x0A:
					string initial_text = this.current_stop !is Stop.init ? this.current_stop.post.post.clock_ref ~ " " : "";

					if (this.current_stop !is Stop.init) {
						foreach (n, tribune; this.tribunes_ordered) {
							if (tribune == this.current_stop.post.tribune) {
								this.active = n;
							}
						}
						this.set_status("");
					}

					wtimeout(this.input_window, -1);
					int exit = 1;
					curs_set(2);
					string text = uput(this.input_window, 1, 0, COLS - 2, initial_text, "> ", exit);
					curs_set(0);
					if (exit == 10 && this.tribunes_ordered[this.active].tribune.post(text)) {
						this.tribunes_ordered[this.active].fetch_posts();
					}
					wmove(this.input_window, 1, 0);
					wclrtoeol(this.input_window);
					wrefresh(this.input_window);
					break;
				default:
					this.display_queued_posts();
					break;
			}
		}
	}

	void adjust_stop() {
		if (this.current_stop.offset < this.offset - this.posts_window.maxy + 1) {
			next_stop();
		}
		highlight_stop(this.current_stop);
	}

	bool prev_stop() {
		Stop new_stop;
		Stop old_stop = this.current_stop;
		if (this.current_stop is Stop.init && this.stops.length) {
			new_stop = this.stops[$ - 1];
		} else foreach_reverse (Stop stop; this.stops) {
			if (stop.offset >= this.offset - this.posts_window.maxy) {
				if ((stop.offset < this.current_stop.offset) ||
					(stop.offset == this.current_stop.offset && stop.start < this.current_stop.start)) {
					new_stop = stop;
					break;
				}
			}
		}

		if (new_stop != Stop.init) {
			this.set_stop(new_stop);
			return true;
		}

		return false;
	}

	bool next_stop() {
		if (this.current_stop == Stop.init) {
			return false;
		}

		if (this.current_stop == this.stops[$ - 1]) {
			return false;
		}

		Stop new_stop;
		Stop old_stop = this.current_stop;
		if (this.current_stop is Stop.init) foreach (Stop stop; this.stops) {
			if (stop.offset > this.offset - this.posts_window.maxy) {
				new_stop = stop;
				break;
			}
		} else foreach (Stop stop; this.stops) {
			if (stop.offset > this.offset - this.posts_window.maxy) {
				if ((stop.offset > this.current_stop.offset) ||
					(stop.offset == this.current_stop.offset && stop.start > this.current_stop.start)) {
					new_stop = stop;
					break;
				}
			}
		}

		if (new_stop != Stop.init) {
			this.set_stop(new_stop);
		}

		return true;
	}

	void set_stop(Stop stop) {
		this.unhighlight_stop(this.current_stop);
		this.current_stop = stop;
		this.highlight_stop(this.current_stop);
	}

	int append_post(WINDOW* window, NCPost post, bool add_stops, int offset) {
		int offset_start = offset;
		offset++;

		wscrl(window, 1);

		int x = 0;
		string clock = post.post.clock;

		mvwprintw(window, window.maxy, x, " ");
		mvwchgat(window, cast(int)window.maxy, x, 1, A_NORMAL, cast(short)post.tribune.ncolor(true), cast(void*)null);
		x += 1;
		mvwprintw(window, window.maxy, x, "%s", clock.toStringz());
		int clock_len = cast(int)std.utf.count(clock);
		ulong current_attributes;
		short pair;
		int opts;
		wattr_get(window, &current_attributes, &pair, cast(void*)&opts);

		Stop post_stop = Stop(offset, x, clock_len, post, current_attributes, pair);
		x += clock_len;

		mvwprintw(window, window.maxy, x, " ");
		x += 1;

		if (post.post.login.length > 0) {
			int count = cast(int) post.post.login.count;
			mvwprintw(window, window.maxy, x, "%s", post.post.login.toStringz());
			mvwchgat(window, cast(int)window.maxy, x, count, A_BOLD, cast(short)0, cast(void*)null);
			x += count;
		} else {
			int count = cast(int) post.post.short_info.count;
			mvwprintw(window, window.maxy, x, "%s", post.post.short_info.toStringz());
			mvwchgat(window, cast(int)window.maxy, x, count, this.colors["rev-white"] | A_REVERSE | A_BOLD, cast(short)0, cast(void*)null);
			x += count;
		}

		mvwprintw(window, window.maxy, x, "> ");
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
			if (x + length >= COLS && length <= (COLS - 2)) {
				x = 2;
				wscrl(window, 1);
				offset++;

				// Add leading color marker
				mvwprintw(window, window.maxy, 0, " ");
				mvwchgat(window, cast(int)window.maxy, 0, 1, A_NORMAL, cast(short)post.tribune.ncolor(true), cast(void*)null);

				wmove(window, window.maxy, 1);
			}

			bool is_clock = false;

			foreach (Clock post_clock; post.post.clocks) {
				if (sub.strip == post_clock.text) {
					NCTribune ref_tribune = post.tribune;

					wattr_get(window, &current_attributes, &pair, cast(void*)&opts);
					if (!(current_attributes & A_BOLD)) {
						wattron(window, A_BOLD);
						is_clock = true;
					}

					has_clocks = true;

					wattr_get(window, &current_attributes, &pair, cast(void*)&opts);

					if (add_stops) {
						if (post_clock.tribune.length > 1) {
							if (post_clock.tribune in this.tribunes) {
								ref_tribune = this.tribunes[post_clock.tribune];
							} else foreach (NCTribune t; this.tribunes) {
								if (find(t.tribune.aliases, post_clock.tribune).length > 0) {
									ref_tribune = t;
									break;
								}
							}
						}

						this.stops ~= Stop(offset, x, cast(int)sub.count, post, current_attributes, pair, ref_tribune.find_referenced_post(post_clock.time, post_clock.index));
					}
				}
			}

			switch (sub.strip()) {
				case "<b>":
					wattron(window, A_BOLD);
					break;
				case "</b>":
					wattroff(window, A_BOLD);
					break;
				case "<i>":
					wattron(window, this.colors["cyan"]);
					break;
				case "</i>":
					wattroff(window, this.colors["cyan"]);
					break;
				case "<u>":
					wattron(window, A_UNDERLINE);
					break;
				case "</u>":
					wattroff(window, A_UNDERLINE);
					break;
				default:
					mvwprintw(window, window.maxy, x, "%s", sub.toStringz());
					x += length;
					break;
			}

			if (is_clock) {
				wattroff(window, A_BOLD);
			}

			if (length >= (COLS - 2)) {
				// Then the text will have wrapped several times.
				offset += x/COLS;
				x = x%COLS;
			}
		}

		if (!has_clocks && add_stops) {
			this.stops ~= post_stop;
		}

		wattrset(window, A_NORMAL);

		wrefresh(window);

		post.lines = offset - offset_start;

		foreach (int i, Stop stop; this.stops) {
			if (stop.offset < offset_start - (LINES * 10) && i+1 < this.stops.length) {
				this.stops = this.stops[0 .. i] ~ this.stops[i+1 .. $];
			}
		}

		return offset;
	}

	NCPost[] posts_to_display;
	void enqueue_post(NCPost post) {
		this.posts_to_display ~= post;
	}

	void display_queued_posts() {
		foreach (NCPost post; this.posts_to_display) {
			this.display_post(this.posts_window, post);
		}

		this.posts_to_display.length = 0;
	}

	void display_post(WINDOW* window, NCPost post, bool add_stops = true, bool scroll = true) {
		if (this.display_enabled && !this.is_post_ignored(post)) {
			synchronized(this) {
				post.offset = this.offset + 1;

				this.offset = append_post(window, post, add_stops, this.offset);
				if (scroll) {
					adjust_stop();
				}
			}
		}
	}

	NCPost[] ignored_posts;

	bool is_post_ignored(NCPost post) {
		if (this.config.default_ignorelist.find(post.post.login).length > 0
		 || this.config.default_ignorelist.find(post.post.info).length > 0) {
			this.ignored_posts ~= post;

			return true;
		}

		foreach (Clock clock; post.post.clocks) {
			NCTribune ref_tribune = post.tribune;
			if (clock.tribune in this.tribunes) {
				ref_tribune = this.tribunes[clock.tribune];
			} else foreach (NCTribune t; this.tribunes) {
				if (find(t.tribune.aliases, clock.tribune).length > 0) {
					ref_tribune = t;
					break;
				}
			}

			if (ref_tribune.find_referenced_post(clock.time, clock.index, this.ignored_posts)) {
				this.ignored_posts ~= post;

				return true;
			}
		}

		return false;
	}
}

class NCTribune {
	Tribune tribune;
	NCUI ui;
	int _color;
	NCPost[] posts;

	bool updating;

	this(NCUI ui, Tribune tribune) {
		this.ui = ui;
		this.tribune = tribune;
		this.tribune.new_post.connect(&this.on_new_post);
	}

	void color(int c) {
		this._color = c;
	}

	ulong color(bool invert = false) {
		return COLOR_PAIR(invert ? this._color + 7 : this._color);
	}

	int ncolor(bool invert = false) {
		return invert ? this._color + 7 : this._color;
	}

	void on_new_post(Post post) {
		NCPost p = new NCPost(this, post);
		this.posts ~= p;

		if (this.posts.length > LINES * 10) {
			this.posts = this.posts[1 .. $];
		}

		this.ui.enqueue_post(p);
	};

	auto fetch_posts() {
		this.updating = true;

		try {
			this.tribune.fetch_posts();
			this.tribune.prune_old_posts(LINES);
		} catch (Exception e) {
		}

		this.updating = false;
	}

	NCPost find_referenced_post(string clock, int index = 1, NCPost[] posts = null) {
		if (posts is null) {
			posts = this.posts;
		}

		NCPost[] matching;
		foreach_reverse(NCPost post; posts) {
			if (clock.length > 5 && post.post.clock == clock) {
				matching ~= post;
			} else if (clock.length == 5 && post.post.clock[0 .. 5] == clock) {
				matching ~= post;
			} else if (matching.length > 0) {
				// We have already found at least one matching post,
				// and this one doesn't match, so any further matching
				// post would be an older, not consecutive, post.
				break;
			}
		}

		index = cast(int)(matching.length - index);

		if (index >= 0) {
			return matching[index];
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

		// Since I can't use backreferences here...
		line = line.replace(regex(`<a href="(.*?)".*?>(.*?)</a>`, "g"), "<$1>");
		line = line.replace(regex(`<a href='(.*?)'.*?>(.*?)</a>`, "g"), "<$1>");

		line = std.array.replace(line, "&lt;", "<");
		line = std.array.replace(line, "&gt;", ">");
		line = std.array.replace(line, "&amp;", "&");

		string[] tokens = [""];

		bool next = false;
		foreach (char c; line) {
			switch (c) {
				case '<':
					tokens ~= "";
					break;
				case '{':
				case '[':
				case '(':
				case ' ':
				case ',':
					tokens ~= "";
					next = true;
					break;
				case ']':
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
