/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */
 
 public class SpellCheckPopover {
	 
	 private Gtk.Popover? popover = null;
	 
	 private GLib.GenericSet<string> selected_rows;
	 	 
	 public signal void selection_changed(string[] active_langs);
	 
	 private class SpellCheckRow : Gtk.ListBoxRow {
		 
		 public string lang_code;
		 public string lang_name;
		 public bool is_lang_visible;		 
		 private Gtk.CheckButton button;
		 public signal void toggled (string lang_code, bool status);
		 
		 public SpellCheckRow (string lang_code) {
			 this.lang_code = lang_code;			 
			 Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);			 
			 lang_name = International.official_name_from_locale(lang_code);
			 			 
			 box.pack_start(new Gtk.Label(lang_name), true, true, 6);			 
			 button = new Gtk.CheckButton();
			 box.pack_start(button,   false, true, 6);			 
			 add(box);
			 
			 is_lang_visible = false;
			 foreach (string visible_lang in GearyApplication.instance.config.spell_check_visible_languages) {
				 if (visible_lang == lang_code)
					is_lang_visible = true;
			 }
			 
			 foreach (string active_lang in GearyApplication.instance.config.spell_check_languages) {
				 if (active_lang == lang_code)
					button.set_active(true);
			 }
			 
			 button.toggled.connect(this.on_button_toggled);
		 }
		 
		 public bool is_lang_active() {
			 return button.get_active();
		 }
		 
		 private void on_button_toggled() {			 
			 if (button.get_active()) {
				 // If the lang is not visible make it visible now
				 if (!is_lang_visible) {
					 string[] visible_langs = GearyApplication.instance.config.spell_check_visible_languages;
					 visible_langs += lang_code;
					 GearyApplication.instance.config.spell_check_visible_languages = visible_langs;
					 is_lang_visible = true;
				 }
			 }
			 
			 this.toggled(lang_code, button.get_active());
		 }
	 }
	 
	 public SpellCheckPopover(Gtk.Widget button) {
		 popover = new Gtk.Popover(button);
		 selected_rows = new GLib.GenericSet<string>(GLib.str_hash, GLib.str_equal);
		 setup_popover();
	 }
	 
	 private void setup_popover() {
		 // We populate the popover with the list of languages that the user wants to see
		 // string[] languages = GearyApplication.instance.config.spell_check_visible_languages;
		 string[] languages = International.get_available_dictionaries();
		 
		 Gtk.Box content = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		 content.pack_start(new Gtk.Label(_("Select the active spell checker dictionaries")), false, true, 6);
		 
		 Gtk.ScrolledWindow view = new Gtk.ScrolledWindow(null, null);
		 view.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
		 
		 Gtk.ListBox langs_list = new Gtk.ListBox();
		 langs_list.set_selection_mode(Gtk.SelectionMode.NONE);
		 foreach (string lang in languages) {
			 SpellCheckRow row = new SpellCheckRow(lang);
			 langs_list.add(row);
			 
			 if (row.is_lang_active())
				selected_rows.add(lang);
				
			row.toggled.connect(this.on_row_toggled);
		 }		 
		 content.pack_start(langs_list, false, true, 6);
		 view.add(content);
		 
		 // We need to handle a sensible size request, otherwise nothing will be 
		 // visible. We make it 2/3 of the window height. 
		 view.set_size_request(-1, GearyApplication.instance.config.window_height * 2 / 3);
		 
		 popover.add(view);
	 }
	 
	 /*
	  * Toggle the visibility of the popover, and return the final status. 
	  * 
	  * @return true if the Popover is visible after the call, false otherwise. 
	  */
	 public bool toggle() {
		 if (popover.get_visible()) {
			 popover.hide();
		 }
		 else {
			 popover.show_all();
		 }
		 
		 return popover.get_visible();
	 }
	 
	 private void on_row_toggled(string lang_code, bool active) {
		 if (active)
			selected_rows.add(lang_code);
		 else
			selected_rows.remove(lang_code);
			
		// Signal that the selection has changed
		string[] active_langs = {};
		selected_rows.foreach((lang) => active_langs += lang);
		this.selection_changed(active_langs);
	 }
	 
 }

