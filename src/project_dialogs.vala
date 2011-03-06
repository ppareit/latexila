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

namespace ProjectDialogs
{
    public void new_project (MainWindow main_window)
    {
        Dialog dialog = new Dialog.with_buttons (_("New Project"), main_window,
            DialogFlags.DESTROY_WITH_PARENT,
            STOCK_CANCEL, ResponseType.CANCEL,
            STOCK_NEW, ResponseType.OK,
            null);

        /* create dialog widgets */
        VBox content_area = (VBox) dialog.get_content_area ();

        HBox hbox = new HBox (false, 6);
        VBox vbox1 = new VBox (true, 6);
        VBox vbox2 = new VBox (true, 6);
        hbox.pack_start (vbox1, false, false);
        hbox.pack_start (vbox2);
        hbox.border_width = 6;

        Label label1 = new Label (null);
        label1.set_markup ("<b>" + _("Directory:") + "</b>");
        Label label2 = new Label (null);
        label2.set_markup ("<b>" + _("Main File:") + "</b>");
        vbox1.pack_start (label1);
        vbox1.pack_start (label2);

        FileChooserButton file_chooser_button1 = new FileChooserButton (_("Directory"),
            FileChooserAction.SELECT_FOLDER);
        FileChooserButton file_chooser_button2 = new FileChooserButton (_("Main File"),
            FileChooserAction.OPEN);

        vbox2.pack_start (file_chooser_button1);
        vbox2.pack_start (file_chooser_button2);

        content_area.pack_start (hbox);
        content_area.show_all ();

        /* callbacks */
        file_chooser_button1.file_set.connect (() =>
        {
            File dir = file_chooser_button1.get_file ();
            try
            {
                file_chooser_button2.set_current_folder_file (dir);
            }
            catch (Error e) {}
        });

        /* if a document is opened, go to the document's directory */
        Document? doc = main_window.active_document;
        if (doc != null)
        {
            try
            {
                file_chooser_button1.set_file (doc.location.get_parent ());
                file_chooser_button2.set_file (doc.location);
            }
            catch (GLib.Error e) {}
        }

        while (dialog.run () == ResponseType.OK)
        {
            File? directory = file_chooser_button1.get_file ();
            File? main_file = file_chooser_button2.get_file ();

            if (directory == null || main_file == null)
                continue;

            // main file not in directory
            if (! main_file_is_in_directory (dialog, main_file, directory))
                continue;

            // try to add the project
            Project project = Project ();
            project.directory = directory;
            project.main_file = main_file;

            File conflict;
            if (Projects.get_default ().add (project, out conflict))
                break;

            // conflict with another project
            Dialog error_dialog = new MessageDialog (dialog,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.ERROR,
                ButtonsType.OK,
                _("There is a conflict with the project \"%s\"."),
                Utils.replace_home_dir_with_tilde (conflict.get_parse_name ()) + "/");
            error_dialog.run ();
            error_dialog.destroy ();
        }

        dialog.destroy ();
    }

    // returns true if configuration changed
    public bool configure_project (Window main_window, int project_id)
    {
        Project? project = Projects.get_default ().get (project_id);
        return_val_if_fail (project != null, false);

        Dialog dialog = new Dialog.with_buttons (_("Configure Project"),
            main_window,
            DialogFlags.DESTROY_WITH_PARENT,
            STOCK_CANCEL, ResponseType.CANCEL,
            STOCK_OK, ResponseType.OK,
            null);

        /* create dialog widgets */
        VBox content_area = (VBox) dialog.get_content_area ();

        Label location = new Label (_("Location of the project: %s").printf (
            Utils.replace_home_dir_with_tilde (project.directory.get_parse_name ())
            + "/"));
        location.set_line_wrap (true);

        content_area.pack_start (location, false, false, 6);

        HBox hbox = new HBox (false, 6);
        content_area.pack_start (hbox);

        Label label = new Label (_("Main File:"));
        hbox.pack_start (label, false, false);

        FileChooserButton file_chooser_button = new FileChooserButton (_("Main File"),
            FileChooserAction.OPEN);
        hbox.pack_start (file_chooser_button);

        content_area.show_all ();

        try
        {
            file_chooser_button.set_file (project.main_file);
        }
        catch (Error e) {}

        /* run */
        bool ret = false;
        while (dialog.run () == ResponseType.OK)
        {
            File? main_file = file_chooser_button.get_file ();

            if (main_file == null)
                continue;

            // main file not in directory
            if (! main_file_is_in_directory (dialog, main_file, project.directory))
                continue;

            ret = Projects.get_default ().change_main_file (project_id, main_file);
            break;
        }

        dialog.destroy ();
        return ret;
    }

    private enum ProjectColumn
    {
        DIRECTORY,
        MAIN_FILE,
        N_COLUMNS
    }

    public void manage_projects (MainWindow main_window)
    {
        Dialog dialog = new Dialog.with_buttons (_("Manage Projects"),
            main_window,
            DialogFlags.DESTROY_WITH_PARENT,
            STOCK_CLOSE, ResponseType.OK,
            null);

        VBox content_area = (VBox) dialog.get_content_area ();

        /* treeview */
        ListStore store = new ListStore (ProjectColumn.N_COLUMNS, typeof (string),
            typeof (string));
        update_model (store);

        TreeView treeview = new TreeView.with_model (store);
        treeview.set_size_request (400, 150);
        treeview.rules_hint = true;

        // column directory
        TreeViewColumn column = new TreeViewColumn ();
        treeview.append_column (column);
        column.title = _("Directory");

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        pixbuf_renderer.stock_id = STOCK_DIRECTORY;
        column.pack_start (pixbuf_renderer, false);

        CellRendererText text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", ProjectColumn.DIRECTORY, null);

        // column main file
        column = new TreeViewColumn ();
        treeview.append_column (column);
        column.title = _("Main File");

        pixbuf_renderer = new CellRendererPixbuf ();
        pixbuf_renderer.stock_id = STOCK_FILE;
        column.pack_start (pixbuf_renderer, false);

        text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", ProjectColumn.MAIN_FILE, null);

        // selection
        TreeSelection select = treeview.get_selection ();
        select.set_mode (SelectionMode.SINGLE);

        // with scrollbar
        var sw = Utils.add_scrollbar (treeview);
        content_area.pack_start (sw);

        /* buttons */
        HBox hbox = new HBox (false, 5);
        content_area.pack_start (hbox, false, false, 5);

        Button edit_button = new Button.from_stock (STOCK_PROPERTIES);
        Button delete_button = new Button.from_stock (STOCK_DELETE);

        Button clear_all_button = new Button.with_label (_("Clear All"));
        Image image = new Image.from_stock (STOCK_CLEAR, IconSize.MENU);
        clear_all_button.set_image (image);

        hbox.pack_start (edit_button);
        hbox.pack_start (delete_button);
        hbox.pack_start (clear_all_button);

        content_area.show_all ();

        /* callbacks */
        edit_button.clicked.connect (() =>
        {
            int i = Utils.get_selected_row (treeview);
            if (i != -1 && configure_project (dialog, i))
                update_model (store);
        });

        delete_button.clicked.connect (() =>
        {
            TreeIter iter;
            int i = Utils.get_selected_row (treeview, out iter);
            if (i == -1)
                return;

            string directory;
            TreeModel model = (TreeModel) store;
            model.get (iter, ProjectColumn.DIRECTORY, out directory, -1);

            Dialog delete_dialog = new MessageDialog (dialog,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.QUESTION, ButtonsType.NONE,
                _("Do you really want to delete the project \"%s\"?"),
                directory);

            delete_dialog.add_buttons (STOCK_CANCEL, ResponseType.CANCEL,
                STOCK_DELETE, ResponseType.YES);

            if (delete_dialog.run () == ResponseType.YES)
            {
                store.remove (iter);
                Projects.get_default ().delete (i);
            }

            delete_dialog.destroy ();
        });

        clear_all_button.clicked.connect (() =>
        {
            Dialog clear_dialog = new MessageDialog (dialog,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.QUESTION,
                ButtonsType.NONE,
                _("Do you really want to clear all projects?"));

            clear_dialog.add_button (STOCK_CANCEL, ResponseType.CANCEL);

            Button button = new Button.with_label (_("Clear All"));
            Image img = new Image.from_stock (STOCK_CLEAR, IconSize.BUTTON);
            button.set_image (img);
            button.show_all ();
            clear_dialog.add_action_widget (button, ResponseType.YES);

            if (clear_dialog.run () == ResponseType.YES)
            {
                Projects.get_default ().clear_all ();
                store.clear ();
            }

            clear_dialog.destroy ();
        });

        dialog.run ();
        dialog.destroy ();
    }

    private bool main_file_is_in_directory (Window window, File main_file, File directory)
    {
        if (main_file.has_prefix (directory))
            return true;

        Dialog error_dialog = new MessageDialog (window,
            DialogFlags.DESTROY_WITH_PARENT,
            MessageType.ERROR,
            ButtonsType.OK,
            _("The Main File is not in the directory."));

        error_dialog.run ();
        error_dialog.destroy ();
        return false;
    }

    private void update_model (ListStore model)
    {
        model.clear ();

        unowned Gee.LinkedList<Project?> projects =
            Projects.get_default ().get_projects ();

        foreach (Project project in projects)
        {
            string uri_directory = project.directory.get_parse_name ();
            string uri_main_file = project.main_file.get_parse_name ();

            string dir = Utils.replace_home_dir_with_tilde (uri_directory) + "/";

            // relative path
            string main_file =
                uri_main_file[uri_directory.length + 1 : uri_main_file.length];

            TreeIter iter;
            model.append (out iter);
            model.set (iter,
                ProjectColumn.DIRECTORY, dir,
                ProjectColumn.MAIN_FILE, main_file,
                -1);
        }
    }
}
