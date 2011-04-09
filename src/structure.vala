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
        PART = 0,
        CHAPTER,
        SECTION,
        SUBSECTION,
        SUBSUBSECTION,
        PARAGRAPH,
        SUBPARAGRAPH,
        LABEL,
        INCLUDE,
        TABLE,
        IMAGE,
        TODO,
        FIXME
    }

    private enum StructItem
    {
        PIXBUF,
        TYPE,
        TEXT,
        TOOLTIP,
        MARK,
        N_COLUMNS
    }

    // command like \name{text}
    private struct StructSimpleCommand
    {
        StructType type;
        string name;
    }

    private struct DataNode
    {
        StructType type;
        string text;
        TextMark mark;
    }

    private unowned MainWindow _main_window;
    private TreeStore _tree_store;
    private TreeView _tree_view;
    private int _nb_marks = 0;
    private static const string MARK_NAME_PREFIX = "struct_item_";

    private bool _insert_at_end = true;
    private Node<DataNode?> _tree;

    private const StructSimpleCommand[] _simple_commands =
    {
        { StructType.PART,          "part" },
        { StructType.PART,          "part*" },
        { StructType.CHAPTER,       "chapter" },
        { StructType.CHAPTER,       "chapter*" },
        { StructType.SECTION,       "section" },
        { StructType.SECTION,       "section*" },
        { StructType.SUBSECTION,    "subsection" },
        { StructType.SUBSECTION,    "subsection*" },
        { StructType.SUBSUBSECTION, "subsubsection" },
        { StructType.SUBSUBSECTION, "subsubsection*" },
        { StructType.PARAGRAPH,     "paragraph" },
        { StructType.PARAGRAPH,     "paragraph*" },
        { StructType.SUBPARAGRAPH,  "subparagraph" },
        { StructType.SUBPARAGRAPH,  "subparagraph*" },
        { StructType.LABEL,         "label" },
        { StructType.INCLUDE,       "input" },
        { StructType.INCLUDE,       "include" }
    };

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

        Button refresh_button = Utils.get_toolbar_button (STOCK_REFRESH);
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
            typeof (StructType), // item type
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
        if (doc != _main_window.active_document)
            return false;

        // place the cursor so the line is highlighted (by default)
        TextIter text_iter;
        doc.get_iter_at_mark (out text_iter, mark);
        doc.place_cursor (text_iter);
        _main_window.active_view.scroll_to_cursor ();

        // the row is selected
        return true;
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

    private string? get_tooltip_from_type (StructType type)
    {
        switch (type)
        {
            case StructType.PART:
                return _("Part");

            case StructType.CHAPTER:
                return _("Chapter");

            case StructType.SECTION:
                return _("Section");

            case StructType.SUBSECTION:
                return _("Sub-section");

            case StructType.SUBSUBSECTION:
                return _("Sub-sub-section");

            case StructType.PARAGRAPH:
                return _("Paragraph");

            case StructType.SUBPARAGRAPH:
                return _("Sub-paragraph");

            case StructType.LABEL:
                return _("Label");

            case StructType.TODO:
                return "TODO";

            case StructType.FIXME:
                return "FIXME";

            case StructType.TABLE:
                return _("Table");

            case StructType.IMAGE:
                return _("Figure");

            case StructType.INCLUDE:
                return _("File included");

            default:
                return_val_if_reached (null);
        }
    }

    // The data are first inserted in Gnodes. When the parsing is done, this method is
    // called to populate the tree store with the data contained in the GNodes.
    private void populate_tree_store (Node<DataNode?> node, TreeIter? parent = null,
        bool root_node = true)
    {
        TreeIter? iter = null;
        if (! root_node)
            iter = add_item_to_tree_store (parent, node.data);

        node.children_foreach (TraverseFlags.ALL, (child_node) =>
        {
            populate_tree_store (child_node, iter, false);
        });
    }

    private TreeIter add_item_to_tree_store (TreeIter? parent, DataNode data)
    {
        TreeIter iter;
        _tree_store.append (out iter, parent);
        _tree_store.set (iter,
            StructItem.PIXBUF, get_icon_from_type (data.type),
            StructItem.TYPE, data.type,
            StructItem.TEXT, data.text,
            StructItem.TOOLTIP, get_tooltip_from_type (data.type),
            StructItem.MARK, data.mark,
            -1);

        return iter;
    }

    private void add_item (StructType type, string text, TextIter iter)
    {
        DataNode data = {};
        data.type = type;
        data.text = text;
        data.mark = create_text_mark_from_iter (iter);

        if (_insert_at_end)
            add_item_at_end (data);
        else
            add_item_in_middle (data);
    }

    private void add_item_at_end (DataNode item)
    {
        /* search the parent, based on the type */
        int depth = item.type;
        int cur_depth = StructType.PART;
        unowned Node<DataNode?> parent = _tree;
        while (cur_depth < depth)
        {
            unowned Node<DataNode?> last_child = parent.last_child ();
            if (last_child == null)
                break;

            DataNode child_data = last_child.data;
            if (child_data.type > StructType.SUBPARAGRAPH)
                break;

            parent = last_child;
            cur_depth++;
        }

        // append the item
        parent.append_data (item);
    }

    // In the middle means that we have to find where to insert the data in the tree.
    // If items have to be shifted (for example: insert a chapter in the middle of
    // sections), it will be done by insert_item_at_position().
    private void add_item_in_middle (DataNode item)
    {
        // if the tree is empty
        if (_tree.is_leaf ())
        {
            _tree.append_data (item);
            return;
        }

        int pos = get_position_from_mark (item.mark);
        unowned Node<DataNode?> cur_parent = _tree;
        while (true)
        {
            unowned Node<DataNode?> cur_child = cur_parent.first_child ();
            int child_index = 0;
            while (true)
            {
                int cur_pos = get_position_from_mark (cur_child.data.mark);

                if (cur_pos > pos)
                {
                    if (child_index == 0)
                    {
                        insert_item_at_position (item, cur_parent, child_index);
                        return;
                    }

                    unowned Node<DataNode?> prev_child = cur_child.prev_sibling ();
                    if (prev_child.is_leaf ())
                    {
                        insert_item_at_position (item, cur_parent, child_index);
                        return;
                    }

                    cur_parent = prev_child;
                    break;
                }

                unowned Node<DataNode?> next_child = cur_child.next_sibling ();

                // current child is the last child
                if (next_child == null)
                {
                    if (cur_child.is_leaf ())
                    {
                        insert_item_at_position (item, cur_parent, child_index+1);
                        return;
                    }

                    cur_parent = cur_child;
                    break;
                }

                cur_child = next_child;
                child_index++;
            }
        }
    }

    private void insert_item_at_position (DataNode item, Node<DataNode?> parent, int pos)
    {
        parent.insert_data (pos, item);
    }

    private int get_position_from_mark (TextMark mark)
    {
        TextIter iter;
        TextBuffer doc = mark.get_buffer ();
        doc.get_iter_at_mark (out iter, mark);
        return iter.get_offset ();
    }

    private StructType? get_type_from_simple_command_name (string name)
    {
        foreach (StructSimpleCommand cmd in _simple_commands)
        {
            if (name == cmd.name)
                return cmd.type;
        }

        return null;
    }

    private TextMark create_text_mark_from_iter (TextIter iter)
    {
        TextBuffer doc = iter.get_buffer ();
        string name = MARK_NAME_PREFIX + _nb_marks.to_string ();
        TextMark mark = doc.create_mark (name, iter, false);
        _nb_marks++;

        return mark;
    }

    private void clear_all_structure_marks (TextBuffer doc)
    {
        for (int i = 0 ; i < _nb_marks ; i++)
        {
            string mark_name = MARK_NAME_PREFIX + i.to_string ();
            TextMark? mark = doc.get_mark (mark_name);
            if (mark != null)
                doc.delete_mark (mark);
        }

        _nb_marks = 0;
    }

    private void parse_document (TextBuffer? doc)
    {
        _tree_store.clear ();
        _tree_view.columns_autosize ();
        DataNode empty_data = {};
        _tree = new Node<DataNode?> (empty_data);

        if (doc == null)
            return;

        clear_all_structure_marks (doc);

        /* search commands (begin with a backslash) */

        _insert_at_end = true;

        TextIter iter;
        doc.get_start_iter (out iter);

        while (iter.forward_search ("\\",
            TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY,
            null, out iter, null))
        {
            search_simple_command (iter);
        }

        _insert_at_end = false;

        /* search comments (begin with '%') */

        Regex regex = null;
        try
        {
             regex = new Regex ("^(?P<type>TODO|FIXME)[[:space:]:]*(?P<text>.*)$");
        }
        catch (RegexError e)
        {
            stderr.printf ("Structure: %s\n", e.message);
            return;
        }

        for (doc.get_start_iter (out iter) ;

            iter.forward_search ("%",
            TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY,
            null, out iter, null) ;

            iter.forward_visible_line ())
        {
            TextIter begin_line;
            doc.get_iter_at_line (out begin_line, iter.get_line ());
            string text_before = doc.get_text (begin_line, iter, false);

            if (Utils.char_is_escaped (text_before, text_before.length - 1))
                continue;

            TextIter end_line = iter;
            end_line.forward_to_line_end ();
            string text_after = doc.get_text (iter, end_line, false);
            text_after = text_after.strip ();

            MatchInfo match_info;
            if (! regex.match (text_after, 0, out match_info))
                continue;

            string type_str = match_info.fetch_named ("type");
            StructType type;
            if (type_str == "TODO")
                type = StructType.TODO;
            else
                type = StructType.FIXME;

            string text = match_info.fetch_named ("text");

            TextIter mark_iter = iter;
            mark_iter.backward_char ();
            add_item (type, text, mark_iter);
        }

        populate_tree_store (_tree);
    }

    private bool search_simple_command (TextIter begin_name_iter)
    {
        TextBuffer doc = begin_name_iter.get_buffer ();

        // set the limit to the end of the line
        TextIter limit = begin_name_iter;
        limit.forward_to_line_end ();

        /* try to get the command name (between '\' and '{') */

        TextIter end_name_iter;
        TextIter begin_contents_iter;

        if (! begin_name_iter.forward_search ("{",
            TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY,
            out end_name_iter, out begin_contents_iter, limit))
        {
            // not a command
            return false;
        }

        string name = doc.get_text (begin_name_iter, end_name_iter, false);
        StructType? type = get_type_from_simple_command_name (name);

        // not a good command
        if (type == null)
            return false;

        /* try to get the command contents (between '{' and '}') */

        // find the matching '}'
        string end_line = doc.get_text (begin_contents_iter, limit, false);
        int brace_level = 0;
        for (long i = 0 ; i < end_line.length ; i++)
        {
            if (end_line[i] == '{' && ! Utils.char_is_escaped (end_line, i))
            {
                brace_level++;
                continue;
            }

            if (end_line[i] == '}' && ! Utils.char_is_escaped (end_line, i))
            {
                if (brace_level > 0)
                {
                    brace_level--;
                    continue;
                }

                // found!
                string contents = end_line[0:i];

                // empty
                if (contents.length == 0)
                    return false;

                TextIter mark_iter = begin_name_iter;
                mark_iter.backward_char ();
                add_item (type, contents, mark_iter);
                return true;
            }
        }

        return false;
    }
}
