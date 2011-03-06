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

using Gtk;
using Gee;

public class PreferencesDialog : Dialog
{
    private static PreferencesDialog preferences_dialog = null;
    private ListStore build_tools_store;
    private TreeView build_tools_view;

    private PreferencesDialog ()
    {
        Button reset_button = new Button.with_label (_("Reset All"));
        Image image = new Image.from_stock (STOCK_CLEAR, IconSize.MENU);
        reset_button.set_image (image);
        reset_button.show_all ();
        add_action_widget (reset_button, ResponseType.APPLY);

        add_button (STOCK_CLOSE, ResponseType.CLOSE);
        title = _("Preferences");
        has_separator = false;
        destroy_with_parent = true;
        border_width = 5;

        response.connect ((response_id) =>
        {
            if (response_id == ResponseType.CLOSE)
            {
                hide ();
                return;
            }

            /* reset all */
            Dialog dialog = get_reset_all_confirm_dialog (
                _("Do you really want to reset all preferences?"));
            int resp = dialog.run ();
            dialog.destroy ();
            if (resp != ResponseType.YES)
                return;

            string[] settings_str =
            {
                "org.gnome.latexila.preferences.editor",
                "org.gnome.latexila.preferences.latex",
                "org.gnome.latexila.preferences.file-browser"
            };

            foreach (string setting_str in settings_str)
            {
                GLib.Settings settings = new GLib.Settings (setting_str);
                string[] keys = settings.list_keys ();
                foreach (string key in keys)
                    settings.reset (key);
            }

            // build tools are NOT reset, since there is another button for that
        });

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
            Widget insert_spaces_checkbutton =
                (Widget) builder.get_object ("insert_spaces_checkbutton");
            Widget forget_no_tabs = (Widget) builder.get_object ("forget_no_tabs");
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


            var interactive_comp_checkbutton =
                builder.get_object ("interactive_comp_checkbutton");
            Widget interactive_comp_spinbutton =
                (Widget) builder.get_object ("interactive_comp_spinbutton");
            Label interactive_comp_label =
                (Label) builder.get_object ("interactive_comp_label");
            var document_view_program = builder.get_object ("document_view_program");
            var web_browser = builder.get_object ("web_browser");
            var nb_most_used_symbols = builder.get_object ("nb_most_used_symbols");

            build_tools_view = (TreeView) builder.get_object ("build_tools_treeview");
            Button bt_new = (Button) builder.get_object ("build_tool_new");
            Button bt_delete = (Button) builder.get_object ("build_tool_delete");
            Button bt_up = (Button) builder.get_object ("build_tool_up");
            Button bt_down = (Button) builder.get_object ("build_tool_down");
            Button bt_properties = (Button) builder.get_object ("build_tool_properties");
            Button bt_reset = (Button) builder.get_object ("build_tool_reset");

            var confirm_clean_up_checkbutton =
                builder.get_object ("confirm_clean_up_checkbutton");
            Widget auto_clean_up_checkbutton =
                (Widget) builder.get_object ("auto_clean_up_checkbutton");
            var clean_up_entry = builder.get_object ("clean_up_entry");

            var file_browser_show_all = builder.get_object ("file_browser_show_all");
            Widget vbox_file_browser_show_all =
                (Widget) builder.get_object ("vbox_file_browser_show_all");
            Widget file_browser_except =
                (Widget) builder.get_object ("file_browser_except");
            Widget file_browser_show_hidden =
                (Widget) builder.get_object ("file_browser_show_hidden");
            Widget file_browser_entry =
                (Widget) builder.get_object ("file_browser_entry");

            // bind settings
            var settings = new GLib.Settings ("org.gnome.latexila.preferences.editor");

            settings.bind ("use-default-font", default_font_checkbutton, "active",
                SettingsBindFlags.DEFAULT);
            settings.bind ("editor-font", font_button, "font-name",
                SettingsBindFlags.DEFAULT);
            settings.bind ("tabs-size", tab_width_spinbutton, "value",
                SettingsBindFlags.DEFAULT);
            settings.bind ("insert-spaces", insert_spaces_checkbutton, "active",
                SettingsBindFlags.DEFAULT);
            settings.bind ("forget-no-tabs", forget_no_tabs, "active",
                SettingsBindFlags.DEFAULT);
            settings.bind ("display-line-numbers", display_line_nb_checkbutton, "active",
                SettingsBindFlags.DEFAULT);
            settings.bind ("highlight-current-line", hl_current_line_checkbutton,
                "active", SettingsBindFlags.DEFAULT);
            settings.bind ("bracket-matching", bracket_matching_checkbutton, "active",
                SettingsBindFlags.DEFAULT);
            settings.bind ("create-backup-copy", backup_checkbutton, "active",
                SettingsBindFlags.DEFAULT);
            settings.bind ("auto-save", autosave_checkbutton, "active",
                SettingsBindFlags.DEFAULT);
            settings.bind ("auto-save-interval", autosave_spinbutton, "value",
                SettingsBindFlags.DEFAULT);
            settings.bind ("reopen-files", reopen_checkbutton, "active",
                SettingsBindFlags.DEFAULT);

            settings.bind ("web-browser", web_browser, "text",
                SettingsBindFlags.DEFAULT);
            settings.bind ("nb-most-used-symbols", nb_most_used_symbols, "value",
                SettingsBindFlags.DEFAULT);

            GLib.Settings latex_settings =
                new GLib.Settings ("org.gnome.latexila.preferences.latex");
            latex_settings.bind ("interactive-completion", interactive_comp_checkbutton,
                "active", SettingsBindFlags.DEFAULT);
            latex_settings.bind ("interactive-completion-num",
                interactive_comp_spinbutton, "value",
                SettingsBindFlags.DEFAULT);
            latex_settings.bind ("document-view-program", document_view_program, "text",
                SettingsBindFlags.DEFAULT);
            latex_settings.bind ("no-confirm-clean", confirm_clean_up_checkbutton,
                "active", SettingsBindFlags.DEFAULT);
            latex_settings.bind ("automatic-clean", auto_clean_up_checkbutton, "active",
                SettingsBindFlags.DEFAULT);
            latex_settings.bind ("clean-extensions", clean_up_entry, "text",
                SettingsBindFlags.DEFAULT);

            GLib.Settings fb_settings =
                new GLib.Settings ("org.gnome.latexila.preferences.file-browser");
            fb_settings.bind ("show-all-files", file_browser_show_all, "active",
                SettingsBindFlags.DEFAULT);
            fb_settings.bind ("show-all-files-except", file_browser_except, "active",
                SettingsBindFlags.DEFAULT);
            fb_settings.bind ("show-hidden-files", file_browser_show_hidden, "active",
                SettingsBindFlags.DEFAULT);
            fb_settings.bind ("file-extensions", file_browser_entry, "text",
                SettingsBindFlags.DEFAULT);

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

            // select style scheme on change
            settings.changed["scheme"].connect ((setting, key) =>
            {
                string val = setting.get_string (key);

                TreeModel model = schemes_treeview.model;
                TreeIter iter;
                bool valid = model.get_iter_first (out iter);

                while (valid)
                {
                    string scheme;
                    model.get (iter, StyleSchemes.ID, out scheme, -1);
                    if (scheme == val)
                    {
                        TreeSelection select = schemes_treeview.get_selection ();
                        select.select_iter (iter);
                        return;
                    }
                    valid = model.iter_next (ref iter);
                }
            });

            // forget no tabs sensitivity
            set_sensitivity (settings, "insert-spaces", forget_no_tabs);

            // autosave spinbutton sensitivity
            set_sensitivity (settings, "auto-save", autosave_spinbutton);

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

            // interactive completion spinbutton sensitivity
            set_sensitivity (latex_settings, "interactive-completion",
                interactive_comp_spinbutton);

            // interactive completion label
            int min_nb_chars = latex_settings.get_int ("interactive-completion-num");
            interactive_comp_label.label =
                min_nb_chars > 1 ? _("characters") : _("character");
            latex_settings.changed["interactive-completion-num"].connect (
                (setting, key) =>
            {
                int val = setting.get_int (key);
                interactive_comp_label.label = val > 1 ? _("characters") : _("character");
            });

            // font hbox sensitivity
            set_sensitivity (settings, "use-default-font", font_hbox, false);

            // default font checkbutton label
            set_system_font_label (default_font_checkbutton);

            AppSettings app_settings = AppSettings.get_default ();
            app_settings.notify["system-font"].connect (() =>
            {
                set_system_font_label (default_font_checkbutton);
            });

            // automatic clean-up sensitivity
            set_sensitivity (latex_settings, "no-confirm-clean",
                auto_clean_up_checkbutton);

            // file browser settings sensitivity
            set_sensitivity (fb_settings, "show-all-files", vbox_file_browser_show_all);
            set_sensitivity (fb_settings, "show-all-files", file_browser_entry, false);

            // build tools
            init_build_tools_treeview ();
            init_build_tools_buttons (bt_new, bt_delete, bt_up, bt_down, bt_properties,
                bt_reset);

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

    private void set_sensitivity (GLib.Settings settings, string key, Widget widget,
        bool must_be_enabled = true)
    {
        bool val = settings.get_boolean (key);
        widget.set_sensitive (must_be_enabled ? val : ! val);

        settings.changed[key].connect ((setting, k) =>
        {
            bool v = setting.get_boolean (k);
            widget.set_sensitive (must_be_enabled ? v : ! v);
        });
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
        ListStore list_store = new ListStore (StyleSchemes.N_COLUMNS, typeof (string),
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
        SHOW,
        PIXBUF,
        LABEL,
        DESCRIPTION,
        N_COLUMNS
    }

    private void init_build_tools_treeview ()
    {
        build_tools_store = new ListStore (BuildToolColumn.N_COLUMNS, typeof (bool),
            typeof (string), typeof (string), typeof (string));
        build_tools_view.set_model (build_tools_store);

        TreeViewColumn column = new TreeViewColumn ();
        build_tools_view.append_column (column);

        CellRendererToggle toggle_renderer = new CellRendererToggle ();
        column.pack_start (toggle_renderer, false);
        column.set_attributes (toggle_renderer, "active", BuildToolColumn.SHOW, null);

        column = new TreeViewColumn ();
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
        update_build_tools_store ();

        /* show/hide build tool */
        toggle_renderer.toggled.connect ((path_string) =>
        {
            TreeIter iter;
            build_tools_store.get_iter_from_string (out iter, path_string);
            bool val;
            TreeModel model = (TreeModel) build_tools_store;
            model.get (iter, BuildToolColumn.SHOW, out val, -1);

            val = ! val;
            build_tools_store.set (iter, BuildToolColumn.SHOW, val, -1);

            int num = path_string.to_int ();
            unowned LinkedList<BuildTool?> build_tools =
                BuildTools.get_default ().get_build_tools ();
            BuildTool build_tool = build_tools.get (num);
            build_tool.show = val;

            BuildTools.get_default ().update (num, build_tool);
        });
    }

    private void update_build_tools_store ()
    {
        build_tools_store.clear ();

        unowned LinkedList<BuildTool?> tools =
            BuildTools.get_default ().get_build_tools ();
        foreach (BuildTool tool in tools)
        {
            TreeIter iter;
            build_tools_store.append (out iter);
            build_tools_store.set (iter,
                BuildToolColumn.SHOW, tool.show,
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
                                           Button bt_properties,
                                           Button bt_reset)
    {

        bt_new.clicked.connect (() =>
        {
            run_build_tool_dialog (-1);
        });

        bt_properties.clicked.connect (() =>
        {
            int num = Utils.get_selected_row (build_tools_view);
            run_build_tool_dialog (num);
        });

        bt_delete.clicked.connect (() =>
        {
            TreeIter iter;
            int i = Utils.get_selected_row (build_tools_view, out iter);
            if (i == -1)
                return;

            string label;
            TreeModel model = (TreeModel) build_tools_store;
            model.get (iter, BuildToolColumn.LABEL, out label, -1);

            Dialog dialog = new MessageDialog (this, DialogFlags.DESTROY_WITH_PARENT,
                MessageType.QUESTION, ButtonsType.NONE,
                _("Do you really want to delete the build tool \"%s\"?"),
                label);

            dialog.add_buttons (STOCK_CANCEL, ResponseType.CANCEL,
                STOCK_DELETE, ResponseType.YES);

            if (dialog.run () == ResponseType.YES)
            {
                build_tools_store.remove (iter);
                BuildTools.get_default ().delete (i);
            }

            dialog.destroy ();
        });

        bt_up.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (build_tools_view, out iter1);
            if (i != -1 && i > 0)
            {
                iter2 = iter1;
                if (Utils.tree_model_iter_prev (build_tools_store, ref iter2))
                {
                    build_tools_store.swap (iter1, iter2);
                    BuildTools.get_default ().move_up (i);
                }
            }
        });

        bt_down.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (build_tools_view, out iter1);
            if (i != -1)
            {
                iter2 = iter1;
                if (build_tools_store.iter_next (ref iter2))
                {
                    build_tools_store.swap (iter1, iter2);
                    BuildTools.get_default ().move_down (i);
                }
            }
        });

        bt_reset.clicked.connect (() =>
        {
            Dialog dialog = get_reset_all_confirm_dialog (
                _("Do you really want to reset all build tools?"));

            if (dialog.run () == ResponseType.YES)
            {
                BuildTools.get_default ().reset_all ();
                update_build_tools_store ();
            }

            dialog.destroy ();
        });
    }

    private Dialog get_reset_all_confirm_dialog (string msg)
    {
        Dialog dialog = new MessageDialog (this, DialogFlags.DESTROY_WITH_PARENT,
            MessageType.QUESTION, ButtonsType.NONE, msg);

        dialog.add_button (STOCK_CANCEL, ResponseType.CANCEL);

        Button button = new Button.with_label (_("Reset All"));
        Image image = new Image.from_stock (STOCK_CLEAR, IconSize.BUTTON);
        button.set_image (image);
        button.show_all ();
        dialog.add_action_widget (button, ResponseType.YES);

        return dialog;
    }

    private void run_build_tool_dialog (int num)
    {
        if (BuildToolDialog.show_me (get_transient_for (), num))
            update_build_tools_store ();
    }
}
