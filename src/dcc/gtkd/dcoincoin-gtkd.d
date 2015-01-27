module dcc.gtkd.main;

private import std.stdio;
private import std.string;
private import std.algorithm : filter, sort, find;
private import std.file : exists, copy;
private import std.process : environment;

private import core.thread;

private import gtk.Main;
private import gtk.Label;
private import gtk.MainWindow;

private import dcc.engine.conf;
private import dcc.engine.tribune;

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

	Main.init(args);

	GtkUI ui = new GtkUI(config_file);

	if (ui.tribunes.length == 0) {
		stderr.writeln("You should try to configure at least one tribune!");
	} else {
		Main.run();
	}
}

class GtkUI : MainWindow {
	string config_file;
	Config config;
	GtkTribune[string] tribunes;
	ulong active = 0;
	string[] tribune_names;

	this(string config_file) {
		super("DCoinCoin");
		setBorderWidth(10);
		add(new Label("Plop"));

		showAll();

		this.config_file = config_file;

		this.config = new Config(this.config_file);

		foreach (Tribune tribune ; this.config.tribunes) {
			this.tribunes[tribune.name] = new GtkTribune(this, tribune);
			this.tribune_names ~= tribune.name;

			this.tribunes[tribune.name].fetch_posts({
				stderr.writeln("Posts fetched");
			});
		}
	}
}

class GtkTribune {
	Tribune tribune;
	GtkUI ui;
	//GtkPost[] posts;

	bool updating;

	this(GtkUI ui, Tribune tribune) {
		this.ui = ui;
		this.tribune = tribune;
	}

	void fetch_posts(void delegate() callback = null) {
		while (this.updating) {
			core.thread.Thread.sleep(dur!("msecs")(50));
		}
		this.updating = true;
		core.thread.Thread t = new core.thread.Thread({
			this.tribune.fetch_posts();
			stderr.writeln("Fetched");
			this.updating = false;
			if (callback) {
				callback();
			}
		});
		t.start();
		t.join();
	}
}

