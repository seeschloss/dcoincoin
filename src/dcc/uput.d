module dcc.uput;

private import std.string;
private import std.utf : count;
private import std.conv;

private import deimos.ncurses.ncurses;

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
	int flag = 0, curspos = cast(int)whole.count, counter;
	dchar ky;
	bool exitflag=false;
	string tempwhole = cast(string)whole.dup;
	
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
				whole = cast(string)tempwhole.dup;
				flag = 5;
				exitflag = true;
				break;
			default:
				if (ins) {
					if (curspos < whole.length) {
						if (whole.length < length) {
							dstring utf32 = to!dstring(whole.dup);
							whole = to!string(utf32[0 .. curspos] ~ ky ~ utf32[curspos .. $]);
						} else {
							curspos--;
						}
					} else {
						whole ~= ky;
					}
				} else {
					if (curspos < whole.length) {
						dstring utf32 = to!dstring(whole.dup);
						whole = to!string(utf32[0 .. curspos] ~ ky ~ utf32[curspos .. $]);
					} else {
						whole ~= ky;
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
