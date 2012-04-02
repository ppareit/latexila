/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010-2012 Sébastien Wilmet
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

public class Latexila : GLib.Object
{
    private static Latexila _instance = null;
    private Gee.List<MainWindow> _windows;

    public MainWindow active_window { get; private set; }

    // Latexila is a singleton.
    private Latexila ()
    {
        _windows = new Gee.LinkedList<MainWindow> ();

        set_application_icons ();
        StockIcons.add_custom ();

        AppSettings.get_default ();
        create_window ();
    }

    public static Latexila get_default ()
    {
        if (_instance == null)
            _instance = new Latexila ();

        return _instance;
    }

    private void set_application_icons ()
    {
        string[] sizes = {"16x16", "22x22", "24x24", "32x32", "48x48"};

        List<Gdk.Pixbuf> list = null;

        foreach (string size in sizes)
        {
            string filename = Path.build_filename (Config.ICONS_DIR, size,
                "apps", "latexila.png");

            try
            {
                list.append (new Gdk.Pixbuf.from_file (filename));
            }
            catch (Error e)
            {
                warning ("Application icon: %s", e.message);
            }
        }

        Gtk.Window.set_default_icon_list (list);
    }

    public Gee.List<MainWindow> get_windows ()
    {
        return _windows;
    }

    // Get all the documents currently opened.
    public Gee.List<Document> get_documents ()
    {
        Gee.List<Document> all_documents = new Gee.LinkedList<Document> ();
        foreach (MainWindow window in _windows)
            all_documents.add_all (window.get_documents ());

        return all_documents;
    }

    // Get all the document views.
    public Gee.List<DocumentView> get_views ()
    {
        Gee.List<DocumentView> all_views = new Gee.LinkedList<DocumentView> ();
        foreach (MainWindow window in _windows)
            all_views.add_all (window.get_views ());

        return all_views;
    }

    public MainWindow create_window (Gdk.Screen? screen = null)
    {
        if (active_window != null)
            active_window.save_state ();

        MainWindow window = new MainWindow ();
        _windows.add (window);
        active_window = window;

        if (screen != null)
            window.set_screen (screen);

        window.destroy.connect (() =>
        {
            _windows.remove (window);
            if (_windows.size == 0)
            {
                Projects.get_default ().save ();
                BuildTools.get_default ().save ();
                MostUsedSymbols.get_default ().save ();
                Gtk.main_quit ();
            }
            else if (window == active_window)
                active_window = _windows.first ();
        });

        window.focus_in_event.connect (() =>
        {
            active_window = window;
            return false;
        });

        window.show ();
        return window;
    }

    public void create_document ()
    {
        active_window.create_tab (true);
    }

    public void open_documents (
        [CCode (array_length = false, array_null_terminated = true)] string[] uris)
    {
        bool jump_to = true;
        foreach (string uri in uris)
        {
            if (uri.length == 0)
                continue;

            File location = File.new_for_uri (uri);
            active_window.open_document (location, jump_to);
            jump_to = false;
        }
    }
}
