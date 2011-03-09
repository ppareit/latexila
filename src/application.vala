/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010-2011 Sébastien Wilmet
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
 */

public class Application : GLib.Object
{
    struct StockIcon
    {
        public string filename;
        public string stock_id;
    }

    private const StockIcon[] stock_icons =
    {
	    { Config.DATA_DIR + "/images/icons/compile_dvi.png", "compile_dvi" },
	    { Config.DATA_DIR + "/images/icons/compile_pdf.png", "compile_pdf" },
	    { Config.DATA_DIR + "/images/icons/compile_ps.png", "compile_ps" },
	    { Config.DATA_DIR + "/images/icons/view_dvi.png", "view_dvi" },
	    { Config.DATA_DIR + "/images/icons/view_pdf.png", "view_pdf" },
	    { Config.DATA_DIR + "/images/icons/view_ps.png", "view_ps" },
	    { Config.DATA_DIR + "/images/icons/textbf.png", "bold" },
	    { Config.DATA_DIR + "/images/icons/textit.png", "italic" },
	    { Config.DATA_DIR + "/images/icons/texttt.png", "typewriter" },
	    { Config.DATA_DIR + "/images/icons/textsl.png", "slanted" },
	    { Config.DATA_DIR + "/images/icons/textsc.png", "small_caps" },
	    { Config.DATA_DIR + "/images/icons/textsf.png", "sans_serif" },
	    { Config.DATA_DIR + "/images/icons/roman.png", "roman" },
	    { Config.DATA_DIR + "/images/icons/underline.png", "underline" },
	    { Config.DATA_DIR + "/images/misc-math/set-R.png", "blackboard" },
	    { Config.DATA_DIR + "/images/icons/sectioning-part.png", "sectioning-part" },
	    { Config.DATA_DIR + "/images/icons/sectioning-chapter.png", "sectioning-chapter" },
	    { Config.DATA_DIR + "/images/icons/sectioning-section.png", "sectioning-section" },
	    { Config.DATA_DIR + "/images/icons/sectioning-subsection.png", "sectioning-subsection" },
	    { Config.DATA_DIR + "/images/icons/sectioning-subsubsection.png", "sectioning-subsubsection" },
	    { Config.DATA_DIR + "/images/icons/sectioning-paragraph.png", "sectioning-paragraph" },
	    { Config.DATA_DIR + "/images/icons/character-size.png", "character-size" },
	    { Config.DATA_DIR + "/images/icons/list-itemize.png", "list-itemize" },
	    { Config.DATA_DIR + "/images/icons/list-enumerate.png", "list-enumerate" },
	    { Config.DATA_DIR + "/images/icons/list-description.png", "list-description" },
	    { Config.DATA_DIR + "/images/icons/list-item.png", "list-item" },
	    { Config.DATA_DIR + "/images/icons/references.png", "references" },
	    { Config.DATA_DIR + "/images/icons/math.png", "math" },
	    { Config.DATA_DIR + "/images/icons/math-centered.png", "math-centered" },
	    { Config.DATA_DIR + "/images/icons/math-numbered.png", "math-numbered" },
	    { Config.DATA_DIR + "/images/icons/math-array.png", "math-array" },
	    { Config.DATA_DIR + "/images/icons/math-numbered-array.png", "math-numbered-array" },
	    { Config.DATA_DIR + "/images/icons/math-superscript.png", "math-superscript" },
	    { Config.DATA_DIR + "/images/icons/math-subscript.png", "math-subscript" },
	    { Config.DATA_DIR + "/images/icons/math-frac.png", "math-frac" },
	    { Config.DATA_DIR + "/images/icons/math-square-root.png", "math-square-root" },
	    { Config.DATA_DIR + "/images/icons/math-nth-root.png", "math-nth-root" },
	    { Config.DATA_DIR + "/images/icons/mathcal.png", "mathcal" },
	    { Config.DATA_DIR + "/images/icons/mathfrak.png", "mathfrak" },
	    { Config.DATA_DIR + "/images/icons/delimiters-left.png", "delimiters-left" },
	    { Config.DATA_DIR + "/images/icons/delimiters-right.png", "delimiters-right" },
	    { Config.DATA_DIR + "/images/icons/badbox.png", "badbox" },
	    { Config.DATA_DIR + "/images/icons/logviewer.png", "view_log" },
	    { Config.DATA_DIR + "/images/greek/01.png", "symbol_alpha" },
	    { Config.DATA_DIR + "/images/icons/accent0.png", "accent0" },
	    { Config.DATA_DIR + "/images/icons/accent1.png", "accent1" },
	    { Config.DATA_DIR + "/images/icons/accent2.png", "accent2" },
	    { Config.DATA_DIR + "/images/icons/accent3.png", "accent3" },
	    { Config.DATA_DIR + "/images/icons/accent4.png", "accent4" },
	    { Config.DATA_DIR + "/images/icons/accent5.png", "accent5" },
	    { Config.DATA_DIR + "/images/icons/accent6.png", "accent6" },
	    { Config.DATA_DIR + "/images/icons/accent7.png", "accent7" },
	    { Config.DATA_DIR + "/images/icons/accent8.png", "accent8" },
	    { Config.DATA_DIR + "/images/icons/accent9.png", "accent9" },
	    { Config.DATA_DIR + "/images/icons/accent10.png", "accent10" },
	    { Config.DATA_DIR + "/images/icons/accent11.png", "accent11" },
	    { Config.DATA_DIR + "/images/icons/accent12.png", "accent12" },
	    { Config.DATA_DIR + "/images/icons/accent13.png", "accent13" },
	    { Config.DATA_DIR + "/images/icons/accent14.png", "accent14" },
	    { Config.DATA_DIR + "/images/icons/accent15.png", "accent15" },
	    { Config.DATA_DIR + "/images/icons/mathaccent0.png", "mathaccent0" },
	    { Config.DATA_DIR + "/images/icons/mathaccent1.png", "mathaccent1" },
	    { Config.DATA_DIR + "/images/icons/mathaccent2.png", "mathaccent2" },
	    { Config.DATA_DIR + "/images/icons/mathaccent3.png", "mathaccent3" },
	    { Config.DATA_DIR + "/images/icons/mathaccent4.png", "mathaccent4" },
	    { Config.DATA_DIR + "/images/icons/mathaccent5.png", "mathaccent5" },
	    { Config.DATA_DIR + "/images/icons/mathaccent6.png", "mathaccent6" },
	    { Config.DATA_DIR + "/images/icons/mathaccent7.png", "mathaccent7" },
	    { Config.DATA_DIR + "/images/icons/mathaccent8.png", "mathaccent8" },
	    { Config.DATA_DIR + "/images/icons/mathaccent9.png", "mathaccent9" },
	    { Config.DATA_DIR + "/images/icons/mathaccent10.png", "mathaccent10" },
	    { Config.DATA_DIR + "/images/icons/completion_choice.png", "completion_choice" },
	    { Config.DATA_DIR + "/images/icons/completion_cmd.png", "completion_cmd" },
	    { Config.DATA_DIR + "/images/icons/image.png", "image" }
    };

    public static int NEW_WINDOW = 1;
    private static Application instance = null;
    public unowned List<MainWindow> windows { get; private set; }
    public MainWindow active_window { get; private set; }

    /* Application is a singleton
     * We must use Application.get_default ()
     */
    private Application ()
    {
        windows = new List<MainWindow> ();

        /* personal style */
        // make the close buttons in tabs smaller
        Gtk.rc_parse_string ("""
            style "my-button-style"
            {
                GtkWidget::focus-padding = 0
                GtkWidget::focus-line-width = 0
                xthickness = 0
                ythickness = 0
            }
            widget "*.my-close-button" style "my-button-style"
        """);

        /* application icons */
        string[] filenames =
        {
            Config.ICONS_DIR + "/16x16/apps/latexila.png",
            Config.ICONS_DIR + "/22x22/apps/latexila.png",
            Config.ICONS_DIR + "/24x24/apps/latexila.png",
            Config.ICONS_DIR + "/32x32/apps/latexila.png",
            Config.ICONS_DIR + "/48x48/apps/latexila.png"
        };

        List<Gdk.Pixbuf> list = null;
        foreach (var filename in filenames)
        {
            try
            {
                list.append (new Gdk.Pixbuf.from_file (filename));
            }
            catch (Error e)
            {
                stderr.printf ("Error with an icon: %s\n", e.message);
            }
        }

        Gtk.Window.set_default_icon_list (list);

        register_my_stock_icons ();

        AppSettings.get_default ();
        create_window ();
    }

    public static Application get_default ()
    {
        if (instance == null)
            instance = new Application ();
        return instance;
    }

    // get all the documents currently opened
    public List<Document> get_documents ()
    {
        List<Document> res = null;
        foreach (var w in windows)
            res.concat (w.get_documents ());
        return res;
    }

    // get all the document views
    public List<DocumentView> get_views ()
    {
        List<DocumentView> res = null;
        foreach (var w in windows)
            res.concat (w.get_views ());
        return res;
    }

    public Unique.Response message (Unique.App sender, int command,
                                    Unique.MessageData data, uint time)
    {
        if (command == NEW_WINDOW)
        {
            create_window ();
            return Unique.Response.OK;
        }

        var workspace = data.get_workspace ();
        var screen = data.get_screen ();

        // if active_window not on current workspace, try to find an other window on the
        // current workspace.
        if (! active_window.is_on_workspace_screen (screen, workspace))
        {
            var found = false;
            foreach (var w in windows)
            {
                if (w == active_window)
                    continue;
                if (w.is_on_workspace_screen (screen, workspace))
                {
                    found = true;
                    active_window = w;
                    break;
                }
            }

            if (! found)
                create_window (screen);
        }

        if (command == Unique.Command.NEW)
            create_document ();

        else if (command == Unique.Command.OPEN)
            open_documents (data.get_uris ());

        active_window.present_with_time (time);
        return Unique.Response.OK;
    }

    public MainWindow create_window (Gdk.Screen? screen = null)
    {
        if (active_window != null)
            active_window.save_state (true);

        var window = new MainWindow ();
        active_window = window;
        notify_property ("active-window");

        if (screen != null)
            window.set_screen (screen);

        window.destroy.connect (() =>
        {
            windows.remove (window);
            if (windows.length () == 0)
            {
                Projects.get_default ().save ();
                BuildTools.get_default ().save ();
                MostUsedSymbols.get_default ().save ();
                Gtk.main_quit ();
            }
            else if (window == active_window)
            {
                active_window = (MainWindow) windows.data;
                notify_property ("active-window");
            }
        });

        window.focus_in_event.connect (() =>
        {
            active_window = window;
            notify_property ("active-window");
            return false;
        });

        windows.append (window);
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
        foreach (string uri in uris)
        {
            if (uri.length == 0)
                continue;
            var location = File.new_for_uri (uri);
            active_window.open_document (location);
        }
    }

    private void register_my_stock_icons ()
    {
        Gtk.IconFactory icon_factory = new Gtk.IconFactory ();

        foreach (StockIcon icon in stock_icons)
        {
            Gtk.IconSet icon_set = new Gtk.IconSet ();
            Gtk.IconSource icon_source = new Gtk.IconSource ();
            icon_source.set_filename (icon.filename);
            icon_set.add_source (icon_source);
            icon_factory.add (icon.stock_id, icon_set);
        }

        icon_factory.add_default ();
    }
}
