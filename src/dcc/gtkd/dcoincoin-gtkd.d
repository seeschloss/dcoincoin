module dcc.gtkd.main;

private import std.random;

private import std.stdio;
private import std.string;
private import std.conv;
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
private import gtk.ScrolledWindow;
private import gtk.MessageDialog;
private import gtk.Box;
private import gtk.TextView;
private import gtk.TreeView;
private import gtk.TreeViewColumn;
private import gtk.TreeIter;
private import gtk.TreeSelection;
private import gtk.TreeModelIF;
private import gtk.TreePath;
private import gtk.CellRendererText;
private import gtk.ListStore;
private import gtk.Widget;
private import gtk.CellRenderer;

private import gdk.Keymap;
private import gdk.Event;
private import gdk.Color;
private import gdk.RGBA;

private import gtkc.gtk;
private import gtkc.gtktypes;
private import glib.ConstructionException;
private import glib.Str;
private import glib.Timeout;

private import dcc.engine.conf;
private import dcc.engine.tribune;
private import dcc.gtkd.tribuneviewer;
private import dcc.gtkd.post;

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
	ui.showAll();
	ui.displayAllPosts();

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
	GtkTribune currentTribune;

	TribuneViewer viewer;
	TextView input;

	this(string config_file) {
		super("DCoinCoin");

		this.config_file = config_file;

		this.config = new Config(this.config_file);

		foreach (Tribune tribune ; this.config.tribunes) {
			GtkTribune gtkTribune = new GtkTribune(this, tribune);
			this.tribunes[tribune.name] = gtkTribune;
			this.tribune_names ~= tribune.name;
			this.currentTribune = gtkTribune;
		}

		this.setup();

		foreach (GtkTribune tribune ; this.tribunes) {
			tribune.fetch_posts({
				stderr.writeln("Posts fetched");
			});

			tribune.on_new_post ~= &this.addPost;
		}
	}

	void setup() {
		this.viewer = this.makeTribuneViewer();

		Box mainBox = new Box(GtkOrientation.VERTICAL, 0);
		mainBox.packStart(makeMenuBar(), false, false, 0);

		Paned paned = new Paned(GtkOrientation.HORIZONTAL);

		paned.add1(this.makeTribunesList());
		ScrolledWindow scrolledWindow = new ScrolledWindow(this.viewer);
		scrolledWindow.setPolicy(GtkPolicyType.NEVER, GtkPolicyType.ALWAYS);
		paned.add2(scrolledWindow);

		mainBox.packStart(paned, true, true, 0);

		this.input = makeTribuneInput();
		mainBox.packStart(input, false, false, 0);

		Statusbar statusbar = new Statusbar();
		mainBox.packStart(statusbar, false, false, 0);

		this.add(mainBox);
	}

	void post(string text, void delegate(bool) success) {
		bool result = this.currentTribune.tribune.post(text);
		success(result);
		this.currentTribune.fetch_posts();
	}

	TextView makeTribuneInput() {
		TextView input = new TextView();
		input.setEditable(true);
		input.setWrapMode(WrapMode.CHAR);

		input.addOnKeyPress((Event event, Widget source) {
			input.overrideBackgroundColor(GtkStateFlags.NORMAL, new RGBA(1, 1, 1, 1));
			GdkEventKey* key = event.key();
			//writeln("Key: ", key.keyval, " - ", Keymap.gdkKeyvalName(key.keyval));

			if (Keymap.gdkKeyvalName(key.keyval) == "Return") {
				string text = input.getBuffer().getText();
				this.post(text, (bool success) {
					if (success) {
						input.getBuffer().setText("");
					} else {
						input.overrideBackgroundColor(GtkStateFlags.NORMAL, new RGBA(1, 0.7, 0.7, 1));
					}
				});
				return true;
			}

			return false;
		});

		return input;
	}

	void addPost(GtkPost post) {
		this.viewer.renderPost(post);
		this.viewer.scrollToEnd();
	}

	void displayAllPosts() {
		GtkPost[] posts;
		foreach (GtkTribune tribune; this.tribunes) {
			posts ~= tribune.posts;
		}
		posts.sort!((a, b) {
			if (a.post.timestamp == b.post.timestamp) {
				return a.post.post_id < b.post.post_id;
			} else {
				return a.post.timestamp < b.post.timestamp;
			}
		});

		foreach (GtkPost post; posts) {
			this.viewer.renderPost(post);
		}

		// Why do I need that?
		new Timeout(100, {
			this.viewer.grabFocus();
			this.viewer.scrollToEnd();
			return false;
		}, false);
	}

	Box makeTribunesList() {
		ListStore listStore = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING, GType.INT]);

		TreeIter iterTop = listStore.createIter();
		
		// Please don't be too smart, you're making it difficult to use loops
		listStore.remove(iterTop);

		foreach (GtkTribune tribune; this.tribunes) {
			listStore.append(iterTop);
			listStore.set(iterTop, [0, 1, 2, 3], [tribune.tribune.name, tribune.color, "black", tribune.color]);
			listStore.setValue(iterTop, 4, 400);

			tribune.listStore = listStore;
			tribune.iter = iterTop.copy(iterTop);
		}

		TreeView tribunesList = new TreeView(listStore);
		tribunesList.setHeadersVisible(false);
		tribunesList.setRulesHint(false);
		tribunesList.setActivateOnSingleClick(false);

		TreeSelection ts = tribunesList.getSelection();
		ts.setMode(SelectionMode.NONE);

		tribunesList.addOnCursorChanged((TreeView treeView) {
			TreeModelIF treeModel = tribunesList.getModel();
			TreePath currentPath;
			TreeViewColumn currentColumn;
			tribunesList.getCursor(currentPath, currentColumn);

			TreeIter iter = new TreeIter();
			treeModel.getIterFirst(iter);
			do {
				listStore.setValue(iter, 4, 400);
			} while (treeModel.iterNext(iter));

			iter = new TreeIter();
			treeModel.getIter(iter, currentPath);
			listStore.setValue(iter, 4, 1000);

			string name = iter.getValueString(0);
			if (name in this.tribunes) {
				this.setCurrentTribune(this.tribunes[name]);
			}
		});

		TreeViewColumn column = new TribuneTreeViewColumn("Tribune", new CellRendererText());
		tribunesList.appendColumn(column);
		column.setResizable(false);

		TreeViewColumn column2 = new TribuneEnabledTreeViewColumn("Enabled", new CellRendererText());
		tribunesList.appendColumn(column2);
		column.setResizable(false);

		Box box = new Box(GtkOrientation.VERTICAL, 0);
		box.packStart(new TreeView(new ListStore([GType.STRING])), 1, 1, 0);
		box.packStart(tribunesList, 0, 0, 0);

		return box;
	}

	void setCurrentTribune(GtkTribune tribune) {
		this.currentTribune = tribune;
	}

	TribuneViewer makeTribuneViewer() {
		TribuneViewer viewer = new TribuneViewer();

		foreach (GtkTribune gtkTribune; this.tribunes) {
			viewer.registerTribune(gtkTribune);
		}

		return viewer;
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

class TribuneTreeViewColumn : TreeViewColumn {
	this(string header, CellRenderer renderer) {
		auto p = gtk_tree_view_column_new_with_attributes(
		Str.toStringz(header),
		renderer.getCellRendererStruct(),
		Str.toStringz("text"),
		0,
		Str.toStringz("cell-background"),
		1,
		Str.toStringz("foreground"),
		2,
		Str.toStringz("weight"),
		4,
		null);
		
		if(p is null)
		{
			throw new ConstructionException("null returned by gtk_tree_view_column_new_with_attributes");
		}

		super(p);
	}
}

class TribuneEnabledTreeViewColumn : TreeViewColumn {
	this(string header, CellRenderer renderer) {
		auto p = gtk_tree_view_column_new_with_attributes(
		Str.toStringz(header),
		renderer.getCellRendererStruct(),
		Str.toStringz("cell-background"),
		3,
		null);
		
		if(p is null)
		{
			throw new ConstructionException("null returned by gtk_tree_view_column_new_with_attributes");
		}

		super(p);
	}
}

class GtkTribune {
	Tribune tribune;
	GtkUI ui;
	GtkPost[] posts;
	string tag;

	void delegate(GtkPost)[] on_new_post;

	string color;

	bool updating;

	ListStore listStore;
	TreeIter iter;

	this(GtkUI ui, Tribune tribune) {
		this.ui = ui;
		this.tribune = tribune;

		this.tribune.on_new_post ~= (Post post) {
			GtkPost p = new GtkPost(this, post);
			this.posts ~= p;

			foreach (void delegate(GtkPost) f ; this.on_new_post) {
				f(p);
			}
		};

		this.color = tribune.color;
	}

	void fetch_posts(void delegate() callback = null) {
		this.updating = true;
		this.tribune.fetch_posts();
		stderr.writeln("Fetched");
		this.updating = false;
		if (callback) {
			callback();
		}
	}

	void fetch_posts_async(void delegate() callback = null) {
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

