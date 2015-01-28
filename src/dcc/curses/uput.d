module dcc.curses.uput;

private import std.string;
private import std.utf : count;
private import std.conv : to;

private import deimos.ncurses.ncurses;

int _uput_default_exit;
string uput(WINDOW* w, int y, int x, int length, string str, string prompt, out int exit = _uput_default_exit) {
/*
+------------------------[ WHAT YOU PUT IN ]-------------------------------+
|UPUT(y, x, length, fg, bg, str, exit)                                     |
+--------------------------------------------------------------------------+
|y -> Row where INPUT will start                                           |
|x -> Column where INPUT will start                                        |
|length -> Maximum length of INPUT                                         |
|str -> String to be edited                                                |
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
	int exitflag = 0, curspos = cast(int)str.count, counter;
	dchar ky;
	string original = cast(string)str.dup;

	string display = str;
	if (display.length > length) {
		display = display[0 .. length];
	}

	int original_x = x;
	x += prompt.count;

	keypad(w, true);

	void fill(char c) {
		wmove(w, y, original_x);
		for (counter=0; counter < length; counter++) {
			waddch(w, ' ');
		}
		wmove(w, y, x);
	}

	void print(string str, int offset = -1) {
		mvwprintw(w, y, original_x, "%s", prompt.toStringz());

		if (offset >= 0) {
			wmove(w, y, x + offset);
		}

		waddstr(w, str.toStringz());
	}

	void move(int offset) {
		wmove(w, y, x + offset);
	}

	int scroll_offset = 0;

	do {
		fill(' ');
		print(display);

		move(curspos);

		curs_set(2);
		
		wrefresh(w);
		wget_wch(w, &ky);
		
		switch (ky) {
			case KEY_LEFT:
				if (curspos > 0) {
					curspos--;
				} else if (scroll_offset > 0) {
					scroll_offset--;
				}

				break;
			case KEY_RIGHT:
				if (curspos < length - 1) {
					curspos++;
				} else if (str.count > length && scroll_offset + length <= str.count) {
					scroll_offset++;
				}
				break;
			case KEY_HOME:
				//case KEY_A1: =KEY_HOME on Linux so not required 
				curspos = 0;
				scroll_offset = 0;
				break;
			case KEY_END:
				//case KEY_C1: =KEY_END on Linux so not required
				str = str.stripRight();
				curspos = cast(int)str.count;
				if (curspos > length) {
					scroll_offset = curspos - length + 1;
					curspos = length - 1;
				}
				break;
			case KEY_DC: //delete key
				if (curspos > str.count - 1) {
					break;
				}

				dstring utf32 = to!dstring(str.dup);
				str = to!string(utf32[0 .. curspos] ~ utf32[curspos + 1 .. $]);
				break;
			case 127:
			case KEY_BACKSPACE:
				if (curspos > 0) {
					dstring utf32 = to!dstring(str.dup);
					str = to!string(utf32[0 .. curspos - 1] ~ utf32[curspos .. $]);
					curspos--;
				}
				break;
			case 10: // enter
				exitflag = 10;
				break;
			case KEY_UP: // up-arrow
				exitflag = 8;
				break;
			case KEY_DOWN: // down-arrow
				exitflag = 2;
				break;
			case 9: // tab
				exitflag = 6;
				break;
			case KEY_BTAB: // shift-tab
				exitflag = 4;
				break;
			case 27: //esc
				str = original;
				exitflag = 5;
				break;
			default:
				if (curspos < str.count) {
					dstring utf32 = to!dstring(str.dup);
					ulong pos = curspos + scroll_offset;
					str = to!string(utf32[0 .. pos] ~ ky ~ utf32[pos .. $]);
				} else {
					str ~= ky;
				}

				if (curspos >= length - 1) {
					scroll_offset++;
				} else {
					curspos++;
				}
		}

		dstring utf32 = to!dstring(str.dup);
		auto end = utf32.length < scroll_offset + length - 1 ? utf32.length : scroll_offset + length - 1;
		display = to!string(utf32[scroll_offset .. end]);
	} while (!exitflag);

	exit = exitflag;
	return str.stripRight();
}
