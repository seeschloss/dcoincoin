module dcc.conf;

private import dcc.tribune;
private import ini.dini;

private import std.file;
private import std.conv;

class Config {
	Tribune[] tribunes;

	string default_ua = "DCoinCoin/1.99";
	int default_refresh = 30;

	this(string file) {
		if (!exists(file)) {
			std.file.write(file, []);
		}

		auto ini = Ini.Parse(file);

		foreach (IniSection section ; ini.sections) {
			if (section.name == "global") {
				this.default_ua = section.getKey("ua");
				this.default_refresh = to!int(section.getKey("refresh"));
			} else {
				tribunes ~= this.tribune_from_section(section);
			}
		}
	}

	Tribune tribune_from_section(IniSection section) {
		string name = section.getKey("name");
		string[] aliases = section.getKey("aliases").split(",");
		string post_url = section.getKey("post_url");
		string post_format = section.getKey("post_format");
		string xml_url = section.getKey("xml_url");
		string cookie = section.getKey("cookie");
		string ua = section.getKey("ua");
		if (!ua.length) {
			ua = this.default_ua;
		}
		int refresh;
		string refresh_string = section.getKey("refresh");
		try {
			refresh = parse!int(refresh_string);
		} catch (Exception e) {
			refresh = this.default_refresh;
		}
		bool tags_encoded;
		string tags_encoded_string = section.getKey("tags_encoded");
		try {
			tags_encoded = parse!bool(tags_encoded_string);
		} catch (Exception e) {
			tags_encoded = false;;
		}
		Tribune tribune = new Tribune(name, aliases, post_url, post_format, xml_url, cookie, ua, refresh, tags_encoded);

		return tribune;
	}
}
