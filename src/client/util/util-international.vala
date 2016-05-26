/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

extern const string LANGUAGE_SUPPORT_DIRECTORY;
extern const string ISO_CODE_639_XML;
extern const string ISO_CODE_3166_XML;
public const string TRANSLATABLE = "translatable";

namespace International {
	
private GLib.HashTable<string, string> official_names = null;
private GLib.HashTable<string, string> official_countries = null;

public const string SYSTEM_LOCALE = "";

void init(string package_name, string program_path, string locale = SYSTEM_LOCALE) {
    Intl.setlocale(LocaleCategory.ALL, locale);
    Intl.bindtextdomain(package_name, get_langpack_dir_path(program_path));
    Intl.bind_textdomain_codeset(package_name, "UTF-8");
    Intl.textdomain(package_name);
}

// TODO: Geary should be able to use langpacks from the build directory
private string get_langpack_dir_path(string program_path) {
    return LANGUAGE_SUPPORT_DIRECTORY;
}

public string[] get_available_dictionaries() {
	string[] dictionaries = {};
	
	Enchant.Broker broker = new Enchant.Broker();
	broker.list_dicts((lang_tag, provider_name, provider_desc, provider_file) => {
		dictionaries += lang_tag;
	});
	
	return dictionaries; 
}

public string[] get_available_locales() {
	string[] locales = {};
	
	try {		
		string? output = null;
		GLib.Subprocess p = new GLib.Subprocess.newv({ "locale", "-a" }, 
			GLib.SubprocessFlags.STDOUT_PIPE);		
		p.communicate_utf8(null, null, out output, null);
		
		foreach (string l in output.split("\n")) {
			locales += l;
		}
	} catch (GLib.Error e) {
		return locales;
	}
	
	return locales;
}

/* 
 * Strip the information about the encoding from the locale. 
 * 
 * That is, en_US.UTF-8 is mapped to en_US, while en_GB remains
 * unchanged. 
 */
public string strip_encoding(string locale) {
	int dot = locale.index_of_char('.');
	return locale.substring(0, dot);
}

public string[] get_user_preferred_languages() {
	GLib.GenericSet<string> dicts = new GLib.GenericSet<string>(GLib.str_hash, GLib.str_equal);
	foreach (string dict in get_available_dictionaries())
		dicts.add(dict);
		
	GLib.GenericSet<string> locales = new GLib.GenericSet<string>(GLib.str_hash, GLib.str_equal);
	foreach (string locale in get_available_locales())
		locales.add(strip_encoding(locale));
	
	string[] output = {};
	unowned string[] language_names = GLib.Intl.get_language_names();
	foreach (string lang in language_names) {
		// Check if we have the associated locale and the dictionary installed before actually
		//  considering this language. 
		if (lang != "C" && dicts.contains(lang) && locales.contains(lang)) {
			output += lang;
		}
	}
	return output;
}

public string? official_name_from_locale (string locale) {
	if (official_names == null) {
		official_names = new HashTable<string, string>(GLib.str_hash, GLib.str_equal);	
		official_countries = new HashTable<string, string>(GLib.str_hash, GLib.str_equal);	
			
		unowned Xml.Doc doc = Xml.Parser.parse_file(ISO_CODE_639_XML);
		if (doc == null) {
			return null;
		}
		else {
			unowned Xml.Node root = doc.get_root_element();
			for (unowned Xml.Node entry = root.children; entry != null; entry = entry.next) {
				if (entry.type == Xml.ElementType.ELEMENT_NODE) {
					string? iso_639_1 = null;
					string? language_name = null;
					
					for (unowned Xml.Attr a = entry.properties; a != null; a = a.next) {				
						switch (a.name) {
							case "iso_639_1_code":
								iso_639_1 = a.children->content;
								break;
							case "name":
								language_name = a.children->content;
								break;
							default:
								break;
						}
						
						if (language_name != null) {
							if (iso_639_1 != null) {
								official_names.insert(iso_639_1, language_name);
							}
						}
					}
				}
			}
		}
		
		doc = Xml.Parser.parse_file(ISO_CODE_3166_XML);
		if (doc == null) {
			return null;
		}
		else {
			unowned Xml.Node root = doc.get_root_element();
			for (unowned Xml.Node entry = root.children; entry != null; entry = entry.next) {
				if (entry.type == Xml.ElementType.ELEMENT_NODE) {
					string? iso_3166 = null;
					string? country_name = null;
					
					for (unowned Xml.Attr a = entry.properties; a != null; a = a.next) {				
						switch (a.name) {
							case "alpha_2_code":
								iso_3166 = a.children->content;
								break;
							case "name":
								country_name = a.children->content;
								break;
							default:
								break;
						}
						
						if (country_name != null) {
							if (iso_3166 != null) {
								official_countries.insert(iso_3166, country_name);
							}
						}
					}
				}
			}
		}
	}
	
	// Look for the name of language matching only the part before the _
	int pos = -1;
	if ("_" in locale) {
		pos = locale.index_of_char('_');
	}
	
	// Return a translated version of the language. 
	string language_name = GLib.dgettext("iso_639", official_names.get(locale.substring(0, pos)));
	string country_name  = GLib.dgettext("iso_3166", official_countries.get(locale.substring(pos+1)));
	
	if (country_name != null)
		language_name = language_name + " (" + country_name + ")";
		
	return language_name;
}

}

