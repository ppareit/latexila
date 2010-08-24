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

namespace Dialogs
{
    private enum UnsavedDocColumn
    {
        SAVE,
        NAME,
        DOC, // a handy pointer to the document
        N_COLUMNS
    }

    public void
    close_several_unsaved_documents (MainWindow window, List<Document> unsaved_docs)
    {
        return_if_fail (unsaved_docs.length () >= 2);

        var dialog = new Dialog.with_buttons (null,
            window,
            DialogFlags.DESTROY_WITH_PARENT,
            _("Close without Saving"), ResponseType.CLOSE,
            STOCK_CANCEL, ResponseType.CANCEL,
            STOCK_SAVE, ResponseType.ACCEPT,
            null);

        dialog.has_separator = false;

        var hbox = new HBox (false, 12);
        hbox.border_width = 5;
        var content_area = (VBox) dialog.get_content_area ();
        content_area.pack_start (hbox, true, true, 0);

        /* image */
        var image = new Image.from_stock (STOCK_DIALOG_WARNING, IconSize.DIALOG);
        image.set_alignment ((float) 0.5, (float) 0.0);
        hbox.pack_start (image, false, false, 0);

        var vbox = new VBox (false, 12);
        hbox.pack_start (vbox, true, true, 0);

        /* primary label */
        var primary_label = new Label (null);
        primary_label.set_line_wrap (true);
        primary_label.set_use_markup (true);
        primary_label.set_alignment ((float) 0.0, (float) 0.5);
        primary_label.set_selectable (true);
        primary_label.set_markup ("<span weight=\"bold\" size=\"larger\">"
            + _("There are %d documents with unsaved changes. Save changes before closing?")
            .printf (unsaved_docs.length ())
            + "</span>");

        vbox.pack_start (primary_label, false, false, 0);

        var vbox2 = new VBox (false, 8);
        vbox.pack_start (vbox2, false, false, 0);

        var select_label = new Label (_("Select the documents you want to save:"));
        select_label.set_line_wrap (true);
        select_label.set_alignment ((float) 0.0, (float) 0.5);
        vbox2.pack_start (select_label, false, false, 0);

        /* unsaved documents list with checkboxes */
        var treeview = new TreeView ();
        treeview.set_size_request (260, 120);
        treeview.headers_visible = false;
        treeview.enable_search = false;

        var store = new ListStore (UnsavedDocColumn.N_COLUMNS, typeof (bool),
            typeof (string), typeof (Document));

        // fill the list
        foreach (var doc in unsaved_docs)
        {
            TreeIter iter;
            store.append (out iter);
            store.set (iter,
                UnsavedDocColumn.SAVE, true,
                UnsavedDocColumn.NAME, doc.tab.label_text,
                UnsavedDocColumn.DOC, doc,
                -1);
        }

        treeview.set_model (store);
        var renderer1 = new CellRendererToggle ();

        renderer1.toggled.connect ((path_str) =>
        {
            var path = new TreePath.from_string (path_str);
            TreeIter iter;
            bool active;
            store.get_iter (out iter, path);
            store.get (iter, UnsavedDocColumn.SAVE, out active, -1);
            // inverse the value
            store.set (iter, UnsavedDocColumn.SAVE, ! active, -1);
        });

        var column = new TreeViewColumn.with_attributes ("Save?", renderer1,
            "active", UnsavedDocColumn.SAVE, null);
        treeview.append_column (column);

        var renderer2 = new CellRendererText ();
        column = new TreeViewColumn.with_attributes ("Name", renderer2,
            "text", UnsavedDocColumn.NAME, null);
        treeview.append_column (column);

        // with a scrollbar
        ScrolledWindow sw = (ScrolledWindow) Utils.add_scrollbar (treeview);
        sw.set_shadow_type (ShadowType.IN);
        vbox2.pack_start (sw, true, true, 0);

        /* secondary label */
        var secondary_label = new Label (_("If you don't save, all your changes will be permanently lost."));
        secondary_label.set_line_wrap (true);
        secondary_label.set_alignment ((float) 0.0, (float) 0.5);
        secondary_label.set_selectable (true);
        vbox2.pack_start (secondary_label, false, false, 0);

        hbox.show_all ();

        var resp = dialog.run ();

        // close without saving
        if (resp == ResponseType.CLOSE)
            window.remove_all_tabs ();

        // save files
        else if (resp == ResponseType.ACCEPT)
        {
            // close all saved documents
            foreach (var doc in window.get_documents ())
            {
                if (! doc.get_modified ())
                    window.close_tab (doc.tab);
            }

            // get unsaved docs to save
            List<Document> selected_docs = null;
            TreeIter iter;
            var valid = store.get_iter_first (out iter);
            while (valid)
            {
                bool selected;
                Document doc;
                store.get (iter,
                    UnsavedDocColumn.SAVE, out selected,
                    UnsavedDocColumn.DOC, out doc,
                    -1);
                if (selected)
                    selected_docs.prepend (doc);

                // if unsaved doc not selected, force to close the tab
                else
                    window.close_tab (doc.tab, true);

                valid = store.iter_next (ref iter);
            }
            selected_docs.reverse ();

            foreach (var doc in selected_docs)
            {
                if (window.save_document (doc, false))
                    window.close_tab (doc.tab, true);
            }
        }

        dialog.destroy ();
    }

    private enum CleanFileColumn
    {
        DELETE,
        NAME,
        N_COLUMNS
    }

    public bool
    confirm_clean_build_files (MainWindow window, File directory, string[] basenames)
    {
        return_if_fail (basenames.length > 0);

        var dialog = new Dialog.with_buttons (null,
            window,
            DialogFlags.DESTROY_WITH_PARENT,
            STOCK_CANCEL, ResponseType.CANCEL,
            STOCK_DELETE, ResponseType.ACCEPT,
            null);

        dialog.has_separator = false;

        HBox hbox = new HBox (false, 12);
        hbox.border_width = 5;
        VBox content_area = (VBox) dialog.get_content_area ();
        content_area.pack_start (hbox, true, true, 0);

        /* image */
        var image = new Image.from_stock (STOCK_DIALOG_WARNING, IconSize.DIALOG);
        image.set_alignment ((float) 0.5, (float) 0.0);
        hbox.pack_start (image, false, false, 0);

        VBox vbox = new VBox (false, 12);
        hbox.pack_start (vbox, true, true, 0);

        /* primary label */
        var primary_label = new Label (null);
        primary_label.set_line_wrap (true);
        primary_label.set_use_markup (true);
        primary_label.set_alignment ((float) 0.0, (float) 0.5);
        primary_label.set_selectable (true);
        primary_label.set_markup ("<span weight=\"bold\" size=\"larger\">"
            + _("Do you really want to delete these files?") + "</span>");

        vbox.pack_start (primary_label, false, false, 0);

        VBox vbox2 = new VBox (false, 8);
        vbox.pack_start (vbox2, false, false);

        var select_label = new Label (_("Select the files you want to delete:"));
        select_label.set_line_wrap (true);
        select_label.set_alignment ((float) 0.0, (float) 0.5);
        vbox2.pack_start (select_label, false, false, 0);

        /* files list with checkboxes */
        TreeView treeview = new TreeView ();
        treeview.set_size_request (260, 120);
        treeview.headers_visible = false;
        treeview.enable_search = false;

        ListStore store = new ListStore (CleanFileColumn.N_COLUMNS, typeof (bool),
            typeof (string));

        // fill the list
        foreach (string basename in basenames)
        {
            TreeIter iter;
            store.append (out iter);
            store.set (iter,
                CleanFileColumn.DELETE, true,
                CleanFileColumn.NAME, basename,
                -1);
        }

        treeview.set_model (store);
        var renderer1 = new CellRendererToggle ();

        renderer1.toggled.connect ((path_str) =>
        {
            var path = new TreePath.from_string (path_str);
            TreeIter iter;
            bool active;
            store.get_iter (out iter, path);
            store.get (iter, CleanFileColumn.DELETE, out active, -1);
            // inverse the value
            store.set (iter, CleanFileColumn.DELETE, ! active, -1);
        });

        var column = new TreeViewColumn.with_attributes ("Delete?", renderer1,
            "active", CleanFileColumn.DELETE, null);
        treeview.append_column (column);

        var renderer2 = new CellRendererText ();
        column = new TreeViewColumn.with_attributes ("Name", renderer2,
            "text", CleanFileColumn.NAME, null);
        treeview.append_column (column);

        // with a scrollbar
        ScrolledWindow sw = (ScrolledWindow) Utils.add_scrollbar (treeview);
        sw.set_shadow_type (ShadowType.IN);
        vbox2.pack_start (sw, true, true, 0);

        hbox.show_all ();

        /* run */
        bool ret = false;
        if (dialog.run () == ResponseType.ACCEPT)
        {
            // get files to delete
            string[] selected_files = {};
            TreeIter iter;
            bool valid = store.get_iter_first (out iter);
            while (valid)
            {
                bool selected;
                string basename;
                store.get (iter,
                    CleanFileColumn.DELETE, out selected,
                    CleanFileColumn.NAME, out basename,
                    -1);
                if (selected)
                    selected_files += basename;

                valid = store.iter_next (ref iter);
            }

            foreach (string selected_file in selected_files)
            {
                ret = true;
                File file = directory.get_child (selected_file);
                Utils.delete_file (file);
            }
        }

        dialog.destroy ();
        return ret;
    }
}
