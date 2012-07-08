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
 */

using Gtk;

public class FileBrowser : Grid
{
    private enum ParentDirColumn
    {
        PIXBUF,
        NAME,
        FILE,
        N_COLUMNS
    }

    private enum FileColumn
    {
        PIXBUF,
        NAME,
        IS_DIR,
        N_COLUMNS
    }

    private unowned MainWindow _main_window;
    private BuildView _build_view;
    private ListStore _parent_dir_store;
    private ListStore _list_store;
    private TreeView _list_view;
    private ComboBox _combo_box;
    private File _current_directory;
    private Button _parent_button;
    private GLib.Settings _settings;
    private GLib.Settings _latex_settings;
    private uint _timeout_id = 0;

    public FileBrowser (MainWindow main_window)
    {
        _main_window = main_window;
        _build_view = main_window.get_build_view ();

        row_spacing = 5;
        orientation = Orientation.VERTICAL;

        init_toolbar ();
        init_combo_box ();
        init_list ();
        init_settings ();
        show_all ();

        fill_stores_with_dir (null);
    }

    private void init_settings ()
    {
        _settings = new GLib.Settings ("org.gnome.latexila.preferences.file-browser");
        _settings.changed["show-all-files"].connect (refresh);
        _settings.changed["show-all-files-except"].connect (refresh);
        _settings.changed["show-hidden-files"].connect (refresh);
        _settings.changed["file-extensions"].connect (on_refresh);

        _latex_settings = new GLib.Settings ("org.gnome.latexila.preferences.latex");
        _latex_settings.changed["clean-extensions"].connect (on_refresh);
    }

    private void on_refresh ()
    {
        // Call refresh () only after 2 seconds.
        // If the text has changed before the 2 seconds, we reinitialize the counter.
        if (_timeout_id != 0)
            Source.remove (_timeout_id);

        _timeout_id = Timeout.add_seconds (2, () =>
        {
            _timeout_id = 0;
            refresh ();
            return false;
        });
    }

    private void init_toolbar ()
    {
        Grid grid = new Grid ();
        grid.set_orientation (Orientation.HORIZONTAL);
        grid.column_homogeneous = true;
        add (grid);

        Button home_button = Utils.get_toolbar_button (Stock.HOME);
        _parent_button = Utils.get_toolbar_button (Stock.GO_UP);
        Button jump_button = Utils.get_toolbar_button (Stock.JUMP_TO);
        Button refresh_button = Utils.get_toolbar_button (Stock.REFRESH);

        home_button.tooltip_text = _("Go to the home directory");
        _parent_button.tooltip_text = _("Go to the parent directory");
        jump_button.tooltip_text = _("Go to the active document directory");
        refresh_button.tooltip_text = _("Refresh");

        grid.add (home_button);
        grid.add (_parent_button);
        grid.add (jump_button);
        grid.add (refresh_button);

        home_button.clicked.connect (() =>
        {
            File home_dir = File.new_for_path (Environment.get_home_dir ());
            fill_stores_with_dir (home_dir);
        });

        _parent_button.clicked.connect (() =>
        {
            File? parent = _current_directory.get_parent ();
            return_if_fail (parent != null);
            fill_stores_with_dir (parent);
        });

        jump_button.clicked.connect (() =>
        {
            if (_main_window.active_tab == null
                || _main_window.active_document.location == null)
                return;
            fill_stores_with_dir (_main_window.active_document.location.get_parent ());
        });

        // jump button sensitivity
        _main_window.notify["active-document"].connect (() =>
        {
            update_jump_button_sensitivity (jump_button);

            // update jump button sensitivity when location changes
            if (_main_window.active_document != null)
            {
                _main_window.active_document.notify["location"].connect (() =>
                {
                    update_jump_button_sensitivity (jump_button);
                });
            }
        });

        refresh_button.clicked.connect (refresh);
    }

    private void update_jump_button_sensitivity (Button jump_button)
    {
        jump_button.sensitive = _main_window.active_tab != null
            && _main_window.active_document.location != null;
    }

    // list of parent directories
    private void init_combo_box ()
    {
        _parent_dir_store = new ListStore (ParentDirColumn.N_COLUMNS,
            typeof (string),    // pixbuf (stock-id)
            typeof (string),    // directory name
            typeof (File));

        _combo_box = new ComboBox.with_model (_parent_dir_store);
        add (_combo_box);

        // pixbuf
        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        _combo_box.pack_start (pixbuf_renderer, false);
        _combo_box.set_attributes (pixbuf_renderer,
            "stock-id", ParentDirColumn.PIXBUF, null);

        // directory name
        CellRendererText text_renderer = new CellRendererText ();
        _combo_box.pack_start (text_renderer, true);
        _combo_box.set_attributes (text_renderer, "text", ParentDirColumn.NAME, null);
        text_renderer.ellipsize_set = true;
        text_renderer.ellipsize = Pango.EllipsizeMode.END;

        _combo_box.changed.connect (() =>
        {
            TreeIter iter;
            if (_combo_box.get_active_iter (out iter))
            {
                TreeModel model = _combo_box.get_model ();
                File file;
                model.get (iter, ParentDirColumn.FILE, out file, -1);

                // avoid infinite loop (this method is called in fill_stores_with_dir ())
                if (! file.equal (_current_directory))
                    fill_stores_with_dir (file);
            }
        });
    }

    // list of files and directories
    private void init_list ()
    {
        _list_store = new ListStore (FileColumn.N_COLUMNS,
            typeof (string),    // pixbuf (stock-id)
            typeof (string),    // filename
            typeof (bool)       // is directory
            );

        _list_store.set_sort_func (0, on_sort);
        _list_store.set_sort_column_id (0, SortType.ASCENDING);

        _list_view = new TreeView.with_model (_list_store);
        _list_view.headers_visible = false;

        TreeViewColumn column = new TreeViewColumn ();
        _list_view.append_column (column);

        // icon
        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        column.pack_start (pixbuf_renderer, false);
        column.set_attributes (pixbuf_renderer, "stock-id", FileColumn.PIXBUF, null);

        // filename
        CellRendererText text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", FileColumn.NAME, null);

        // with a scrollbar
        Widget sw = Utils.add_scrollbar (_list_view);
        sw.expand = true;
        add (sw);

        _list_view.row_activated.connect ((path) =>
        {
            TreeModel model = (TreeModel) _list_store;
            TreeIter iter;
            if (! model.get_iter (out iter, path))
                return;

            string basename;
            bool is_dir;
            model.get (iter,
                FileColumn.NAME, out basename,
                FileColumn.IS_DIR, out is_dir,
                -1);

            File file = _current_directory.get_child (basename);

            if (is_dir)
            {
                fill_stores_with_dir (file);
                return;
            }

            string extension = Utils.get_extension (basename);
            if (extension != ".dvi" &&
                extension != ".pdf" &&
                extension != ".ps")
            {
                _main_window.open_document (file);
                return;
            }

            try
            {
                Gtk.show_uri (this.get_screen (), file.get_uri (), Gdk.CURRENT_TIME);
            }
            catch (Error e)
            {
                warning ("Impossible to open the file '%s': %s",
                    file.get_uri (), e.message);
            }
        });
    }

    public void refresh ()
    {
        fill_stores_with_dir (_current_directory);
    }

    // Refresh the file browser if the document has a "link" with the directory currently
    // displayed.
    public void refresh_for_document (Document doc)
    {
        Project? project = doc.get_project ();

        // If the document is not part of a project, refresh only if the document's
        // directory is the same as the current directory.
        if (project == null)
        {
            if (doc.location != null
                && _current_directory.equal (doc.location.get_parent ()))
            {
                refresh ();
            }

            return;
        }

        // If a project is defined, refresh if the current dir is part of the project.
        File project_dir = project.directory;

        if (_current_directory.equal (project_dir)
            || _current_directory.has_prefix (project_dir))
        {
            refresh ();
        }
    }

    private void fill_stores_with_dir (File? dir)
    {
        _list_store.clear ();
        _parent_dir_store.clear ();

        _list_view.columns_autosize ();

        /* files list store */

        File? directory = dir;
        if (directory == null)
        {
            string uri = _settings.get_string ("current-directory");

            if (uri != null && uri.length > 0)
                directory = File.new_for_uri (uri);

            // if first use, or if the directory doesn't exist, take the home directory
            if (uri == null || uri.length == 0 || ! directory.query_exists ())
                directory = File.new_for_path (Environment.get_home_dir ());
        }

        // TODO~ try (haha) to put the minimum code in the try
        // note: the file browser will be removed when latexila will become a
        // Gedit plugin...
        try
        {
            FileEnumerator enumerator = directory.enumerate_children (
                "standard::type,standard::display-name", FileQueryInfoFlags.NONE);

            bool show_all = _settings.get_boolean ("show-all-files");
            bool show_all_except = _settings.get_boolean ("show-all-files-except");
            bool show_hidden = show_all && _settings.get_boolean ("show-hidden-files");

            string exts = _settings.get_string ("file-extensions");
            string[] extensions = exts.split (" ");

            exts = _latex_settings.get_string ("clean-extensions");
            string[] clean_extensions = exts.split (" ");

            for (FileInfo? info = enumerator.next_file () ;
                 info != null ;
                 info = enumerator.next_file ())
            {
                string basename = info.get_display_name ();
                if (basename[0] == '.' && ! show_hidden)
                    continue;

                FileType type = info.get_file_type ();
                if (type == FileType.DIRECTORY)
                {
                    insert_file (true, Stock.DIRECTORY, basename);
                    continue;
                }

                string extension = Utils.get_extension (basename);
                if ((show_all && ! show_all_except)
                    || (show_all && ! (extension in clean_extensions))
                    || extension in extensions)
                {
                    string pixbuf;
                    switch (extension)
                    {
                        case ".tex":
                            pixbuf = Stock.EDIT;
                            break;
                        case ".pdf":
                            pixbuf = "view_pdf";
                            break;
                        case ".dvi":
                            pixbuf = "view_dvi";
                            break;
                        case ".ps":
                        case ".eps":
                            pixbuf = "view_ps";
                            break;
                        case ".png":
                        case ".jpg":
                        case ".jpeg":
                        case ".gif":
                        case ".bmp":
                        case ".tif":
                        case ".tiff":
                            pixbuf = "image";
                            break;
                        default:
                            pixbuf = Stock.FILE;
                            break;
                    }

                    insert_file (false, pixbuf, basename);
                }
            }

            _list_store.sort_column_changed ();
        }
        catch (Error e)
        {
            warning ("%s", e.message);

            // warning dialog
            MessageDialog dialog = new MessageDialog (_main_window,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.WARNING,
                ButtonsType.CLOSE,
                "%s", _("File Browser"));

            dialog.format_secondary_text ("%s", e.message);
            dialog.run ();
            dialog.destroy ();
            return;
        }

        /* parent directories store */

        List<File> parent_dirs = null;
        parent_dirs.prepend (directory);
        File current_dir = directory;

        while (true)
        {
            File? parent = current_dir.get_parent ();
            if (parent == null)
                break;
            parent_dirs.prepend (parent);
            current_dir = parent;
        }

        TreeIter iter = {};
        int i = 0;
        foreach (File current in parent_dirs)
        {
            // basename
            string basename;
            if (i == 0)
                basename = _("File System");
            else
                basename = current.get_basename ();

            // pixbuf
            string pixbuf;
            if (i == 0)
                pixbuf = Stock.HARDDISK;
            else if (Environment.get_home_dir () == current.get_path ())
                pixbuf = Stock.HOME;
            else
                pixbuf = Stock.DIRECTORY;

            // insert
            _parent_dir_store.append (out iter);
            _parent_dir_store.set (iter,
                ParentDirColumn.FILE, current,
                ParentDirColumn.NAME, basename,
                ParentDirColumn.PIXBUF, pixbuf,
                -1);

            i++;
        }

        _current_directory = directory;
        _settings.set_string ("current-directory", directory.get_uri ());

        // select the last parent directory
        _combo_box.set_active_iter (iter);

        _parent_button.set_sensitive (directory.get_parent () != null);
    }

    private void insert_file (bool is_dir, string pixbuf, string basename)
    {
        TreeIter iter;
        _list_store.append (out iter);
        _list_store.set (iter,
            FileColumn.IS_DIR, is_dir,
            FileColumn.PIXBUF, pixbuf,
            FileColumn.NAME, basename,
            -1);
    }

    private int on_sort (TreeModel model, TreeIter a, TreeIter b)
    {
        bool a_is_dir, b_is_dir;
        model.get (a, FileColumn.IS_DIR, out a_is_dir, -1);
        model.get (b, FileColumn.IS_DIR, out b_is_dir, -1);

        if (a_is_dir == b_is_dir)
        {
            string a_name, b_name;
            model.get (a, FileColumn.NAME, out a_name, -1);
            model.get (b, FileColumn.NAME, out b_name, -1);
            return a_name.collate (b_name);
        }

        return a_is_dir ? -1 : +1;
    }
}
