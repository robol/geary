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
	 
	 private Gtk.Entry search_box;
	 
	 private Gtk.ScrolledWindow view;
	 
	 private Gtk.Box content;
	 
	 private enum SpellCheckStatus {
		 INACTIVE, 
		 DEACTIVATING,
		 ACTIVE
	 }
	 
	 private class SpellCheckLangRow : Gtk.ListBoxRow, SpellCheckRow {
		 
		 public string lang_code;
		 public string lang_name;
		 public string country_name;
		 public bool is_lang_visible;		 
		 public signal void toggled (string lang_code, bool status);
		 
		 private Gtk.Label label;
		 
		 private SpellCheckStatus lang_active = SpellCheckStatus.INACTIVE;
		 
		 private uint timer_id = 0;
		 
		 public SpellCheckLangRow (string lang_code) {
			 this.lang_code = lang_code;			 
			 Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);			 
			 
			 lang_name = International.language_name_from_locale(lang_code);
			 country_name = International.country_name_from_locale(lang_code);
			 
			 label = new Gtk.Label("");
			 label.set_xalign(0.0f);
			 label.set_size_request(-1, 24);
			 			 
			 box.pack_start(label, true, true);
			 
			 is_lang_visible = false;
			 foreach (string visible_lang in GearyApplication.instance.config.spell_check_visible_languages) {
				 if (visible_lang == lang_code)
					is_lang_visible = true;
			 }
			 
			 foreach (string active_lang in GearyApplication.instance.config.spell_check_languages) {
				 if (active_lang == lang_code)
					lang_active = SpellCheckStatus.ACTIVE;
			 }
			 			 
			 update_label();			 
			 add(box);
		 }
		 
		 public bool is_lang_active() {
			 return lang_active == SpellCheckStatus.ACTIVE;
		 }
		 
		 private void update_label() {
			 string text = lang_name;
			 if (country_name != null) {
				 text += " (<i>" + country_name + "</i>)";
			 }
			 
			 switch (lang_active) {
				 case SpellCheckStatus.ACTIVE:
					text += " \t \t <b>✓</b> ";
					break;
				case SpellCheckStatus.DEACTIVATING:
					text += " \t<i><small>" + 
						_("click again to remove from the quicklist") + 
						"</small></i>";
					break;
			 }
			 
			 label.set_markup(text);
		 }
		 
		 public bool match_filter(string filter) {
			 string filter_down = filter.down();
			 return (filter_down in lang_name.down() || filter_down in country_name.down());
		 }
		 
		 private void set_lang_active(SpellCheckStatus active) {			
			 lang_active = active;			 
			 
			 switch (active) {
				 case SpellCheckStatus.ACTIVE:
					 // If the lang is not visible make it visible now
					 if (!is_lang_visible) {
						 string[] visible_langs = GearyApplication.instance.config.spell_check_visible_languages;
						 visible_langs += lang_code;
						 GearyApplication.instance.config.spell_check_visible_languages = visible_langs;
						 is_lang_visible = true;
					 }
					 break;
				 case SpellCheckStatus.DEACTIVATING:
					// Make it switch automatically to INACTIVE in 5 seconds
					timer_id = GLib.Timeout.add(5000, this.on_automatic_deactivation, 0);
					break;
				 case SpellCheckStatus.INACTIVE:
					// Reset the timer counter, this has either been disabled or has expired. 
					if (timer_id > 0) {
						timer_id = 0;
					}
					break;
			 }
			 
			 update_label();
			 this.toggled(lang_code, active == SpellCheckStatus.ACTIVE);
		 }
		 
		 private bool on_automatic_deactivation() {			 
			 set_lang_active(SpellCheckStatus.INACTIVE);
			 return false;
		 }
		 
		 public void handle_activation(SpellCheckPopover spell_check_popover) {
			 switch (lang_active) {
				 case SpellCheckStatus.ACTIVE:
					set_lang_active(SpellCheckStatus.DEACTIVATING);
					break;
				case SpellCheckStatus.DEACTIVATING:
					GLib.Source.remove(timer_id);
												
					// Since the user has selected the button before the automatic timeout, 
					// we shall remove it from the quicklist. 
					is_lang_visible = false;
					string[] visible_langs = {};
					foreach (string visible_lang in GearyApplication.instance.config.spell_check_visible_languages) {
						if (visible_lang != lang_code)
							visible_langs += visible_lang;
					}
					GearyApplication.instance.config.spell_check_visible_languages = visible_langs;
					
					set_lang_active(SpellCheckStatus.INACTIVE);
					break;
				case SpellCheckStatus.INACTIVE:
					set_lang_active(SpellCheckStatus.ACTIVE);
					break;
			 }
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
		 string text = search_box.get_text();		 
		 SpellCheckLangRow r = row as SpellCheckLangRow;
		 return (r.is_row_visible(is_expanded) && r.match_filter(text));
	 }
	 
	 private void setup_popover() {
		 // We populate the popover with the list of languages that the user wants to see
		 // string[] languages = GearyApplication.instance.config.spell_check_visible_languages;
		 string[] languages = International.get_available_dictionaries();
		 
		 content = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
		 
		 // Setup a search box so that the user can lookup more languages, 		 // if needed. 
		 search_box = new Gtk.Entry();		 
		 // FIXME: We should not set the icon if the current theme does not support it. 
		 search_box.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "edit-find-symbolic");
		 search_box.set_placeholder_text(_("Search for more languages"));
		 search_box.changed.connect(on_search_box_changed);
		 search_box.grab_focus.connect(on_search_box_grab_focus);
		 content.pack_start(search_box, false, true);
		 
		 view = new Gtk.ScrolledWindow(null, null);
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
		 langs_list.row_activated.connect(on_row_activated);
		 view.add(langs_list);
		 
		 content.pack_start(view, true, true);		 
		 
		 langs_list.set_filter_func(this.filter_function);		
		 
		 view.set_size_request(350, 300);
		 popover.add(content);
		 
		 // Make sure that the search box does not get the focus first. We want it to have it only 
		 // if the user wants to perform an extended search. 
		 content.set_focus_child(view);
		 
		 content.set_margin_start(6);
		 content.set_margin_end(6);
		 content.set_margin_top(6);
		 content.set_margin_bottom(6);
	 }
	 
	 private void on_row_activated(Gtk.ListBoxRow row) {
		 SpellCheckRow r = row as SpellCheckRow;
		 r.handle_activation(this);
		 
		 // Make sure that we update the visible languages based on the
		 // possibly updated is_lang_visible_properties. 
		 langs_list.invalidate_filter();
	 }
	 
	 private void on_search_box_changed() {
		 langs_list.invalidate_filter();
	 }
	 
	 private void on_search_box_grab_focus() {
		 set_expanded(true);
	 }
	 
	 private void set_expanded(bool expanded) {
		 is_expanded = expanded;
		 langs_list.invalidate_filter();
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
			 // Make sure that when the box is shown the list is not expanded anymore. 
			 content.set_focus_child(view);
			 is_expanded = false;
			 langs_list.invalidate_filter();
			 
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

