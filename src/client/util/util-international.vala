/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

extern const string LANGUAGE_SUPPORT_DIRECTORY;
public const string TRANSLATABLE = "translatable";

namespace International {
	
private GLib.HashTable<string, string> official_names = null;

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

public string[] get_available_locales() {
	string[] locales = {};
	
	GLib.File dictionary_directory = File.new_for_path("/usr/share/hunspell");
	
	try {
		GLib.FileEnumerator e = dictionary_directory.enumerate_children(
			FileAttribute.STANDARD_NAME, 0);			
		for (GLib.FileInfo info = e.next_file(); info != null; info = e.next_file()) {
			string name = info.get_name();
			if (name.len() > 4 && !("-" in name) && name.substring(-4) == ".dic") {
				locales += name.substring(0, name.len() - 4);
			}
		}		
	} catch (GLib.Error e) {
		return locales;
	}
	return locales;
}

public string? official_name_from_locale (string locale) {
	if (official_names == null) {
		official_names = new HashTable<string, string>(GLib.str_hash, GLib.str_equal);	
			
		unowned Xml.Doc doc = Xml.Parser.parse_file ("/usr/share/xml/iso-codes/iso_639.xml");
		if (doc == null) {
			// FIXME: Print out an error here
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
							if (iso_639_1 != null)
								official_names.insert(iso_639_1, language_name);
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
	
	return official_names.get(locale.substring(0, pos));
}

}

