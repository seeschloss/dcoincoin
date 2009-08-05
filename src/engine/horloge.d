module engine.horloge;

import common;

import std.date, std.utf;
import std.string, std.cstream;

class Horloge
	{
	public  Date	time;
	public  int	id;
	private char[]	time_string;
	private int	_indice;

	public this (char[] time_string, int id)
		{
		if (time_string !is null && time_string.length == 14)
			{
			time.year	= atoi (time_string[0  .. 4 ]);
			time.month	= atoi (time_string[4  .. 6 ]);
			time.day	= atoi (time_string[6  .. 8 ]);
			time.hour	= atoi (time_string[8  .. 10]);
			time.minute	= atoi (time_string[10 .. 12]);
			time.second	= atoi (time_string[12 .. 14]);

			this.time_string = time_string.dup;
			this.id = id;
			}
		}

	public int indice ()
		{
		return _indice;
		}

	public void indice (int i)
		{
		_indice = i;
		}

	public void set_indice (Horloge last_horloge)
		{
		if (last_horloge !is null && last_horloge.match (toString))
			{
			if (last_horloge.indice == 0)
				last_horloge.indice = 1;

			_indice = last_horloge.indice + 1;
			}
		}

	public char[] indice_string ()
		{
		if (indice > 3)
			{
			return format (":%s", indice);
			}
		else switch (indice)
			{
			case 0:
				return "";
			case 1:
				return "¹";
			case 2:
				return "²";
			case 3:
				return "³";
			default: // wtf ?
				return "";
			}
		}

	public char[] toString ()
		{
		return format ("%02s:%02s:%02s%s", time.hour, time.minute, time.second, indice_string);
		}

	public int opCmp (Object o)
		{
		Horloge horloge = cast(Horloge)o;
		return this.id - horloge.id;
		}

	public bool older_than (int id)
		{
		return this.id < id;
		}

	public bool match (char[] autre_horloge)
		{
		if (time_string.length == 14)
			{
			if (strlen (autre_horloge) == 5) // HH:mm
				{
				return (time_string[ 8 .. 10] == autre_horloge[ 0 ..  2])
				    && (time_string[10 .. 12] == autre_horloge[ 3 ..  5]);
				}
			else if (strlen (autre_horloge) == 8) // HH:mm:ss
				{
				return (time_string[ 8 .. 10] == autre_horloge[ 0 ..  2])
				    && (time_string[10 .. 12] == autre_horloge[ 3 ..  5])
				    && (time_string[12 .. 14] == autre_horloge[ 6 ..  8]);
				}
			else if (strlen (autre_horloge) == 9) // HH:mm:ss[¹²³]
				{
				if ((time_string[ 8 .. 10] == autre_horloge[ 0 ..  2])
				 && (time_string[10 .. 12] == autre_horloge[ 3 ..  5])
				 && (time_string[12 .. 14] == autre_horloge[ 6 ..  8]))
					{
					dchar[] autre_horloge_utf32 =  toUTF32 (autre_horloge);

					switch (autre_horloge_utf32[8])
						{
						case '\&sup1;':
							return indice == 1 || indice == 0;
						case '\&sup2;':
							return indice == 2;
						case '\&sup3;':
							return indice == 3;
						default:
							return false;
						}
					}
				else
					{
					return false;
					}
				}
			else if (strlen (autre_horloge) == 10) // HH:mm:ss:[1-9]
				{
				if ((time_string[ 8 .. 10] == autre_horloge[ 0 ..  2])
				 && (time_string[10 .. 12] == autre_horloge[ 3 ..  5])
				 && (time_string[12 .. 14] == autre_horloge[ 6 ..  8]))
					{
					return indice == autre_horloge[9] - '0' || indice == 0;
					}
				else
					{
					return false;
					}
				}
			else
				{
				return false;
				}
			}
		else
			{
			return false;
			}
		}
	}
