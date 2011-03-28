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
        N_COLUMNS
    }

    // command like \name{text}
    private struct StructSimpleCommand
    {
        StructType type;
        string name;
    }

    private unowned MainWindow _main_window;
    private TreeStore _tree_store;
    private TreeView _tree_view;

    private const StructSimpleCommand[] _simple_commands =
    {
        { StructType.PART,          "part" },
        { StructType.CHAPTER,       "chapter" },
        { StructType.SECTION,       "section" },
        { StructType.SUBSECTION,    "subsection" },
        { StructType.SUBSUBSECTION, "subsubsection" },
        { StructType.PARAGRAPH,     "paragraph" },
        { StructType.SUBPARAGRAPH,  "subparagraph" },
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
            analyze_document (_main_window.active_document);
        });
    }

    private void init_tree_view ()
    {
        _tree_store = new TreeStore (StructItem.N_COLUMNS,
            typeof (string),     // pixbuf (stock-id)
            typeof (StructType), // item type
            typeof (string),     // text
            typeof (string)      // tooltip
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

    private TreeIter add_item (TreeIter? parent, StructType type, string text)
    {
        TreeIter iter;
        _tree_store.append (out iter, parent);
        _tree_store.set (iter,
            StructItem.PIXBUF, get_icon_from_type (type),
            StructItem.TYPE, type,
            StructItem.TEXT, text,
            StructItem.TOOLTIP, get_tooltip_from_type (type),
            -1);

        return iter;
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

    private void analyze_document (TextBuffer? doc)
    {
        _tree_store.clear ();
        _tree_view.columns_autosize ();

        if (doc == null)
            return;

        /* search commands (begin with a backslash) */

        TextIter iter;
        doc.get_start_iter (out iter);

        while (iter.forward_search ("\\",
            TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY,
            null, out iter, null))
        {
            search_simple_command (iter);
        }

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
            add_item (null, type, text);
        }
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
                if (contents.length == 0)
                    return false;
                add_item (null, type, contents);
                return true;
            }
        }

        return false;
    }
}
