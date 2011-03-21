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

public class Structure : VBox
{
    private enum StructType
    {
        PART,
        CHAPTER,
        SECTION,
        SUBSECTION,
        SUBSUBSECTION,
        PARAGRAPH,
        SUBPARAGRAPH,
        LABEL,
        TODO,
        FIXME,
        TABLE,
        IMAGE,
        INCLUDE
    }

    private enum StructItem
    {
        PIXBUF,
        TYPE,
        NAME,
        N_COLUMNS
    }

    private TreeStore _tree_store;
    private TreeView _tree_view;

    public Structure ()
    {
        init_tree_view ();
        show_all ();
    }

    private void init_tree_view ()
    {
        _tree_store = new TreeStore (StructItem.N_COLUMNS,
            typeof (string),     // pixbuf (stock-id)
            typeof (StructType), // item type
            typeof (string)      // name
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
        column.set_attributes (text_renderer, "text", StructItem.NAME, null);

        // with a scrollbar
        var sw = Utils.add_scrollbar (_tree_view);
        pack_start (sw);
    }

    private string? get_icon_from_type (StructType type)
    {
        switch (type)
        {
            case StructType.PART:
                return "tree_part";
            case StructType.CHAPTER:
                return "tree_chapter";
            case StructType.SECTION:
                return "tree_section";
            case StructType.SUBSECTION:
                return "tree_subsection";
            case StructType.SUBSUBSECTION:
                return "tree_subsubsection";
            case StructType.PARAGRAPH:
            case StructType.SUBPARAGRAPH:
                return "tree_paragraph";
            case StructType.LABEL:
                return "tree_label";
            case StructType.TODO:
            case StructType.FIXME:
                return "tree_todo";
            case StructType.TABLE:
                return "table";
            case StructType.IMAGE:
                return "image";
            case StructType.INCLUDE:
                return "tree_include";
            default:
                return_val_if_reached (null);
        }
    }

    private TreeIter add_item (TreeIter? parent, StructType type, string name)
    {
        TreeIter iter;
        _tree_store.append (out iter, parent);
        _tree_store.set (iter,
            StructItem.PIXBUF, get_icon_from_type (type),
            StructItem.TYPE, type,
            StructItem.NAME, name,
            -1);

        return iter;
    }
}
