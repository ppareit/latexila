/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2012 Sébastien Wilmet
 *
 * LaTeXila is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * LaTeXila is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with LaTeXila.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: Sébastien Wilmet
 */

// SyncTeX: forward and backward search with evince.

[DBus (name = "org.gnome.evince.Daemon")]
interface EvinceDaemon : Object
{
    // Returns the bus name owner (the evince instance).
    public abstract string find_document (string uri, bool spawn) throws IOError;
}

[DBus (name = "org.gnome.evince.Application")]
interface EvinceApplication : Object
{
    public abstract string[] get_window_list () throws IOError;
}

private struct DocPosition
{
    int32 line;
    int32 column;
}

[DBus (name = "org.gnome.evince.Window")]
interface EvinceWindow : Object
{
    public abstract void sync_view (string source_file, DocPosition source_point,
        uint32 timestamp) throws IOError;

    public signal void sync_source (string source_file, DocPosition source_point,
        uint32 timestamp);
}

public class Synctex : Object
{
    public void forward_search (Document doc, int line, int column)
    {
        string? pdf_uri = get_pdf_uri (doc);
        return_if_fail (pdf_uri != null);

        EvinceWindow? ev_window = get_evince_window (pdf_uri);
        return_if_fail (ev_window != null);

        return_if_fail (doc.location != null);
        string tex_path = doc.location.get_path ();

        sync_view (ev_window, tex_path, line, column);
    }

    private string? get_pdf_uri (Document doc)
    {
        File? main_file = doc.get_main_file ();

        if (main_file == null)
            return null;

        string uri = main_file.get_uri ();
        return Utils.get_shortname (uri) + ".pdf";
    }

    private EvinceWindow? get_evince_window (string pdf_uri)
    {
        EvinceDaemon daemon = null;

        try
        {
            daemon = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.evince.Daemon",
                "/org/gnome/evince/Daemon");
        }
        catch (IOError e)
        {
            warning ("SyncTeX: can not connect to evince daemon: %s", e.message);
            return null;
        }

        string owner = null;

        try
        {
            owner = daemon.find_document (pdf_uri, true);
        }
        catch (IOError e)
        {
            warning ("SyncTeX: find document: %s", e.message);
            return null;
        }

        EvinceApplication app = null;

        try
        {
            app = Bus.get_proxy_sync (BusType.SESSION, owner, "/org/gnome/evince/Evince");
        }
        catch (IOError e)
        {
            warning ("SyncTeX: can not connect to evince application: %s", e.message);
            return null;
        }

        string[] window_list = {};

        try
        {
            window_list = app.get_window_list ();
        }
        catch (IOError e)
        {
            warning ("SyncTeX: can not get window list: %s", e.message);
            return null;
        }

        if (window_list.length == 0)
        {
            warning ("SyncTeX: the window list is empty.");
            return null;
        }

        // There is normally only one window.
        string window_path = window_list[0];
        EvinceWindow window = null;

        try
        {
            window = Bus.get_proxy_sync (BusType.SESSION, owner, window_path);
        }
        catch (IOError e)
        {
            warning ("SyncTeX: can not connect to evince window: %s", e.message);
            return null;
        }

        return window;
    }

    private void sync_view (EvinceWindow window, string tex_path, int line, int column)
    {
        DocPosition source_point = DocPosition ();
        source_point.line = line;
        source_point.column = column;

        try
        {
            window.sync_view (tex_path, source_point, Gdk.CURRENT_TIME);
        }
        catch (IOError e)
        {
            warning ("SyncTeX: can not sync view: %s", e.message);
        }
    }
}
