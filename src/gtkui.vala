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

public Gtk.AboutDialog make_about_dialog(Gtk.Window w) {
    var d = new Gtk.AboutDialog () ;
    d.set_transient_for (w) ;
    d.set_modal (true) ;

    d.program_name = "Obozrenie" ;
    d.comments = "Simple and easy to use game server browser." ;
    d.copyright = "Copyright (c) 2015-2016 Obozrenie developers" ;
    d.version = "2.0" ;

    return d ;
}

public Gtk.TreeIter SearchModel(Gtk.TreeModel m, int c, GLib.Value v) {
    var found = Gtk.TreeIter () ;
    m.foreach((model, path, iter) => {
        GLib.Value v1 ;

        m.get_value (iter, c, out v1) ;

        if( v == v1 ){
            found = iter ;
            return true ;
        }
        return false ;
    } ) ;

    return found ;
}
