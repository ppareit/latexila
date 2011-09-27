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

        Dialog dialog = new Dialog.with_buttons (null,
            window,
            DialogFlags.DESTROY_WITH_PARENT,
            _("Close without Saving"), ResponseType.CLOSE,
            Stock.CANCEL, ResponseType.CANCEL,
            Stock.SAVE, ResponseType.ACCEPT,
            null);

        HBox hbox = new HBox (false, 12);
        hbox.border_width = 5;
        VBox content_area = (VBox) dialog.get_content_area ();
        content_area.pack_start (hbox, true, true, 0);

        /* image */
        Image image = new Image.from_stock (Stock.DIALOG_WARNING, IconSize.DIALOG);
        image.set_alignment ((float) 0.5, (float) 0.0);
        hbox.pack_start (image, false, false, 0);

        VBox vbox = new VBox (false, 12);
        hbox.pack_start (vbox, true, true, 0);

        /* primary label */
        Label primary_label = new Label (null);
        primary_label.set_line_wrap (true);
        primary_label.set_use_markup (true);
        primary_label.set_alignment ((float) 0.0, (float) 0.5);
        primary_label.set_selectable (true);
        primary_label.set_markup ("<span weight=\"bold\" size=\"larger\">"
            + _("There are %d documents with unsaved changes. Save changes before closing?")
            .printf (unsaved_docs.length ())
            + "</span>");

        vbox.pack_start (primary_label, false, false, 0);

        VBox vbox2 = new VBox (false, 8);
        vbox.pack_start (vbox2, false, false, 0);

        Label select_label = new Label (_("Select the documents you want to save:"));
        select_label.set_line_wrap (true);
        select_label.set_alignment ((float) 0.0, (float) 0.5);
        vbox2.pack_start (select_label, false, false, 0);

        /* unsaved documents list with checkboxes */
        TreeView treeview = new TreeView ();
        treeview.set_size_request (260, 120);
        treeview.headers_visible = false;
        treeview.enable_search = false;

        ListStore store = new ListStore (UnsavedDocColumn.N_COLUMNS, typeof (bool),
            typeof (string), typeof (Document));

        // fill the list
        foreach (Document doc in unsaved_docs)
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
        CellRendererToggle renderer1 = new CellRendererToggle ();

        renderer1.toggled.connect ((path_str) =>
        {
            TreePath path = new TreePath.from_string (path_str);
            TreeIter iter;
            bool active;
            store.get_iter (out iter, path);
            store.get (iter, UnsavedDocColumn.SAVE, out active, -1);
            // inverse the value
            store.set (iter, UnsavedDocColumn.SAVE, ! active, -1);
        });

        TreeViewColumn column = new TreeViewColumn.with_attributes ("Save?", renderer1,
            "active", UnsavedDocColumn.SAVE, null);
        treeview.append_column (column);

        CellRendererText renderer2 = new CellRendererText ();
        column = new TreeViewColumn.with_attributes ("Name", renderer2,
            "text", UnsavedDocColumn.NAME, null);
        treeview.append_column (column);

        // with a scrollbar
        ScrolledWindow sw = (ScrolledWindow) Utils.add_scrollbar (treeview);
        sw.set_shadow_type (ShadowType.IN);
        vbox2.pack_start (sw, true, true, 0);

        /* secondary label */
        Label secondary_label = new Label (
            _("If you don't save, all your changes will be permanently lost."));
        secondary_label.set_line_wrap (true);
        secondary_label.set_alignment ((float) 0.0, (float) 0.5);
        secondary_label.set_selectable (true);
        vbox2.pack_start (secondary_label, false, false, 0);

        hbox.show_all ();

        int resp = dialog.run ();

        // close without saving
        if (resp == ResponseType.CLOSE)
            window.remove_all_tabs ();

        // save files
        else if (resp == ResponseType.ACCEPT)
        {
            // close all saved documents
            foreach (Document doc in window.get_documents ())
            {
                if (! doc.get_modified ())
                    window.close_tab (doc.tab);
            }

            // get unsaved docs to save
            List<Document> selected_docs = null;
            TreeIter iter;
            bool valid = store.get_iter_first (out iter);
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

            foreach (Document doc in selected_docs)
            {
                if (window.save_document (doc, false))
                    window.close_tab (doc.tab, true);
            }
        }

        dialog.destroy ();
    }
}
