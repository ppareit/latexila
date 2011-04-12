/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2011 Sébastien Wilmet
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

public enum StructItem
{
    PIXBUF,
    TYPE,
    TEXT,
    TOOLTIP,
    MARK,
    N_COLUMNS
}

public class Structure : VBox
{
    private unowned MainWindow _main_window;
    private TreeStore _tree_store;
    private TreeView _tree_view;

    public Structure (MainWindow main_window)
    {
        GLib.Object (spacing: 3);
        _main_window = main_window;

        init_toolbar ();
        init_tree_view ();
        show_all ();
    }

    private void init_toolbar ()
    {
        HBox hbox = new HBox (true, 0);
        pack_start (hbox, false, false);

        Button refresh_button = Utils.get_toolbar_button (Stock.REFRESH);
        hbox.pack_start (refresh_button);

        refresh_button.clicked.connect (() =>
        {
            parse_document (_main_window.active_document);
        });
    }

    private void init_tree_view ()
    {
        _tree_store = new TreeStore (StructItem.N_COLUMNS,
            typeof (string),     // pixbuf (stock-id)
            typeof (int),        // item type
            typeof (string),     // text
            typeof (string),     // tooltip
            typeof (TextMark)    // mark
            );

        _tree_view = new TreeView.with_model (_tree_store);
        _tree_view.headers_visible = false;

        TreeViewColumn column = new TreeViewColumn ();
        _tree_view.append_column (column);

        // icon
        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        column.pack_start (pixbuf_renderer, false);
        column.set_attributes (pixbuf_renderer, "stock-id", StructItem.PIXBUF, null);

        // name
        CellRendererText text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", StructItem.TEXT, null);

        // tooltip
        _tree_view.set_tooltip_column (StructItem.TOOLTIP);

        // selection
        TreeSelection select = _tree_view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);
        select.set_select_function (on_row_selection);

        // with a scrollbar
        var sw = Utils.add_scrollbar (_tree_view);
        pack_start (sw);
    }

    private bool on_row_selection (TreeSelection selection, TreeModel model,
        TreePath path, bool path_currently_selected)
    {
        TreeIter tree_iter;
        if (! model.get_iter (out tree_iter, path))
            // the row is not selected
            return false;

        TextMark mark;
        model.get (tree_iter, StructItem.MARK, out mark, -1);

        TextBuffer doc = mark.get_buffer ();
        return_val_if_fail (doc == _main_window.active_document, false);

        // place the cursor so the line is highlighted (by default)
        TextIter text_iter;
        doc.get_iter_at_mark (out text_iter, mark);
        doc.place_cursor (text_iter);
        _main_window.active_view.scroll_to_cursor ();

        // the row is selected
        return true;
    }

    private void parse_document (Document doc)
    {
        _tree_store.clear ();
        _tree_view.columns_autosize ();

        DocumentStructure doc_struct = doc.get_structure ();
        doc_struct.parse ();
        doc_struct.populate_tree_store (_tree_store);
        _tree_view.expand_all ();
    }
}
