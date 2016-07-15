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

private Server[] GetQStatData(string qstat_exec_path, string id, string[] master_servers) {
    Server[] v = {} ;

    return v ;
}

public Server[] QStatBackendFunc(GLib.KeyFile settings) {
    var qstat_exec_path = settings.get_string (get_setting_group_string (SettingGroup.USER), "qstat_path") ;
    var qstat_master_servers = settings.get_string_list (get_setting_group_string (SettingGroup.USER), "master_uri") ;
    var qstat_id = settings.get_string (get_setting_group_string (SettingGroup.USER), "qstat_id") ;

    return GetQStatData (qstat_exec_path, qstat_id, qstat_master_servers) ;
}
