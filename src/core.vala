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

using Gee ;
using Json ;
using Geoip ;

public delegate void VoidFunc() ;

public delegate Server[] QueryFunc(GLib.KeyFile settings) ;

public delegate bool ServerCompareFunc(Server data) ;

public errordomain GameTableError {
    EXISTS,
    DOES_NOT_EXIST,
    INVALID_TYPE
}

public enum QueryStatus {
    EMPTY,
    READY,
    WORKING,
    ERROR
}

public enum SettingGroup {
    USER,
    SYSTEM,
    BACKEND
}

public string name_setting() {
    return "name" ;
}

public string get_setting_group_string(SettingGroup g) {
    string v = "" ;

    switch( g ){
    case SettingGroup.USER:
        v = "user" ;
        break ;

    case SettingGroup.BACKEND:
        v = "backend" ;
        break ;

    case SettingGroup.SYSTEM:
        v = "system" ;
        break ;
    }

    return v ;
}

public struct Player {
    string Name ;
    string Score ;
    int Ping ;
}

public class Server : GLib.Object {
    public string name ;
    public string host ;
    public bool need_pass ;
    public string country ;
    public bool secure ;
    public int player_count ;
    public int player_limit ;
    public string terrain ;
    public GLib.KeyFile settings ;
    public Gee.LinkedList players ;

    public Server () {
        this.settings = new GLib.KeyFile () ;
        this.players = new Gee.LinkedList<Player ? >() ;
    }

}

public class ConfigValue : GLib.Object {
    public GLib.VariantType type ;
    public GLib.Variant data ;
}

public class GameEntry : GLib.Object {
    public QueryStatus status ;

    public Gee.HashMap<SettingGroup, Gee.HashMap<string, ConfigValue> > settings ;
    public Gee.LinkedList<Server ? > servers ;

    public QueryFunc query_func ;

    public GameEntry () {
        this.settings = new Gee.HashMap<SettingGroup, Gee.HashMap<string, ConfigValue> >() ;
        this.servers = new Gee.LinkedList<Server ? >() ;
    }

}

public class GameTable : GLib.Object {
    private GLib.Mutex m ;
    private Gee.HashMap<string, GameEntry ? > data ;

    public signal void changed(string id) ;
    public signal void status_changed(string id) ;
    public signal void settings_changed(string id) ;
    public signal void servers_changed(string id) ;

    private void atomic_exec(VoidFunc fn) {
        this.m.lock( ) ;

        try {
            fn () ;
        } finally {
            this.m.unlock () ;
        }
    }

    public void create_game_entry(string id) throws GameTableError {
        this.m.lock( ) ;

        try {
            if( this.data.has_key (id)){
                throw new GameTableError.EXISTS (id) ;
            }

            this.data.set (id, new GameEntry ()) ;
            this.changed (id) ;
        } finally {
            this.m.unlock () ;
        }
    }

    public void remove_game_entry(string id) throws GameTableError {
        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            this.data.unset (id) ;
            this.changed (id) ;
        } finally {
            this.m.unlock () ;
        }
    }

    public Gee.Set<string> list_game_entries() {
        this.m.lock( ) ;

        var entries = this.data.keys ;

        this.m.unlock () ;

        return entries ;
    }

    public void create_setting(string id, GLib.VariantType t, SettingGroup g, string k, GLib.Variant ? data = null) throws GameTableError {
        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            if( !this.data.get (id).settings.has_key (g)){
                this.data.get (id).settings.set (g, new Gee.HashMap<string, ConfigValue>()) ;
            }

            var v = new ConfigValue () ;
            v.type = t ;
            v.data = data ;

            this.data.get (id).settings.get (g).set (k, v) ;

            this.changed (id) ;
            this.settings_changed (id) ;
        } finally {
            this.m.unlock () ;
        }
    }

    public void set_setting(string id, SettingGroup g, string k, GLib.Variant v) throws GameTableError {
        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            if( !this.data.get (id).settings.has_key (g)){
                throw new GameTableError.DOES_NOT_EXIST ("No setting group %s for game %s".printf (get_setting_group_string (g), id)) ;
            }

            if( !this.data.get (id).settings.get (g).has_key (k)){
                throw new GameTableError.DOES_NOT_EXIST ("No setting key %s for game %s, group %s".printf (k, id, get_setting_group_string (g))) ;
            }

            var dtype = this.data.get (id).settings.get (g).get (k).type ;
            var vtype = v.get_type () ;
            if( dtype != vtype ){
                throw new GameTableError.INVALID_TYPE ("Invalid type (%s), expected %s".printf (vtype.dup_string (), dtype.dup_string ())) ;
            }

            this.data.get (id).settings.get (g).get (k).data = v ;

            this.changed (id) ;
            this.settings_changed (id) ;
        } finally {
            this.m.unlock () ;
        }
    }

    public GLib.Variant get_setting(string id, SettingGroup g, string k) throws GameTableError {
        GLib.Variant v ;

        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            if( !this.data.get (id).settings.has_key (g)){
                throw new GameTableError.DOES_NOT_EXIST ("No setting group %s for game %s".printf (get_setting_group_string (g), id)) ;
            }

            if( !this.data.get (id).settings.get (g).has_key (k)){
                throw new GameTableError.DOES_NOT_EXIST ("No setting key %s for game %s, group %s".printf (k, id, get_setting_group_string (g))) ;
            }

            v = this.data.get (id).settings.get (g).get (k).data ;
        } finally {
            this.m.unlock () ;
        }
        return v ;
    }

    public GLib.KeyFile get_settings(string id) throws GameTableError {
        var f = new GLib.KeyFile () ;

        this.m.lock( ) ;
        try {
            f.load_from_data (this.data.get (id).settings.to_data (), -1, KeyFileFlags.NONE) ;
        } finally {
            this.m.unlock () ;
        }

        return f ;
    }

    public void set_query_func(string id, QueryFunc v) throws GameTableError {
        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            this.data.get (id).query_func = v ;

            this.changed (id) ;
        } finally {
            this.m.unlock () ;
        }
    }

    public QueryFunc get_query_func(string id) throws GameTableError {
        QueryFunc v = null ;

        this.atomic_exec (() => {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            v = this.data.get (id).query_func ;
        }) ;

        return v ;
    }

    public void set_query_status(string id, QueryStatus v) throws GameTableError {
        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            this.data.get (id).status = v ;

            this.changed (id) ;
            this.status_changed (id) ;
        } finally {
            this.m.unlock () ;
        }
    }

    public QueryStatus get_query_status(string id) throws GameTableError {
        var v = QueryStatus.EMPTY ;

        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            v = this.data.get (id).status ;

            this.changed (id) ;
            this.status_changed (id) ;
        } finally {
            this.m.unlock () ;
        }

        return v ;
    }

    public void insert_servers(string id, Server[] entries, bool keep_old = true) throws GameTableError {
        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            if( !keep_old ){
                this.data.get (id).servers.clear () ;
            }

            foreach( Server e in entries ){
                this.data.get (id).servers.add (e) ;
            }

            this.changed (id) ;
            this.servers_changed (id) ;
        } finally {
            this.m.unlock () ;
        }
    }

    public Server[] get_servers(string id, ServerCompareFunc ? f = null) throws GameTableError {
        Server[] matched = {} ;

        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            foreach( Server e in this.data.get (id).servers ){
                bool ok = false ;
                if( f == null ){
                    ok = true ;
                } else if( f (e)){
                    ok = true ;
                }

                if( ok ){
                    matched += e ;
                }
            }

        } finally {
            this.m.unlock () ;
        }
        return matched ;
    }

    public Server[] remove_servers(string id, ServerCompareFunc ? f = null) throws GameTableError {
        Server[] deleted = {} ;
        var remaining = new Gee.LinkedList<Server ? >() ;

        this.m.lock( ) ;

        try {
            if( !this.data.has_key (id)){
                throw new GameTableError.DOES_NOT_EXIST (id) ;
            }

            foreach( Server e in this.data.get (id).servers ){
                bool ok = false ;
                if( f == null ){
                    ok = true ;
                } else if( f (e)){
                    ok = true ;
                }

                if( ok ){
                    deleted += e ;
                } else {
                    remaining.add (e) ;
                }
            }

            this.data.get (id).servers = remaining ;

            this.changed (id) ;
            this.servers_changed (id) ;
        } finally {
            this.m.unlock () ;
        }
        return deleted ;
    }

    public void read_game_lists(Json.Object data) {
        data.foreach_member ((game_list, game_name, game_node) => {
            var game_object = game_node.get_object () ;

            this.create_game_entry (game_name) ;

            this.create_setting (game_name, GLib.VariantType.STRING, SettingGroup.SYSTEM, name_setting (), game_object.get_string_member ("name")) ;

            var sobj = game_object.get_object_member ("settings") ;
            if( sobj != null ){
                sobj.foreach_member ((o, k, entry_data_node) => {
                    var entry_data = entry_data_node.get_object () ;
                    var typestring = entry_data.get_string_member ("type") ;
                    if( GLib.VariantType.string_is_valid (typestring)){
                        this.create_setting (game_name, new GLib.VariantType (typestring), SettingGroup.USER, k) ;
                        if( entry_data.has_member ("default")){
                            this.set_setting (game_name, SettingGroup.USER, k, entry_data.get_member ("default").get_value ().get_variant ()) ;
                        }
                    }
                }) ;
            }

        }) ;
    }

    public GameTable () {
        data = new Gee.HashMap<string, GameEntry ? >() ;
    }

}

public class Core : GLib.Object {
    public GameTable game_table ;
    public Geoip.Geodata geocoder ;
    private GLib.Mutex m ;

    public void refresh_servers(string id) {
        this.m.lock( ) ;
        if( this.game_table.get_query_status (id) != QueryStatus.WORKING ){
            this.game_table.set_query_status (id, QueryStatus.WORKING) ;
            new Thread<void *>(null, () => {
                try {
                    var fn = this.game_table.get_query_func (id) ;

                    var data = fn (this.game_table.get_settings (id)) ;

                    foreach( Server v in data ){
                        v.country = geocoder.country_code_by_name (v.host) ;
                    }

                    this.game_table.remove_servers (id) ;
                    this.game_table.insert_servers (id, data) ;
                } catch ( Error e ){
                    this.game_table.set_query_status (id, QueryStatus.ERROR) ;
                    return null ;
                }
                this.game_table.set_query_status (id, QueryStatus.READY) ;
                return null ;
            }) ;
        }
        this.m.unlock () ;
    }

    public Core (string geoip_file_name = "") {
        this.game_table = new GameTable () ;
        this.geocoder = new Geoip.Geodata () ;
        if( geoip_file_name != "" ){
            this.geocoder.load_from_file (geoip_file_name) ;
        }
    }

}
