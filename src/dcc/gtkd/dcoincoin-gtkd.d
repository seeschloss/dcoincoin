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
private import gtk.Menu;
private import gtk.MenuBar;
private import gtk.MenuItem;
private import gtk.AccelGroup;
private import gtk.Paned;
private import gtk.Statusbar;
private import gtk.MessageDialog;
private import gtk.Box;
private import gtk.TreeView;
private import gtk.TreeViewColumn;
private import gtk.TreeIter;
private import gtk.TreeSelection;
private import gtk.CellRendererText;
private import gtk.ListStore;

private import gtkc.gtktypes;

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

		this.config_file = config_file;

		this.config = new Config(this.config_file);

		foreach (Tribune tribune ; this.config.tribunes) {
			this.tribunes[tribune.name] = new GtkTribune(this, tribune);
			this.tribune_names ~= tribune.name;

			this.tribunes[tribune.name].fetch_posts({
				stderr.writeln("Posts fetched");
			});
		}

		this.setup();
		this.showAll();
	}

	void setup() {
		this.setBorderWidth(10);

		Box mainBox = new Box(GtkOrientation.VERTICAL, 0);
		mainBox.packStart(makeMenuBar(), false, false, 0);

		Paned paned = new Paned(GtkOrientation.HORIZONTAL);

		paned.add1(this.makeTribunesList());
		paned.add2(new Label("Add2"));

		mainBox.packStart(paned, true, true, 0);

		Statusbar statusbar = new Statusbar();
		mainBox.packStart(statusbar, false, false, 0);

		this.add(mainBox);
	}

	TreeView makeTribunesList() {
		ListStore listStore = new ListStore([GType.STRING]);

		TreeIter iterTop = listStore.createIter();
		
		// Please don't be too smart, you're making it difficult to use loops
		listStore.remove(iterTop);

		foreach (GtkTribune tribune; this.tribunes) {
			listStore.append(iterTop);
			listStore.set(iterTop, [0], [tribune.tribune.name]);
		}

		TreeView tribunesList = new TreeView(listStore);
		tribunesList.setHeadersVisible(false);
		tribunesList.setRulesHint(false);

		TreeSelection ts = tribunesList.getSelection();
		ts.setMode(SelectionMode.MULTIPLE);

		TreeViewColumn column = new TreeViewColumn("Tribune", new CellRendererText(), "text", 0);
		tribunesList.appendColumn(column);
		column.setResizable(false);
		column.setReorderable(true);
		column.setSortColumnId(0);
		column.setSortIndicator(false);

		return tribunesList;
	}

	MenuBar makeMenuBar() {
		AccelGroup accelGroup = new AccelGroup();
		this.addAccelGroup(accelGroup);

		MenuBar menuBar = new MenuBar();
		Menu menu = menuBar.append("_Tribunes");
		menu.append(new MenuItem(&onMenuActivate, "_Settings", "tribunes.settings", true, accelGroup, 's'));
		menu.append(new MenuItem(&onMenuActivate, "E_xit", "application.exit", true, accelGroup, 'x'));

		menu = menuBar.append("_Help");
		menu.append(new MenuItem(&onMenuActivate, "_About", "help.about", true, accelGroup, 'a', GdkModifierType.CONTROL_MASK | GdkModifierType.SHIFT_MASK));

		return menuBar;
	}

	void onMenuActivate(MenuItem menuItem) {
		string action = menuItem.getActionName();
		switch (action) {
			default:
				MessageDialog d = new MessageDialog(
					this,
					GtkDialogFlags.MODAL,
					MessageType.INFO,
					ButtonsType.OK,
					"You pressed menu item "~action);
				d.run();
				d.destroy();
			break;
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

