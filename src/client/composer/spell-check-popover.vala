/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */
 
interface SpellCheckRow : Gtk.ListBoxRow {
 
	/**
	 * Return true if the row shall be shown. The value of 
	 * is_expanded represents the current state of the list, 
	 * whereas it is true whenever the user has clicked the
	 * "Show more languages" button. 
	 */
	public abstract bool is_row_visible(bool is_expanded);
	
	/**
	 * React to being activated inside a ListBox.
	 */
	public abstract void handle_activation (SpellCheckPopover spell_check_popover);
 
}
 
 public class SpellCheckPopover {
	 	 	 
	 public signal void selection_changed(string[] active_langs);
	 
	 private Gtk.Popover? popover = null;
	 
	 private GLib.GenericSet<string> selected_rows;
	 
	 private bool is_expanded = false;
	 
	 private Gtk.ListBox langs_list;	
	 
	 private class SpellCheckMoreRow : Gtk.ListBoxRow, SpellCheckRow {
		 public SpellCheckMoreRow() {
			 add(new Gtk.Label(_("Show more languages")));
		 }
		 
		 public bool is_row_visible(bool is_expanded) {
			 return !is_expanded;
		 }
		 
		 public void handle_activation(SpellCheckPopover spell_check_popover) {
			 if (spell_check_popover.is_expanded)
				spell_check_popover.is_expanded = false;
			 else
				spell_check_popover.is_expanded = true;
				
			 spell_check_popover.langs_list.invalidate_filter();
		 }
	 }
	 
	 private class SpellCheckLangRow : Gtk.ListBoxRow, SpellCheckRow {
		 
		 public string lang_code;
		 public string lang_name;
		 public bool is_lang_visible;		 
		 private Gtk.CheckButton button;
		 public signal void toggled (string lang_code, bool status);
		 
		 public SpellCheckLangRow (string lang_code) {
			 this.lang_code = lang_code;			 
			 Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);			 
			 lang_name = International.official_name_from_locale(lang_code);
			 			 
			 box.pack_start(new Gtk.Label(lang_name), true, true, 6);			 
			 button = new Gtk.CheckButton();
			 box.pack_start(button, false, true, 6);			 
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
		 
		 public void handle_activation(SpellCheckPopover spell_check_popover) {
			 button.set_active(! button.get_active());
		 }
		 
		 public bool is_row_visible(bool is_expanded) {
			 return is_lang_visible || is_expanded;
		 }
	 }
	 
	 public SpellCheckPopover(Gtk.Widget button) {
		 popover = new Gtk.Popover(button);
		 selected_rows = new GLib.GenericSet<string>(GLib.str_hash, GLib.str_equal);
		 setup_popover();
	 }
	 
	 private bool filter_function (Gtk.ListBoxRow row) {
		 SpellCheckRow r = row as SpellCheckRow;
		 return r.is_row_visible(is_expanded);
	 }
	 
	 private void setup_popover() {
		 // We populate the popover with the list of languages that the user wants to see
		 // string[] languages = GearyApplication.instance.config.spell_check_visible_languages;
		 string[] languages = International.get_available_dictionaries();
		 
		 Gtk.Box content = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		 content.pack_start(new Gtk.Label(_("Select the active spell checker dictionaries")), false, true, 6);
		 
		 Gtk.ScrolledWindow view = new Gtk.ScrolledWindow(null, null);
		 view.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
		 
		 langs_list = new Gtk.ListBox();
		 langs_list.set_selection_mode(Gtk.SelectionMode.NONE);
		 foreach (string lang in languages) {
			 SpellCheckLangRow row = new SpellCheckLangRow(lang);
			 langs_list.add(row);
			 
			 if (row.is_lang_active())
				selected_rows.add(lang);
				
			row.toggled.connect(this.on_row_toggled);
		 }		 
		 
		 SpellCheckMoreRow row = new SpellCheckMoreRow();
		 langs_list.add(row);
		 
		 langs_list.row_activated.connect(on_row_activated);
		 
		 content.pack_start(langs_list, false, true, 6);
		 view.add(content);
		 
		 langs_list.set_filter_func(this.filter_function);
		 
		 // We need to handle a sensible size request, otherwise nothing will be 
		 // visible. We make it 2/3 of the window height. 
		 view.set_size_request(-1, GearyApplication.instance.config.window_height * 2 / 3);
		 // view.set_min_content_height(300);
		 // view.set_size_request(-1, 300);
		 
		 popover.add(view);
	 }
	 
	 private void on_row_activated(Gtk.ListBoxRow row) {
		 SpellCheckRow r = row as SpellCheckRow;
		 r.handle_activation(this);
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
			
		// In any case, restrict the list
		is_expanded = false;
		langs_list.invalidate_filter();
			
		// Signal that the selection has changed
		string[] active_langs = {};
		selected_rows.foreach((lang) => active_langs += lang);
		this.selection_changed(active_langs);
	 }
	 
 }

