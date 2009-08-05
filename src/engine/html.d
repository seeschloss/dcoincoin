module engine.html;

import std.string, std.cstream, std.ctype, std.conv;

dchar[char[]] html_entities;

char[] html_entities_encode (char[] string)
	{
	if (html_entities.length == 0)
		init_entities();

	/+
	foreach (char[] entity, dchar c ; html_entities)
		{
		string = replace (string, format ("&%s;", c), entity);
		}
	+/

	char[] outstring = "";

	foreach (dchar c ; string)
		{
		if (c <= 0xFF)
			{
			outstring ~= format ("%s", c);
			}
		else
			{
			outstring ~= format ("&#%d;", c);
			}
		}

	return outstring;
	}

char[] html_entities_decode (char[] string)
	{
	if (html_entities.length == 0)
		init_entities();

	char[] outstring = "";
	char[] entity = "";

	bool in_entity = false;

	foreach (char c ; string)
		{
		if (!in_entity)
			{
			if (c == '&')
				{
				in_entity = true;
				}
			else
				{
				outstring ~= c;
				}
			}
		else
			{
			if (c == ';')
				{
				in_entity = false;

				if (entity in html_entities)
					{
					outstring ~= format ("%s", html_entities[entity]);

					debug (3) dout.writefln ("Entité : %s", entity);
					}
				else
					{
					if (entity.length > 1 && entity[0] == '#')
						{
						try
							{
							int i = toInt (entity[1 .. $]);

							dchar d = cast (dchar) i;

							outstring ~= d;
							}
						catch (Exception e)
							{
							debug (3) dout.writefln ("Entité qui va pas : %s", entity);
							outstring ~= '&' ~ entity ~ ';';
							}
						}
					else
						{
						outstring ~= '&' ~ entity ~ ';';
						}
					}

				entity = "";
				}
			else if (isalnum (c))
				{
				entity ~= c;
				}
			else
				{
				in_entity = false;

				outstring ~= '&' ~ entity;

				entity = "";
				}
			}
		}

	return outstring ~ entity;
	}

void init_entities ()
	{
	html_entities["amp"]		= '&';
	html_entities["lt"]		= '<';
	html_entities["gt"]		= '>';
	html_entities["quot"]		= '"';

	html_entities["nbsp"]		= 160;
	html_entities["iexcl"]		= 161;
	html_entities["cent"]		= 162;
	html_entities["pound"]		= 163;
	html_entities["curren"]		= 164;
	html_entities["yen"]		= 165;
	html_entities["brvbar"]		= 166;
	html_entities["sect"]		= 167;
	html_entities["uml"]		= 168;
	html_entities["copy"]		= 169;
	html_entities["ordf"]		= 170;
	html_entities["laquo"]		= 171;
	html_entities["not"]		= 172;
	html_entities["shy"]		= 173;
	html_entities["reg"]		= 174;
	html_entities["macr"]		= 175;
	html_entities["deg"]		= 176;
	html_entities["plusmn"]		= 177;
	html_entities["sup2"]		= 178;
	html_entities["sup3"]		= 179;
	html_entities["acute"]		= 180;
	html_entities["micro"]		= 181;
	html_entities["para"]		= 182;
	html_entities["middot"]		= 183;
	html_entities["cedil"]		= 184;
	html_entities["sup1"]		= 185;
	html_entities["ordm"]		= 186;
	html_entities["raquo"]		= 187;
	html_entities["frac14"]		= 188;
	html_entities["frac12"]		= 189;
	html_entities["frac34"]		= 190;
	html_entities["iquest"]		= 191;
	html_entities["Agrave"]		= 192;
	html_entities["Aacute"]		= 193;
	html_entities["Acirc"]		= 194;
	html_entities["Atilde"]		= 195;
	html_entities["Auml"]		= 196;
	html_entities["Aring"]		= 197;
	html_entities["AElig"]		= 198;
	html_entities["Ccedil"]		= 199;
	html_entities["Egrave"]		= 200;
	html_entities["Eacute"]		= 201;
	html_entities["Ecirc"]		= 202;
	html_entities["Euml"]		= 203;
	html_entities["Igrave"]		= 204;
	html_entities["Iacute"]		= 205;
	html_entities["Icirc"]		= 206;
	html_entities["Iuml"]		= 207;
	html_entities["ETH"]		= 208;
	html_entities["Ntilde"]		= 209;
	html_entities["Ograve"]		= 210;
	html_entities["Oacute"]		= 211;
	html_entities["Ocirc"]		= 212;
	html_entities["Otilde"]		= 213;
	html_entities["Ouml"]		= 214;
	html_entities["times"]		= 215;
	html_entities["Oslash"]		= 216;
	html_entities["Ugrave"]		= 217;
	html_entities["Uacute"]		= 218;
	html_entities["Ucirc"]		= 219;
	html_entities["Uuml"]		= 220;
	html_entities["Yacute"]		= 221;
	html_entities["THORN"]		= 222;
	html_entities["szlig"]		= 223;
	html_entities["agrave"]		= 224;
	html_entities["aacute"]		= 225;
	html_entities["acirc"]		= 226;
	html_entities["atilde"]		= 227;
	html_entities["auml"]		= 228;
	html_entities["aring"]		= 229;
	html_entities["aelig"]		= 230;
	html_entities["ccedil"]		= 231;
	html_entities["egrave"]		= 232;
	html_entities["eacute"]		= 233;
	html_entities["ecirc"]		= 234;
	html_entities["euml"]		= 235;
	html_entities["igrave"]		= 236;
	html_entities["iacute"]		= 237;
	html_entities["icirc"]		= 238;
	html_entities["iuml"]		= 239;
	html_entities["eth"]		= 240;
	html_entities["ntilde"]		= 241;
	html_entities["ograve"]		= 242;
	html_entities["oacute"]		= 243;
	html_entities["ocirc"]		= 244;
	html_entities["otilde"]		= 245;
	html_entities["ouml"]		= 246;
	html_entities["divide"]		= 247;
	html_entities["oslash"]		= 248;
	html_entities["ugrave"]		= 249;
	html_entities["uacute"]		= 250;
	html_entities["ucirc"]		= 251;
	html_entities["uuml"]		= 252;
	html_entities["yacute"]		= 253;
	html_entities["thorn"]		= 254;
	html_entities["yuml"]		= 255;
	html_entities["OElig"]		= 338;
	html_entities["oelig"]		= 339;
	html_entities["Scaron"]		= 352;
	html_entities["scaron"]		= 353;
	html_entities["Yuml"]		= 376;
	html_entities["fnof"]		= 402;
	html_entities["circ"]		= 710;
	html_entities["tilde"]		= 732;
	html_entities["Alpha"]		= 913;
	html_entities["Beta"]		= 914;
	html_entities["Gamma"]		= 915;
	html_entities["Delta"]		= 916;
	html_entities["Epsilon"]	= 917;
	html_entities["Zeta"]		= 918;
	html_entities["Eta"]		= 919;
	html_entities["Theta"]		= 920;
	html_entities["Iota"]		= 921;
	html_entities["Kappa"]		= 922;
	html_entities["Lambda"]		= 923;
	html_entities["Mu"]		= 924;
	html_entities["Nu"]		= 925;
	html_entities["Xi"]		= 926;
	html_entities["Omicron"]	= 927;
	html_entities["Pi"]		= 928;
	html_entities["Rho"]		= 929;
	html_entities["Sigma"]		= 931;
	html_entities["Tau"]		= 932;
	html_entities["Upsilon"]	= 933;
	html_entities["Phi"]		= 934;
	html_entities["Chi"]		= 935;
	html_entities["Psi"]		= 936;
	html_entities["Omega"]		= 937;
	html_entities["alpha"]		= 945;
	html_entities["beta"]		= 946;
	html_entities["gamma"]		= 947;
	html_entities["delta"]		= 948;
	html_entities["epsilon"]	= 949;
	html_entities["zeta"]		= 950;
	html_entities["eta"]		= 951;
	html_entities["theta"]		= 952;
	html_entities["iota"]		= 953;
	html_entities["kappa"]		= 954;
	html_entities["lambda"]		= 955;
	html_entities["mu"]		= 956;
	html_entities["nu"]		= 957;
	html_entities["xi"]		= 958;
	html_entities["omicron"]	= 959;
	html_entities["pi"]		= 960;
	html_entities["rho"]		= 961;
	html_entities["sigmaf"]		= 962;
	html_entities["sigma"]		= 963;
	html_entities["tau"]		= 964;
	html_entities["upsilon"]	= 965;
	html_entities["phi"]		= 966;
	html_entities["chi"]		= 967;
	html_entities["psi"]		= 968;
	html_entities["omega"]		= 969;
	html_entities["thetasym"]	= 977;
	html_entities["upsih"]		= 978;
	html_entities["piv"]		= 982;
	html_entities["ensp"]		= 8194;
	html_entities["emsp"]		= 8195;
	html_entities["thinsp"]		= 8201;
	html_entities["zwnj"]		= 8204;
	html_entities["zwj"]		= 8205;
	html_entities["lrm"]		= 8206;
	html_entities["rlm"]		= 8207;
	html_entities["ndash"]		= 8211;
	html_entities["mdash"]		= 8212;
	html_entities["lsquo"]		= 8216;
	html_entities["rsquo"]		= 8217;
	html_entities["sbquo"]		= 8218;
	html_entities["ldquo"]		= 8220;
	html_entities["rdquo"]		= 8221;
	html_entities["bdquo"]		= 8222;
	html_entities["dagger"]		= 8224;
	html_entities["Dagger"]		= 8225;
	html_entities["bull"]		= 8226;
	html_entities["hellip"]		= 8230;
	html_entities["permil"]		= 8240;
	html_entities["prime"]		= 8242;
	html_entities["Prime"]		= 8243;
	html_entities["lsaquo"]		= 8249;
	html_entities["rsaquo"]		= 8250;
	html_entities["oline"]		= 8254;
	html_entities["frasl"]		= 8260;
	html_entities["euro"]		= 8364;
	html_entities["image"]		= 8465;
	html_entities["weierp"]		= 8472;
	html_entities["real"]		= 8476;
	html_entities["trade"]		= 8482;
	html_entities["alefsym"]	= 8501;
	html_entities["larr"]		= 8592;
	html_entities["uarr"]		= 8593;
	html_entities["rarr"]		= 8594;
	html_entities["darr"]		= 8595;
	html_entities["harr"]		= 8596;
	html_entities["crarr"]		= 8629;
	html_entities["lArr"]		= 8656;
	html_entities["uArr"]		= 8657;
	html_entities["rArr"]		= 8658;
	html_entities["dArr"]		= 8659;
	html_entities["hArr"]		= 8660;
	html_entities["forall"]		= 8704;
	html_entities["part"]		= 8706;
	html_entities["exist"]		= 8707;
	html_entities["empty"]		= 8709;
	html_entities["nabla"]		= 8711;
	html_entities["isin"]		= 8712;
	html_entities["notin"]		= 8713;
	html_entities["ni"]		= 8715;
	html_entities["prod"]		= 8719;
	html_entities["sum"]		= 8721;
	html_entities["minus"]		= 8722;
	html_entities["lowast"]		= 8727;
	html_entities["radic"]		= 8730;
	html_entities["prop"]		= 8733;
	html_entities["infin"]		= 8734;
	html_entities["ang"]		= 8736;
	html_entities["and"]		= 8743;
	html_entities["or"]		= 8744;
	html_entities["cap"]		= 8745;
	html_entities["cup"]		= 8746;
	html_entities["int"]		= 8747;
	html_entities["there4"]		= 8756;
	html_entities["sim"]		= 8764;
	html_entities["cong"]		= 8773;
	html_entities["asymp"]		= 8776;
	html_entities["ne"]		= 8800;
	html_entities["equiv"]		= 8801;
	html_entities["le"]		= 8804;
	html_entities["ge"]		= 8805;
	html_entities["sub"]		= 8834;
	html_entities["sup"]		= 8835;
	html_entities["nsub"]		= 8836;
	html_entities["sube"]		= 8838;
	html_entities["supe"]		= 8839;
	html_entities["oplus"]		= 8853;
	html_entities["otimes"]		= 8855;
	html_entities["perp"]		= 8869;
	html_entities["sdot"]		= 8901;
	html_entities["lceil"]		= 8968;
	html_entities["rceil"]		= 8969;
	html_entities["lfloor"]		= 8970;
	html_entities["rfloor"]		= 8971;
	html_entities["lang"]		= 9001;
	html_entities["rang"]		= 9002;
	html_entities["loz"]		= 9674;
	html_entities["spades"]		= 9824;
	html_entities["clubs"]		= 9827;
	html_entities["hearts"]		= 9829;
	html_entities["diams"]		= 9830;
	}
