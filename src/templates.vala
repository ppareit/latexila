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

public class Templates : GLib.Object
{
    private static Templates _instance = null;

    // Contains the default templates (empty, article, report, ...)
    private ListStore _default_store;

    // Contains the personal templates (created by the user)
    private ListStore _personal_store;

    private int _nb_personal_templates;

    private File _data_dir;
    private File _rc_file;

    private enum TemplateColumn
    {
        PIXBUF,  // the theme icon name
        ICON_ID, // the string stored in the rc file (article, report, ...)
        NAME,
        CONTENTS,
        N_COLUMNS
    }

    /* Templates is a singleton */
    private Templates ()
    {
        _data_dir = File.new_for_path (
            Path.build_filename (Environment.get_user_data_dir (), "latexila"));

        _rc_file = _data_dir.get_child ("templatesrc");

        init_default_templates ();
        init_personal_templates ();
    }

    public static Templates get_default ()
    {
        if (_instance == null)
            _instance = new Templates ();
        return _instance;
    }

    private void init_default_templates ()
    {
        _default_store = create_new_store ();

        add_template_from_string (_default_store, _("Empty"), "empty", "");

        add_default_template (_("Article"), "article", "article.tex");
        add_default_template (_("Report"), "report", "report.tex");
        add_default_template (_("Book"), "book", "book.tex");
        add_default_template (_("Letter"), "letter", "letter.tex");
        add_default_template (_("Presentation"), "beamer", "beamer.tex");
    }

    private void init_personal_templates ()
    {
        _personal_store = create_new_store ();
        _nb_personal_templates = 0;

        // if the rc file doesn't exist, there is no personal template
        if (! _rc_file.query_exists ())
            return;

        // load the key file
        KeyFile key_file = new KeyFile ();
        string[] names;
        string[] icons;

        try
        {
            key_file.load_from_file (_rc_file.get_path (), KeyFileFlags.NONE);

            // get the names and the icons
            names = key_file.get_string_list (Config.APP_NAME, "names");
            icons = key_file.get_string_list (Config.APP_NAME, "icons");
        }
        catch (Error e)
        {
            warning ("Load templates failed: %s", e.message);
            return;
        }

        return_if_fail (names.length == icons.length);

        int nb_templates = names.length;

        for (int i = 0 ; i < nb_templates ; i++)
        {
            File file = get_personal_template_file (i);
            if (! file.query_exists ())
            {
                warning ("The template '%s' doesn't exist.", names[i]);
                continue;
            }

            if (add_template_from_file (_personal_store, names[i], icons[i], file))
                _nb_personal_templates++;
        }
    }

    private ListStore create_new_store ()
    {
        return new ListStore (TemplateColumn.N_COLUMNS,
            typeof (string), // pixbuf
            typeof (string), // icon id
            typeof (string), // name
            typeof (string)  // contents
        );
    }

    private File get_personal_template_file (int template_num)
    {
        string filename = "%d.tex".printf (template_num);
        return _data_dir.get_child (filename);
    }

    /*************************************************************************/
    // Add templates: from string, from file, ...

    private void add_template_from_string (ListStore store, string name,
        string icon_id, string contents)
    {
        TreeIter iter;
        store.append (out iter);
        store.set (iter,
            TemplateColumn.PIXBUF, get_theme_icon (icon_id),
            TemplateColumn.ICON_ID, icon_id,
            TemplateColumn.NAME, name,
            TemplateColumn.CONTENTS, contents);
    }

    // Returns true on success.
    private bool add_template_from_file (ListStore store, string name,
        string icon_id, File file)
    {
        uint8[] chars;

        try
        {
            file.load_contents (null, out chars, null);
        }
        catch (Error e)
        {
            warning ("Impossible to load the template '%s': %s", name, e.message);
            return false;
        }

        string contents = (string) (owned) chars;
        add_template_from_string (store, name, icon_id, contents);

        return true;
    }

    private void add_default_template (string name, string icon_id, string filename)
    {
        // The templates are translated, so we search first a translated template.

        File[] files = {};

        unowned string[] language_names = Intl.get_language_names ();
        foreach (string language_name in language_names)
        {
            files += File.new_for_path (Path.build_filename (Config.DATA_DIR,
                "templates", language_name, filename));
        }

        foreach (File file in files)
        {
            if (! file.query_exists ())
                continue;

            add_template_from_file (_default_store, name, icon_id, file);
            return;
        }

        warning ("Template '%s' not found.", name);
    }

    /*************************************************************************/
    // Dialogs: create a new document, create/delete a template

    // Dialog: create a new document from a template.
    public void show_dialog_new (MainWindow parent)
    {
        Dialog dialog = new Dialog.with_buttons (_("New File..."), parent,
            DialogFlags.NO_SEPARATOR,
            Stock.OK, ResponseType.ACCEPT,
            Stock.CANCEL, ResponseType.REJECT,
            null);

        // get and set previous size
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");
        int w, h;
        settings.get ("new-file-dialog-size", "(ii)", out w, out h);
        dialog.set_default_size (w, h);

        // without this, we can not shrink the dialog completely
        dialog.set_size_request (0, 0);

        Box content_area = (Box) dialog.get_content_area ();
        VPaned vpaned = new VPaned ();
        content_area.pack_start (vpaned);
        vpaned.position = settings.get_int ("new-file-dialog-paned-position");

        /* icon view for the default templates */
        IconView icon_view_default_templates = create_icon_view (_default_store);
        Widget scrollbar = Utils.add_scrollbar (icon_view_default_templates);
        Widget component = Utils.get_dialog_component (_("Default templates"), scrollbar);
        vpaned.pack1 (component, true, true);

        /* icon view for the personal templates */
        IconView icon_view_personal_templates = create_icon_view (_personal_store);
        scrollbar = Utils.add_scrollbar (icon_view_personal_templates);
        component = Utils.get_dialog_component (_("Your personal templates"), scrollbar);
        vpaned.pack2 (component, false, true);

        content_area.show_all ();

        icon_view_default_templates.selection_changed.connect (() =>
        {
            on_icon_view_selection_changed (icon_view_default_templates,
                icon_view_personal_templates);
        });

        icon_view_personal_templates.selection_changed.connect (() =>
        {
            on_icon_view_selection_changed (icon_view_personal_templates,
                icon_view_default_templates);
        });

        icon_view_default_templates.item_activated.connect ((path) =>
        {
            open_template (parent, _default_store, path);
            close_dialog_new (dialog, vpaned);
        });

        icon_view_personal_templates.item_activated.connect ((path) =>
        {
            open_template (parent, _personal_store, path);
            close_dialog_new (dialog, vpaned);
        });

        if (dialog.run () == ResponseType.ACCEPT)
        {
            List<TreePath> selected_items =
                icon_view_default_templates.get_selected_items ();
            TreeModel model = (TreeModel) _default_store;

            // if no item is selected in the default templates, maybe one item is
            // selected in the personal templates
            if (selected_items.length () == 0)
            {
                selected_items = icon_view_personal_templates.get_selected_items ();
                model = (TreeModel) _personal_store;
            }

            TreePath path = (TreePath) selected_items.nth_data (0);
            open_template (parent, model, path);
        }

        close_dialog_new (dialog, vpaned);
    }

    private void on_icon_view_selection_changed (IconView icon_view,
        IconView other_icon_view)
    {
        // Only one item of the two icon views can be selected at once.

        // We unselect all the items of the other icon view only if the current icon
        // view have an item selected, because when we unselect all the items the
        // "selection-changed" signal is emitted for the other icon view, so for the
        // other icon view this function is also called but no item is selected so
        // nothing is done and the item selected by the user keeps selected.

        List<TreePath> selected_items = icon_view.get_selected_items ();
        if (selected_items.length () > 0)
            other_icon_view.unselect_all ();
    }

    private void open_template (MainWindow main_window, TreeModel model, TreePath? path)
    {
        TreeIter iter = {};
        string contents = "";

        if (path != null && model.get_iter (out iter, path))
            model.get (iter, TemplateColumn.CONTENTS, out contents, -1);

        DocumentTab tab = main_window.create_tab (true);
        tab.document.set_contents (contents);
    }

    private void close_dialog_new (Dialog dialog, VPaned vpaned)
    {
        // save dialog size and paned position
        int w, h;
        dialog.get_size (out w, out h);
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");
        settings.set ("new-file-dialog-size", "(ii)", w, h);
        settings.set_int ("new-file-dialog-paned-position", vpaned.position);

        dialog.destroy ();
    }

    // Dialog: create a new template
    public void show_dialog_create (MainWindow parent)
    {
        return_if_fail (parent.active_tab != null);

        Dialog dialog = new Dialog.with_buttons (_("New Template..."), parent, 0,
            Stock.OK, ResponseType.ACCEPT,
            Stock.CANCEL, ResponseType.REJECT,
            null);

        dialog.set_default_size (420, 370);

        Box content_area = dialog.get_content_area () as Box;
        content_area.homogeneous = false;

        /* name */
        Entry entry = new Entry ();
        Widget component = Utils.get_dialog_component (_("Name of the new template"),
            entry);
        content_area.pack_start (component, false);

        /* icon */
        // we take the default store because it contains all the icons
        IconView icon_view = create_icon_view (_default_store);
        Widget scrollbar = Utils.add_scrollbar (icon_view);
        component = Utils.get_dialog_component (_("Choose an icon"), scrollbar);
        content_area.pack_start (component);

        content_area.show_all ();

        while (dialog.run () == ResponseType.ACCEPT)
        {
            // if no name specified
            if (entry.text_length == 0)
                continue;

            List<TreePath> selected_items = icon_view.get_selected_items ();

            // if no icon selected
            if (selected_items.length () == 0)
                continue;

            _nb_personal_templates++;

            // get the contents
            TextIter start, end;
            parent.active_document.get_bounds (out start, out end);
            string contents = parent.active_document.get_text (start, end, false);

            // get the icon id
            TreeModel model = (TreeModel) _default_store;
            TreePath path = selected_items.nth_data (0);
            TreeIter iter;
            string icon_id;
            model.get_iter (out iter, path);
            model.get (iter, TemplateColumn.ICON_ID, out icon_id, -1);

            add_template_from_string (_personal_store, entry.text, icon_id, contents);
            add_personal_template (contents);
            break;
        }

        dialog.destroy ();
    }

    public IconView create_icon_view_default_templates ()
    {
        return create_icon_view (_default_store);
    }

    public IconView create_icon_view_personal_templates ()
    {
        return create_icon_view (_personal_store);
    }

    private IconView create_icon_view (ListStore store)
    {
        IconView icon_view = new IconView.with_model (store);
        icon_view.set_selection_mode (SelectionMode.SINGLE);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        pixbuf_renderer.stock_size = IconSize.DIALOG;
        pixbuf_renderer.xalign = (float) 0.5;
        pixbuf_renderer.yalign = (float) 1.0;
        icon_view.pack_start (pixbuf_renderer, false);
        icon_view.set_attributes (pixbuf_renderer,
            "icon-name", TemplateColumn.PIXBUF,
            null);

        // We also use a CellRenderer for the text column, because with set_text_column()
        // the text is not centered (when a CellRenderer is used for the pixbuf).
        CellRendererText text_renderer = new CellRendererText ();
        text_renderer.alignment = Pango.Alignment.CENTER;
        text_renderer.wrap_mode = Pango.WrapMode.WORD;
        text_renderer.xalign = (float) 0.5;
        text_renderer.yalign = (float) 0.0;
        icon_view.pack_end (text_renderer, false);
        icon_view.set_attributes (text_renderer,
            "text", TemplateColumn.NAME,
            null);

        return icon_view;
    }

    public void delete_personal_template (TreePath template_path)
    {
        /* Delete the template from the personal store */
        TreeModel model = (TreeModel) _personal_store;
        TreeIter iter;
        model.get_iter (out iter, template_path);
        _personal_store.remove (iter);

        /* Remove the corresponding file */
        int template_num = template_path.get_indices ()[0];
        File template_file = get_personal_template_file (template_num);
        Utils.delete_file (template_file);

        /* Rename the next .tex files */
        for (int i = template_num + 1 ; i < _nb_personal_templates ; i++)
        {
            File file = get_personal_template_file (i);
            File new_file = get_personal_template_file (i-1);
            try
            {
                file.move (new_file, FileCopyFlags.OVERWRITE);
            }
            catch (Error e)
            {
                warning ("Delete personal template, move file failed: %s", e.message);
            }
        }

        _nb_personal_templates--;
    }

    private void add_personal_template (string contents)
    {
        save_rc_file ();

        File file = get_personal_template_file (_nb_personal_templates - 1);

        try
        {
            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            file.replace_contents (contents.data, null, false,
                FileCreateFlags.NONE, null);
        }
        catch (Error e)
        {
            warning ("Impossible to save the templates: %s", e.message);
        }
    }

    public void save_rc_file ()
    {
        if (_nb_personal_templates == 0)
        {
            Utils.delete_file (_rc_file);
            return;
        }

        // the names and the icons of all personal templates
        string[] names = new string[_nb_personal_templates];
        string[] icons = new string[_nb_personal_templates];

        // traverse the list store
        TreeIter iter;
        TreeModel model = (TreeModel) _personal_store;
        bool valid_iter = model.get_iter_first (out iter);
        int i = 0;
        while (valid_iter)
        {
            model.get (iter,
                TemplateColumn.NAME, out names[i],
                TemplateColumn.ICON_ID, out icons[i],
                -1);
            valid_iter = model.iter_next (ref iter);
            i++;
        }

        /* save the rc file */
        try
        {
            KeyFile key_file = new KeyFile ();
            key_file.set_string_list (Config.APP_NAME, "names", names);
            key_file.set_string_list (Config.APP_NAME, "icons", icons);

            string key_file_data = key_file.to_data ();

            // check if parent directories exist, if not, create it
            // TODO move this in a function in Utils
            File parent = _rc_file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            _rc_file.replace_contents (key_file_data.data, null, false,
                FileCreateFlags.NONE, null);
        }
        catch (Error e)
        {
            warning ("Impossible to save the templates: %s", e.message);
        }
    }

    // For compatibility reasons. 'icon_id' is the string stored in the rc file,
    // and the return value is the theme icon name used for the pixbuf.
    // If we store directly the theme icon names in the rc file, old rc files must be
    // modified via a script for example, but it's simpler like that.
    private string? get_theme_icon (string icon_id)
    {
        switch (icon_id)
        {
            case "empty":
                return "text-x-preview";

            case "article":
                // Same as Stock.FILE (but it's the theme icon name)
                return "text-x-generic";

            case "report":
                return "x-office-document";

            case "book":
                return "accessories-dictionary";

            case "letter":
                return "emblem-mail";

            case "beamer":
                return "x-office-presentation";

            default:
                return_val_if_reached (null);
        }
    }
}
