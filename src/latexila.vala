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

public class Latexila : Gtk.Application
{
    public MainWindow active_window { get; private set; }

    public Latexila ()
    {
        Object (application_id: "org.gnome.latexila");
        Environment.set_application_name ("LaTeXila");

        connect_signals ();
        add_actions ();
    }

    private void connect_signals ()
    {
        startup.connect (init_primary_instance);

        activate.connect (() =>
        {
            hold ();
            active_window.present ();
            release ();
        });

        shutdown.connect (() =>
        {
            hold ();
            Projects.get_default ().save ();
            BuildTools.get_default ().save ();
            MostUsedSymbols.get_default ().save ();
            release ();
        });

        window_removed.connect (() =>
        {
            hold ();
            unowned List<weak Gtk.Window> windows = get_windows ();
            if (0 < windows.length ())
                active_window = windows.data as MainWindow;

            release ();
        });
    }

    private void add_actions ()
    {
        /* New document */
        SimpleAction new_document_action = new SimpleAction ("new-document", null);
        add_action (new_document_action);

        new_document_action.activate.connect (() =>
        {
            hold ();
            create_document ();
            release ();
        });

        /* New window */
        SimpleAction new_window_action = new SimpleAction ("new-window", null);
        add_action (new_window_action);

        new_window_action.activate.connect (() =>
        {
            hold ();
            create_window ();
            release ();
        });

        /* Open files */
        VariantType strings_array = new VariantType ("as");
        SimpleAction open_files_action = new SimpleAction ("open-files", strings_array);
        add_action (open_files_action);

        open_files_action.activate.connect ((param) =>
        {
            string[] uris = param.dup_strv ();
            File[] files = {};

            foreach (string uri in uris)
            {
                if (0 < uri.length)
                    files += File.new_for_uri (uri);
            }

            open_documents (files);
        });
    }

    public static Latexila get_instance ()
    {
        return GLib.Application.get_default () as Latexila;
    }

    private void init_primary_instance ()
    {
        hold ();
        set_application_icons ();
        StockIcons.add_custom ();

        AppSettings.get_default ();
        create_window ();
        reopen_files ();
        release ();
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

    private void reopen_files ()
    {
        GLib.Settings editor_settings =
            new GLib.Settings ("org.gnome.latexila.preferences.editor");

        if (editor_settings.get_boolean ("reopen-files"))
        {
            GLib.Settings window_settings =
                new GLib.Settings ("org.gnome.latexila.state.window");

            string[] uris = window_settings.get_strv ("documents");
            File[] files = {};
            foreach (string uri in uris)
            {
                if (0 < uri.length)
                    files += File.new_for_uri (uri);
            }

            open_documents (files);
        }
    }

    // Get all the documents currently opened.
    public Gee.List<Document> get_documents ()
    {
        Gee.List<Document> all_documents = new Gee.LinkedList<Document> ();
        foreach (Gtk.Window window in get_windows ())
        {
            MainWindow main_window = window as MainWindow;
            all_documents.add_all (main_window.get_documents ());
        }

        return all_documents;
    }

    // Get all the document views.
    public Gee.List<DocumentView> get_views ()
    {
        Gee.List<DocumentView> all_views = new Gee.LinkedList<DocumentView> ();
        foreach (Gtk.Window window in get_windows ())
        {
            MainWindow main_window = window as MainWindow;
            all_views.add_all (main_window.get_views ());
        }

        return all_views;
    }

    public MainWindow create_window ()
    {
        if (active_window != null)
            active_window.save_state ();

        MainWindow window = new MainWindow ();
        add_window (window);
        active_window = window;

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

    public void open_documents (File[] files)
    {
        bool jump_to = true;
        foreach (File file in files)
        {
            active_window.open_document (file, jump_to);
            jump_to = false;
        }
    }
}
