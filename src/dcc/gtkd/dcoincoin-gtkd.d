module dcc.gtkd.main;

private import std.random;

private import std.stdio;
private import std.string;
private import std.conv;
private import std.algorithm : filter, sort, find, uniq, map;
private import std.file : exists, copy;
private import std.process : environment;
private import std.array : array;
private import std.signals;

private import core.memory;
private import core.thread;

private import gtk.Main;
private import gtk.Label;
private import gtk.MainWindow;
private import gtk.Menu;
private import gtk.MenuBar;
private import gtk.MenuItem;
private import gtk.AccelGroup;
private import gtk.Paned;
private import gtk.ScrolledWindow;
private import gtk.MessageDialog;
private import gtk.Box;
private import gtk.TextView;
private import gtk.TextIter;
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
private import gtk.MountOperation;
private import gtk.Overlay;

private import gdk.Keymap;
private import gdk.Event;
private import gdk.Color;
private import gdk.Cursor;
private import gdk.RGBA;
private import gdk.Threads;

private import gtkc.gtk;
private import gtkc.gtktypes;
private import gtkc.glib;
private import gtkc.glibtypes;

private import glib.ConstructionException;
private import glib.Str;
private import glib.Timeout;
private import glib.Idle;

private import dcc.engine.conf;
private import dcc.engine.tribune;
private import dcc.gtkd.tribuneviewer;
private import dcc.gtkd.tribuneinput;
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

	if (ui.tribunes.length == 0) {
		stderr.writeln("You should try to configure at least one tribune!");
	} else {
		Main.run();
	}
}

public class DCCIdle {
	void delegate() f;
	uint idleID;

	static DCCIdle[] idles;
	
	this(void delegate() f) {
		this.f = f;
		idleID = g_idle_add(cast(GSourceFunc)&idleCallback, cast(void*)this);
		idles ~= this;
	}
	
	public void stop() {
		g_source_remove(idleID);
		this.f = null;
	}
	
	~this() {
		stop();
	}
	
	extern(C) static bool idleCallback(DCCIdle idle) {
		return idle.callAllListeners();
	}
	
	private bool callAllListeners() {
		this.f();
		return false;
	}
}

public class DCCTimeout {
	void delegate() f;
	uint timeoutID;
	
	this(uint timeout, void delegate() f) {
		this.f = f;
		timeoutID = g_timeout_add(timeout, cast(GSourceFunc)&timeoutCallback, cast(void*)this);
		//GC.removeRange(this);
	}
	
	public void stop() {
		g_source_remove(timeoutID);
		this.f = null;
	}
	
	~this() {
		stop();
	}
	
	extern(C) static bool timeoutCallback(DCCTimeout timeout) {
		return timeout.callAllListeners();
	}
	
	private bool callAllListeners() {
		this.f();
		return true;
	}
}

class GtkUI : MainWindow {
	string config_file;
	Config config;
	GtkTribune[string] tribunes;
	ulong active = 0;
	string[] tribune_names;
	GtkTribune currentTribune;

	TribuneMainViewer viewer;
	TribuneInput input;
	ScrolledWindow inputScroll;
	TreeView tribunesList;
	ListStore tribunesListStore;
	Overlay overlay;
	TribunePreviewer preview;

	DCCTimeout renderTimeout, reloadTimeout;

	GtkPost latestPost;

	this(string config_file) {
		super("DCoinCoin");

		this.config_file = config_file;

		this.config = new Config(this.config_file);

		foreach (Tribune tribune ; this.config.tribunes) {
			GtkTribune gtkTribune = new GtkTribune(this, tribune);
			gtkTribune.newPost.connect(&addPost);
			this.tribunes[tribune.name] = gtkTribune;
			this.tribune_names ~= tribune.name;
			this.currentTribune = gtkTribune;
		}

		this.setup();

		foreach (GtkTribune tribune ; this.tribunes) {
			this.reloadRemaining[tribune] = 0;
		}

		this.setCurrentTribune(this.tribunes.values[$-1]);
		this.reloadRemaining[this.tribunes.values[$-1]] = 0;

		this.reloadTimeout = new DCCTimeout(100, {
			this.reloadTick();
		});

		this.renderTimeout = new DCCTimeout(100, {
			this.renderPostsQueue();
		});
	}

	int[GtkTribune] reloadRemaining;

	void reloadTick() {
		foreach (GtkTribune tribune ; this.tribunes) {
			this.reloadRemaining[tribune]--;

			if (this.reloadRemaining[tribune] <= 0 && !tribune.updating) {
				new Thread({
					tribune.fetch_posts({
						this.reloadRemaining[tribune] = 100;
					});
				}).start();
			}
		}
	}

	override void showAll() {
		super.showAll();
		this.inputScroll.setSizeRequest(0, this.input.lineHeight() * 3);
	}

	void setup() {
		this.viewer = this.makeTribuneMainViewer();
		this.preview = this.makeTribunePreviewer();

		Box mainBox = new Box(GtkOrientation.VERTICAL, 0);
		mainBox.packStart(makeMenuBar(), false, false, 0);

		Paned paned = new Paned(GtkOrientation.HORIZONTAL);

		paned.add1(this.makeTribunesList());
		ScrolledWindow scrolledWindow = new ScrolledWindow(this.viewer);
		scrolledWindow.setPolicy(GtkPolicyType.NEVER, GtkPolicyType.ALWAYS);

		this.overlay = new Overlay();
		this.overlay.add(scrolledWindow);
		this.overlay.addOverlay(this.preview);

		paned.add2(this.overlay);

		mainBox.packStart(paned, true, true, 0);

		this.input = makeTribuneInput();
		this.inputScroll = new ScrolledWindow(this.input);
		this.inputScroll.setPolicy(GtkPolicyType.NEVER, GtkPolicyType.ALWAYS);
		mainBox.packStart(this.inputScroll, false, false, 0);

		this.add(mainBox);
	}

	void post(string text, void delegate(bool) success) {
		bool result = this.currentTribune.tribune.post(text);
		success(result);
		this.currentTribune.fetch_posts();
	}

	TribuneInput makeTribuneInput() {
		TribuneInput input = new TribuneInput();

		input.addOnKeyPress((Event event, Widget source) {
			GdkEventKey* key = event.key();

			if (Keymap.keyvalName(key.keyval) == "Return") {
				string text = input.getBuffer().getText();
				input.setProperty("editable", false);
				auto post_comment = {
					this.post(text, (bool success) {
						if (success) {
							new DCCIdle({
								input.getBuffer().setText("");
								input.setProperty("editable", true);
							});
						} else {
							new DCCIdle({
								input.setProperty("editable", true);
							});
						}
					});
				};
				new Thread(post_comment).start();
				return true;
			}

			return false;
		});

		return input;
	}

	void updatePost(GtkPost post) {
		post.referencedPosts = this.findReferencedPosts(post);

		foreach (GtkPost referencedPost ; post.referencedPosts) {
			referencedPost.referencingPosts[post] = post;
		}

		post.checkIfAnswer();

		/*
		if (this.latestPost && post.post.real_time < (this.latestPost.post.real_time - this.latestPost.post.tribune.last_update)) {
			post.post.tribune.unreliable_date = true;
			post.post.tribune.time_offset = this.latestPost.post.real_time - this.latestPost.post.tribune.last_update - post.post.time;
			post.post.real_time = this.latestPost.post.real_time + 1.msecs;
		}
		*/

		this.latestPost = post;
	}

	void addPost(GtkPost post) {
		this.updatePost(post);
		synchronized(this.renderTimeout) {
			postsQueue ~= post;
		}
	}

	GtkPost[] postsQueue;

	void renderPostsQueue() {
		if (this.postsQueue.length > 0) {
			bool scroll = viewer.isScrolledDown();
			synchronized(this.renderTimeout) {
				foreach (GtkPost post; this.postsQueue) {
					this.viewer.renderPost(post);
				}
				this.postsQueue = typeof(this.postsQueue).init;
			}
			if (scroll) {
				viewer.scrollToEnd();
			}
		}
	}

	GtkPostSegment[] findReferencesToPost(GtkPost post) {
		GtkPostSegment[] segments;

		foreach (GtkTribune tribune ; this.tribunes) {
			segments ~= tribune.findReferencesToPost(post);
		}

		return segments;
	}

	GtkPost[] findReferencedPosts(GtkPost origin) {
		GtkPost[] posts;

		foreach (GtkTribune tribune ; this.tribunes) {
			foreach (GtkPostSegment segment ; origin.segments) {
				if (tribune.tribune.matches_name(segment.context.clock.tribune)) {
					posts ~= tribune.findPostsByClock(segment);
				}
			}
		}

		return posts.uniq.array;
	}

	Box makeTribunesList() {
		ListStore listStore = new ListStore([GType.STRING, GType.STRING, GType.STRING, GType.STRING, GType.INT]);
		this.tribunesListStore = listStore;

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

		this.tribunesList = tribunesList;

		TreeSelection ts = tribunesList.getSelection();
		ts.setMode(SelectionMode.NONE);

		tribunesList.addOnButtonPress((Event event, Widget widget) {
			switch (event.button.button) {
				case 1:
					return false;
				case 2:
					TreeModelIF treeModel = tribunesList.getModel();
					TreePath currentPath;
					TreeViewColumn currentColumn;
					int cellX, cellY;
					tribunesList.getPathAtPos(cast(int)event.button.x, cast(int)event.button.y, currentPath, currentColumn, cellX, cellY);

					TreeIter iter = new TreeIter();
					iter = new TreeIter();
					treeModel.getIter(iter, currentPath);

					string name = iter.getValueString(0);
					if (name in this.tribunes) {
						//this.tribunes[name].forceReload();
					}

					return true;
				default:
					return false;
			}
		});

		tribunesList.addOnCursorChanged((TreeView treeView) {
			TreeModelIF treeModel = tribunesList.getModel();
			TreePath currentPath;
			TreeViewColumn currentColumn;
			tribunesList.getCursor(currentPath, currentColumn);

			TreeIter iter = new TreeIter();
			iter = new TreeIter();
			treeModel.getIter(iter, currentPath);

			string name = iter.getValueString(0);
			if (name in this.tribunes) {
				this.setCurrentTribune(this.tribunes[name]);
			}
		});

		TreeViewColumn column = new TribuneTreeViewColumn("Tribune", new CellRendererText());
		tribunesList.appendColumn(column);
		column.setResizable(false);
		column.setExpand(false);
		column.setSizing(GtkTreeViewColumnSizing.FIXED);
		column.setFixedWidth(60);

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

		TreeModelIF treeModel = this.tribunesList.getModel();
		TreePath currentPath;
		TreeViewColumn currentColumn;
		this.tribunesList.getCursor(currentPath, currentColumn);

		TreeIter iter = new TreeIter();
		treeModel.getIterFirst(iter);
		do {
			string name = this.tribunesListStore.getValue(iter, 0).getString();

			if (name == this.currentTribune.tribune.name) {
				this.tribunesListStore.setValue(iter, 4, 1000);
			} else {
				this.tribunesListStore.setValue(iter, 4, 400);
			}
		} while (treeModel.iterNext(iter));

		this.input.setCurrentTribune(tribune);
	}

	TribuneMainViewer makeTribuneMainViewer() {
		TribuneMainViewer viewer = new TribuneMainViewer();

		foreach (GtkTribune gtkTribune; this.tribunes) {
			viewer.registerTribune(gtkTribune);
		}

		viewer.postClockHover.connect(&onPostClockHover);
		viewer.postSegmentHover.connect(&onPostSegmentHover);

		viewer.postClockClick.connect(&onPostClockClick);
		viewer.postLoginClick.connect(&onPostLoginClick);
		viewer.postSegmentClick.connect(&onPostSegmentClick);

		viewer.postHighlight.connect(&onPostHighlight);
		viewer.resetHighlight.connect(&onResetHighlight);

		viewer.tribunes = this.tribunes.values;

		return viewer;
	}

	TribunePreviewer makeTribunePreviewer() {
		auto preview = new TribunePreviewer();

		foreach (GtkTribune gtkTribune; this.tribunes) {
			preview.registerTribune(gtkTribune);
		}

		preview.tribunes = this.tribunes.values;

		return preview;
	}

	void onPostClockHover(GtkPost post) {
		this.preview.postInfo(post);
		this.preview.show();
	}

	void onPostSegmentHover(GtkPost post, GtkPostSegment segment) {
		if (segment.context.link) {
			this.preview.showUrl(segment.context.link_target);
			this.preview.show();
		}
	}

	void onPostClockClick(GtkPost post) {
		writeln("Clicked on clock: ", post.post.clock);
		this.setCurrentTribune(post.tribune);
		this.input.insertText(post.post.clock ~ " ");
		this.input.grabFocus();
	}

	void onPostLoginClick(GtkPost post) {
		writeln("Clicked on login: ", post.post.timestamp);
		this.setCurrentTribune(post.tribune);
		this.input.insertText(post.post.login ~ "< ");
		this.input.grabFocus();
	}

	void onPostSegmentClick(GtkPost post, GtkPostSegment segment) {
		writeln("Clicked on segment: ", segment.text);
		if (segment.context.link) {
			writeln("Url is ", segment.context.link_target);
			MountOperation.showUri(null, segment.context.link_target, 0);
		}
	}

	void onPostHighlight(GtkPost post) {
		this.preview.renderPost(post);
		this.preview.show();
	}

	void onResetHighlight() {
		this.preview.hide();
	}

	MenuBar makeMenuBar() {
		AccelGroup accelGroup = new AccelGroup();
		this.addAccelGroup(accelGroup);

		MenuBar menuBar = new MenuBar();
		Menu menu = menuBar.append("_Tribunes");
		menu.append(new MenuItem(&onMenuActivate, "_Settings", "tribunes.settings", true, accelGroup, 's'));
		menu.append(new MenuItem(&onMenuActivate, "E_xit", "application.exit", true, accelGroup, 'q'));

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

class GtkTribuneColor {
	string desc;

	this(string desc) {
		this.desc = desc;
	}

	RGBA toRGBA() {
		return new RGBA(1, 0, 0, 1);
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

		renderer.setProperty("size-points", 8);
		
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

	string color;

	bool updating;

	ListStore listStore;
	TreeIter iter;

	mixin Signal!(GtkPost) newPost;

	this(GtkUI ui, Tribune tribune) {
		this.ui = ui;
		this.tribune = tribune;

		this.tribune.new_post.connect(&this.newPostHandler);

		this.color = tribune.color;
	}

	void newPostHandler(Post post) {
		GtkPost p = new GtkPost(this, post);
		this.posts ~= p;

		this.newPost.emit(p);
	};

	GtkPost[] findPostsByClock(GtkPostSegment segment) {
		GtkPost[] posts;

		if (!this.tribune.matches_name(segment.context.clock.tribune)) {
			return posts;
		}

		foreach (GtkPost post ; this.posts) {
			if (post.post.matches_clock(segment.context.clock)) {
				posts ~= post;
			}
		}

		return posts;
	}

	GtkPostSegment[] findReferencesToPost(GtkPost post) {
		GtkPostSegment[] segments;

		foreach (GtkPost tested_post ; this.posts) {
			foreach (GtkPostSegment segment ; tested_post.segments) {
				if (segment.context.clock != Clock.init && post.post.matches_clock(segment.context.clock)) {
					segments ~= segment;
				}
			}
		}

		return segments;
	}

	void fetch_posts() {
		this.fetch_posts(null);
	}

	void fetch_posts(void delegate() callback = null) {
		this.updating = true;
		stderr.writeln("Updating ", this.tribune.name);
		try {
			this.tribune.fetch_posts();
			stderr.writeln("Fetched ", this.tribune.name);
		} catch (Exception e) {
			stderr.writeln("Not fetched ", this.tribune.name);
		}
		this.updating = false;
		if (callback) {
			callback();
		}
	}
}

