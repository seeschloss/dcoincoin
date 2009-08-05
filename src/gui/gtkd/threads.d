module gui.gtkd.threads;

import std.thread;
import std.boxer;
import std.random;
import std.cstream;
import std.c.time;

class BackgroundThread : Thread
	{
	private Box delegate (Box[]) to_execute;
	private void delegate (Box) callback;
	private Box[] arguments;

	this (Box delegate (Box[]) to_execute, Box[] arguments = null, void delegate (Box) callback = null)
		{
		this.to_execute = to_execute;
		this.callback   = callback;
		this.arguments  = arguments;
		}

	int run ()
		{
		if (to_execute)
			{
			Box result = to_execute (arguments);

			if (callback)
				{
				callback (result);
				}
			}

		return 0;
		}
	}

class TimerThread : Thread
	{
	private void delegate () reload_delegate;
	private void delegate (double) set_percent_delegate;

	double period = 10;

	int intermediary_steps = 255;

	bool pause = false;
	
	private bool _update_now = false;

	this (void delegate () reload, void delegate (double) set_percent = null)
		{
		this.reload_delegate = reload;
		this.set_percent_delegate = set_percent;

		period += (cast(double)std.random.rand())
					/
		          (cast(double)int.max);
		}

	int run ()
		{
		while (true)
			{
			if (reload_delegate)
				{
				BackgroundThread update_thread = new BackgroundThread (&wrapper, null, &reloaded);
				try
					{
					update_thread.start ();
					}
				catch (Exception e)
					{ // Hmm ?
					dout.writefln ("Update thread error: %s", e);
					delete update_thread;
					}

				for (int i = 0 ; i < intermediary_steps ; i++)
					{
					if (set_percent_delegate)
						{
						set_percent_delegate ((cast (double) i)
												/
						                      (cast (double) intermediary_steps));
						}

					if (_update_now)
						{
						_update_now = false;
						break;
						}

					if (pause)
						{
						i--;
						}

					usleep (cast (int) (period*1000*1000 / intermediary_steps));
					}
				}
			}

		return 0;
		}

	public void update_now ()
		{
		_update_now = true;
		}

	private Box wrapper (Box[] inbox)
		{
		if (reload_delegate)
			{
			pause = true;
			reload_delegate ();
			}

		return box(null);
		}

	private void reloaded (Box box)
		{
		pause = false;
		}
	}
