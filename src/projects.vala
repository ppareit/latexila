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

public class Projects : GLib.Object
{
    public static void new_project (MainWindow main_window)
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
            if (! main_file.has_prefix (directory))
            {
                Dialog error_dialog = new MessageDialog (dialog,
                    DialogFlags.DESTROY_WITH_PARENT,
                    MessageType.ERROR,
                    ButtonsType.OK,
                    _("The Main File is not in the directory."));
                error_dialog.run ();
                error_dialog.destroy ();
                continue;
            }

            // try to add the project
            Project project = Project ();
            project.directory = directory;
            project.main_file = main_file;

            if (AppSettings.get_default ().add_project (project))
                break;

            // conflict with another project
            Dialog error_dialog = new MessageDialog (dialog,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.ERROR,
                ButtonsType.OK,
                _("There is a conflict with another project."));
            error_dialog.run ();
            error_dialog.destroy ();
        }

        dialog.destroy ();
    }
}
