/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010 Sébastien Wilmet
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
using Gee;

public class PreferencesDialog : Dialog
{
    private static PreferencesDialog preferences_dialog = null;
    private ListStore build_tools_store;
    private TreeView build_tools_view;

    private PreferencesDialog ()
    {
        add_button (STOCK_CLOSE, ResponseType.CLOSE);
        title = _("Preferences");
        has_separator = false;
        destroy_with_parent = true;
        border_width = 5;

        response.connect (() => hide ());

        var path = Path.build_filename (Config.DATA_DIR, "ui", "preferences_dialog.ui");

        try
        {
            var builder = new Builder ();
            builder.add_from_file (path);

            // get objects
            var notebook = (Notebook) builder.get_object ("notebook");
            var display_line_nb_checkbutton =
                builder.get_object ("display_line_nb_checkbutton");
            var tab_width_spinbutton = builder.get_object ("tab_width_spinbutton");
            var insert_spaces_checkbutton =
                builder.get_object ("insert_spaces_checkbutton");
            var hl_current_line_checkbutton =
                builder.get_object ("hl_current_line_checkbutton");
            var bracket_matching_checkbutton =
                builder.get_object ("bracket_matching_checkbutton");
            var backup_checkbutton = builder.get_object ("backup_checkbutton");
            var autosave_checkbutton = builder.get_object ("autosave_checkbutton");
            var autosave_spinbutton = (Widget) builder.get_object ("autosave_spinbutton");
            Label autosave_label = (Label) builder.get_object ("autosave_label");
            var reopen_checkbutton = builder.get_object ("reopen_checkbutton");

            var default_font_checkbutton =
                (Button) builder.get_object ("default_font_checkbutton");
            var font_button = builder.get_object ("font_button");
            var font_hbox = (Widget) builder.get_object ("font_hbox");
            var schemes_treeview = (TreeView) builder.get_object ("schemes_treeview");

            var document_view_program = builder.get_object ("document_view_program");
            var web_browser = builder.get_object ("web_browser");

            build_tools_view = (TreeView) builder.get_object ("build_tools_treeview");
            Button bt_new = (Button) builder.get_object ("build_tool_new");
            Button bt_delete = (Button) builder.get_object ("build_tool_delete");
            Button bt_up = (Button) builder.get_object ("build_tool_up");
            Button bt_down = (Button) builder.get_object ("build_tool_down");
            Button bt_properties = (Button) builder.get_object ("build_tool_properties");

            var confirm_clean_up_checkbutton =
                builder.get_object ("confirm_clean_up_checkbutton");
            Widget auto_clean_up_checkbutton =
                (Widget) builder.get_object ("auto_clean_up_checkbutton");
            var clean_up_entry = builder.get_object ("clean_up_entry");

            var file_browser_show_all = builder.get_object ("file_browser_show_all");
            Widget file_browser_show_hidden =
                (Widget) builder.get_object ("file_browser_show_hidden");
            Widget file_browser_entry =
                (Widget) builder.get_object ("file_browser_entry");

            // bind settings
            var settings = new GLib.Settings ("org.gnome.latexila.preferences.editor");

            settings.bind ("use-default-font", default_font_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("editor-font", font_button, "font-name",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("tabs-size", tab_width_spinbutton, "value",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("insert-spaces", insert_spaces_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("display-line-numbers", display_line_nb_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("highlight-current-line", hl_current_line_checkbutton,
                "active", SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("bracket-matching", bracket_matching_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("create-backup-copy", backup_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("auto-save", autosave_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("auto-save-interval", autosave_spinbutton, "value",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            settings.bind ("reopen-files", reopen_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);

            settings.bind ("web-browser", web_browser, "text",
                SettingsBindFlags.GET | SettingsBindFlags.SET);

            GLib.Settings build_settings =
                new GLib.Settings ("org.gnome.latexila.preferences.build");
            build_settings.bind ("document-view-program", document_view_program, "text",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            build_settings.bind ("no-confirm-clean", confirm_clean_up_checkbutton,
                "active", SettingsBindFlags.GET | SettingsBindFlags.SET);
            build_settings.bind ("automatic-clean", auto_clean_up_checkbutton, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            build_settings.bind ("clean-extensions", clean_up_entry, "text",
                SettingsBindFlags.GET | SettingsBindFlags.SET);

            GLib.Settings fb_settings =
                new GLib.Settings ("org.gnome.latexila.preferences.file-browser");
            fb_settings.bind ("show-all-files", file_browser_show_all, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            fb_settings.bind ("show-hidden-files", file_browser_show_hidden, "active",
                SettingsBindFlags.GET | SettingsBindFlags.SET);
            fb_settings.bind ("file-extensions", file_browser_entry, "text",
                SettingsBindFlags.GET | SettingsBindFlags.SET);

            // schemes treeview
            var current_scheme_id = settings.get_string ("scheme");
            init_schemes_treeview (schemes_treeview, current_scheme_id);
            schemes_treeview.cursor_changed.connect ((treeview) =>
            {
                TreePath tree_path;
                TreeIter iter;
                schemes_treeview.get_cursor (out tree_path, null);

                TreeModel model = treeview.model;
                model.get_iter (out iter, tree_path);

                string id;
                model.get (iter, StyleSchemes.ID, out id, -1);

                settings.set_string ("scheme", id);
            });

            // autosave spinbutton sensitivity
            var auto_save_enabled = settings.get_boolean ("auto-save");
            autosave_spinbutton.set_sensitive (auto_save_enabled);
            settings.changed["auto-save"].connect ((setting, key) =>
            {
                var val = setting.get_boolean (key);
                autosave_spinbutton.set_sensitive (val);
            });

            // autosave label
            uint interval;
            settings.get ("auto-save-interval", "u", out interval);
            autosave_label.label = interval > 1 ? _("minutes") : _("minute");
            settings.changed["auto-save-interval"].connect ((setting, key) =>
            {
                uint val;
                setting.get (key, "u", out val);
                autosave_label.label = val > 1 ? _("minutes") : _("minute");
            });

            // font hbox sensitivity
            var use_default_font = settings.get_boolean ("use-default-font");
            font_hbox.set_sensitive (! use_default_font);
            settings.changed["use-default-font"].connect ((setting, key) =>
            {
                var val = setting.get_boolean (key);
                font_hbox.set_sensitive (! val);
            });

            // default font checkbutton label
            set_system_font_label (default_font_checkbutton);

            AppSettings app_settings = AppSettings.get_default ();
            app_settings.notify["system-font"].connect (() =>
            {
                set_system_font_label (default_font_checkbutton);
            });

            // automatic clean-up sensitivity
            bool no_confirm = build_settings.get_boolean ("no-confirm-clean");
            auto_clean_up_checkbutton.set_sensitive (no_confirm);
            build_settings.changed["no-confirm-clean"].connect ((setting, key) =>
            {
                bool val = setting.get_boolean (key);
                auto_clean_up_checkbutton.set_sensitive (val);
            });

            // file browser settings sensitivity
            bool fb_show_all = fb_settings.get_boolean ("show-all-files");
            file_browser_show_hidden.set_sensitive (fb_show_all);
            file_browser_entry.set_sensitive (! fb_show_all);
            fb_settings.changed["show-all-files"].connect ((setting, key) =>
            {
                bool val = setting.get_boolean (key);
                file_browser_show_hidden.set_sensitive (val);
                file_browser_entry.set_sensitive (! val);
            });

            // build tools
            init_build_tools_treeview ();
            init_build_tools_buttons (bt_new, bt_delete, bt_up, bt_down, bt_properties);

            // pack notebook
            var content_area = (Box) get_content_area ();
            content_area.pack_start (notebook, true, true, 0);
            notebook.border_width = 5;
        }
        catch (Error e)
        {
            var message = "Error: %s".printf (e.message);
            stderr.printf ("%s\n", message);

            var label_error = new Label (message);
            label_error.set_line_wrap (true);
            var content_area = (Box) get_content_area ();
            content_area.pack_start (label_error, true, true, 0);
            content_area.show_all ();
        }
    }

    private void set_system_font_label (Button button)
    {
        AppSettings app_settings = AppSettings.get_default ();
        string label = _("Use the system fixed width font (%s)")
            .printf (app_settings.system_font);
        button.set_label (label);
    }

    public static void show_me (MainWindow parent)
    {
        if (preferences_dialog == null)
        {
            preferences_dialog = new PreferencesDialog ();

            // FIXME how to connect Widget.destroyed?
            preferences_dialog.destroy.connect (() =>
            {
                if (preferences_dialog != null)
                    preferences_dialog = null;
            });
        }

        if (parent != preferences_dialog.get_transient_for ())
            preferences_dialog.set_transient_for (parent);

        preferences_dialog.present ();
    }

    private enum StyleSchemes
    {
        ID,
        DESC,
        N_COLUMNS
    }

    private void init_schemes_treeview (TreeView treeview, string current_id)
    {
        var list_store = new ListStore (StyleSchemes.N_COLUMNS, typeof (string),
            typeof (string));
        list_store.set_sort_column_id (StyleSchemes.ID, SortType.ASCENDING);
        treeview.set_model (list_store);

        var renderer = new CellRendererText ();
        var column = new TreeViewColumn.with_attributes (
            "Name and description", renderer,
            "markup", StyleSchemes.DESC, null);
        treeview.append_column (column);

        var select = treeview.get_selection ();
        select.set_mode (SelectionMode.SINGLE);

        /* fill style scheme list store */
        var manager = SourceStyleSchemeManager.get_default ();
        foreach (string id in manager.get_scheme_ids ())
        {
            var scheme = manager.get_scheme (id);
            var desc = "<b>%s</b> - %s".printf (scheme.name, scheme.description);
            TreeIter iter;
            list_store.append (out iter);
            list_store.set (iter,
                StyleSchemes.ID, scheme.id,
                StyleSchemes.DESC, desc,
                -1);

            if (id == current_id)
                select.select_iter (iter);
        }
    }

    private enum BuildToolColumn
    {
        PIXBUF,
        LABEL,
        DESCRIPTION,
        N_COLUMNS
    }

    private void init_build_tools_treeview ()
    {
        build_tools_store = new ListStore (BuildToolColumn.N_COLUMNS, typeof (string),
            typeof (string), typeof (string));
        build_tools_view.set_model (build_tools_store);

        TreeViewColumn column = new TreeViewColumn ();
        build_tools_view.append_column (column);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        column.pack_start (pixbuf_renderer, false);
        column.set_attributes (pixbuf_renderer, "stock-id", BuildToolColumn.PIXBUF, null);

        CellRendererText text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", BuildToolColumn.LABEL, null);

        build_tools_view.set_tooltip_column (BuildToolColumn.DESCRIPTION);

        var select = build_tools_view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);

        /* fill list store */
        unowned LinkedList<BuildTool?> tools =
            AppSettings.get_default ().get_build_tools ();
        foreach (BuildTool tool in tools)
        {
            TreeIter iter;
            build_tools_store.append (out iter);
            build_tools_store.set (iter,
                BuildToolColumn.PIXBUF, tool.icon,
                BuildToolColumn.LABEL, tool.label,
                BuildToolColumn.DESCRIPTION, tool.description,
                -1);
        }
    }

    private void init_build_tools_buttons (Button bt_new,
                                           Button bt_delete,
                                           Button bt_up,
                                           Button bt_down,
                                           Button bt_properties)
    {
        bt_delete.clicked.connect (() =>
        {
            TreeIter iter;
            int i = get_selected_build_tool (out iter);
            if (i != -1)
            {
                build_tools_store.remove (iter);
                AppSettings.get_default ().delete_build_tool (i);
            }
        });

        bt_up.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = get_selected_build_tool (out iter1);
            if (i != -1 && i > 0)
            {
                iter2 = iter1;
                if (Utils.tree_model_iter_prev (build_tools_store, ref iter2))
                {
                    build_tools_store.swap (iter1, iter2);
                    AppSettings.get_default ().move_build_tool_up (i);
                }
            }
        });

        bt_down.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = get_selected_build_tool (out iter1);
            if (i != -1)
            {
                iter2 = iter1;
                if (build_tools_store.iter_next (ref iter2))
                {
                    build_tools_store.swap (iter1, iter2);
                    AppSettings.get_default ().move_build_tool_down (i);
                }
            }
        });
    }

    // get indice of selected build tool in the treeview
    // returns -1 if no build tool is selected
    private int get_selected_build_tool (out TreeIter iter = null)
    {
        TreeSelection select = build_tools_view.get_selection ();
        GLib.List<TreePath> selected_rows = select.get_selected_rows (null);
        if (selected_rows.length () == 0)
            return -1;

        unowned TreePath path = selected_rows.nth_data (0);
        build_tools_store.get_iter (out iter, path);
        unowned int[] indices = path.get_indices ();
        return indices[0];
    }
}
