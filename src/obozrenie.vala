// This file is part of Obozrenie.

// https://github.com/obozrenie
// Copyright (C) 2016 Artem Vorotnikov
//
// Obozrenie is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License
// as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Obozrenie is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Obozrenie.  If not, see <http://www.gnu.org/licenses/>.

using Gtk ;

public enum GameListModelColumn {
    ID,
    NAME,
    ICON,
    STATUS_ICON
}

public enum ServerListModelColumn {
    HOST,
    PASSWORD,
    PLAYER_COUNT,
    PLAYER_LIMIT,
    PING,
    SECURE,
    COUNTRY,
    NAME,
    GAME_ID,
    GAME_MOD,
    GAME_TYPE,
    TERRAIN,
    GAME_ICON,
    LOCK_ICON,
    SECURE_ICON,
    COUNTRY_ICON,
    FULL,
    EMPTY
}

public class ObozrenieApplication : Gtk.Application {
    Gtk.Builder builder ;
    Core core ;
    GLib.Settings settings ;

    Gtk.ListStore game_list_model ;
    Gtk.ListStore server_list_model ;

    Gtk.ApplicationWindow main_window ;
    Gtk.TreeView game_browser ;
    Gtk.ComboBox game_connect_combobox ;

    public ObozrenieApplication (Core c, string b, GLib.SettingsSchemaSource ? sss) {
        this.core = c ;
        if( sss != null ){
            this.settings = new GLib.Settings.full (sss.lookup ("io.obozrenie", false), null, null) ;
        }

        this.application_id = "io.obozrenie" ;
        this.flags = ApplicationFlags.FLAGS_NONE ;

        this.activate.connect (() => {
            this.builder = new Gtk.Builder.from_string (b, b.length) ;

            this.main_window = this.builder.get_object ("main_window") as Gtk.ApplicationWindow ;
            this.add_window (this.main_window) ;

            this.game_list_model = this.builder.get_object ("game-list-store") as Gtk.ListStore ;
            this.server_list_model = this.builder.get_object ("server-list-store") as Gtk.ListStore ;

            foreach( string name in this.core.game_table.list_game_entries ()){
                Gtk.TreeIter iter ;

                this.game_list_model.append (out iter) ;
                this.game_list_model.set_value (iter, GameListModelColumn.ID, name) ;
                this.game_list_model.set_value (iter, GameListModelColumn.NAME, this.core.game_table.get_setting (name, SettingGroup.SYSTEM, name_setting ())) ;
            }

            this.game_browser = this.builder.get_object ("Game_TreeView") as Gtk.TreeView ;

            if( sss != null ){
                this.bind_settings () ;
            }

            this.connect_signals () ;

            this.main_window.show_all () ;
        }) ;
    }

    public string selected_game {
        owned get {
            var v = GLib.Value (typeof (string)) ;

            Gtk.TreeModel m = this.game_browser.get_model () ;

            Gtk.TreeIter iter ;
            if( this.game_browser.get_selection ().get_selected (out m, out iter)){
                m.get_value (iter, GameListModelColumn.ID, out v) ;

                return v.get_string () ;
            } else {
                return "" ;
            }
        } set {
            Gtk.TreeModel m = this.game_browser.get_model () ;

            Gtk.TreeIter iter = SearchModel (m, GameListModelColumn.ID, value) ;

            this.game_browser.get_selection ().select_iter (iter) ;
        }
    }

    public void on_about_button_clicked() {
        make_about_dialog (this.main_window).show () ;
    }

    public void game_treeview_togglebutton_clicked() {
        var b = this.builder.get_object ("game_view_togglebutton") as Gtk.ToggleButton ;
        var combobox_revealer = this.builder.get_object ("game_combobox_revealer") as Gtk.Revealer ;
        var treeview_revealer = this.builder.get_object ("game_view_revealer") as Gtk.Revealer ;

        if( b.active ){
            combobox_revealer.set_reveal_child (false) ;
            treeview_revealer.set_reveal_child (true) ;
        } else {
            combobox_revealer.set_reveal_child (true) ;
            treeview_revealer.set_reveal_child (false) ;
        }
    }

    public void on_refresh_button_clicked() {
        var s1 = new Server () ;
        s1.host = "127.0.0.1" ;
        this.core.game_table.insert_servers ("q3a", { s1 }) ;
    }

    public void on_game_browser_selection_changed() {
        var selected_game = this.selected_game ;
        if( selected_game != "" ){
            this.load_servers (this.selected_game) ;
        }
    }

    public void load_servers(string id) {
        stdout.printf ("Getting servers for %s\n".printf (id)) ;
        this.server_list_model.clear () ;

        var data = this.core.game_table.get_servers (id, null) ;
        foreach( Server e in data ){
            stdout.printf (e.host) ;
            Gtk.TreeIter iter ;

            this.server_list_model.append (out iter) ;
            this.server_list_model.set_value (iter, ServerListModelColumn.HOST, e.host) ;
            this.server_list_model.set_value (iter, ServerListModelColumn.NAME, e.name) ;
            this.server_list_model.set_value (iter, ServerListModelColumn.PASSWORD, e.need_pass) ;
            if( e.need_pass ){
                this.server_list_model.set_value (iter, ServerListModelColumn.LOCK_ICON, "security-high-symbolic") ;
            }
            this.server_list_model.set_value (iter, ServerListModelColumn.TERRAIN, e.terrain) ;
            this.server_list_model.set_value (iter, ServerListModelColumn.PLAYER_COUNT, e.player_count) ;
            this.server_list_model.set_value (iter, ServerListModelColumn.PLAYER_LIMIT, e.player_limit) ;
            this.server_list_model.set_value (iter, ServerListModelColumn.COUNTRY, e.country) ;
            this.server_list_model.set_value (iter, ServerListModelColumn.SECURE, e.secure) ;
        }
    }

    public void on_server_data_changed(string id) {
        if( id == this.selected_game ){
            this.load_servers (id) ;
        }
    }

    public void connect_signals() {

        (this.builder.get_object ("Update_Button") as Gtk.Button).clicked.connect (this.on_refresh_button_clicked) ;
        (this.builder.get_object ("game_view_togglebutton") as Gtk.ToggleButton).clicked.connect (this.game_treeview_togglebutton_clicked) ;
        this.game_browser.get_selection ().changed.connect (this.on_game_browser_selection_changed) ;
        this.core.game_table.servers_changed.connect (this.on_server_data_changed) ;

    }

    public void bind_settings() {
        // this.settings.bind_with_mapping ("selected-game", this.game_connect_combobox, "changed", GLib.SettingsBindFlags.DEFAULT, null, null, null, null) ;
        this.settings.bind ("host", (this.builder.get_object ("server-connect-host") as Gtk.Entry), "text", GLib.SettingsBindFlags.DEFAULT) ;
    }

}

int main(string[] args) {
    var core = new Core () ;

    string game_data ;
    GLib.FileUtils.get_contents (GLib.Path.build_filename (Constants.PKGDATADIR, "game_lists.json"), out game_data) ;
    var p = new Json.Parser () ;
    p.load_from_data (game_data) ;
    core.game_table.read_game_lists (p.get_root ().get_object ()) ;

    string b ;
    GLib.FileUtils.get_contents (GLib.Path.build_filename (Constants.PKGDATADIR, "main.ui"), out b) ;

    var sss = new GLib.SettingsSchemaSource.from_directory (GLib.Path.build_filename (Constants.DATADIR, "glib-2.0", "schemas"), null, true) ;

    var app = new ObozrenieApplication (core, b, sss) ;
    return app.run (args) ;
}
