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

public class DocumentStructure : GLib.Object
{
    private unowned TextBuffer _doc;
    private int _nb_marks = 0;
    private static const string MARK_NAME_PREFIX = "struct_item_";

    private bool _insert_at_end = true;
    private StructureModel _model = null;

    private static Regex? _comment_regex = null;

    private bool _in_figure_env = false;
    private bool _in_table_env = false;

    private static const int MAX_NB_LINES_TO_PARSE = 500;
    private int _start_parsing_line = 0;

    private bool _measure_parsing_time = true;

    public DocumentStructure (TextBuffer doc)
    {
        _doc = doc;

        if (_comment_regex == null)
        {
            try
            {
                _comment_regex =
                    new Regex ("^(?P<type>TODO|FIXME)[[:space:]:]*(?P<text>.*)$");
            }
            catch (RegexError e)
            {
                stderr.printf ("Structure: %s\n", e.message);
            }
        }
    }

    public void parse ()
    {
        // reset
        _model = new StructureModel ();
        _in_figure_env = false;
        _in_table_env = false;
        clear_all_structure_marks ();
        _start_parsing_line = 0;

        Idle.add (() =>
        {
            return parse_impl ();
        });
    }

    public StructureModel get_model ()
    {
        return _model;
    }

    // Parse the document. Returns false if finished, true otherwise.
    private bool parse_impl ()
    {
        Timer timer = null;
        if (_measure_parsing_time)
            timer = new Timer ();

        /* search commands (begin with a backslash) */

        // At the beginning of the search, the place where to insert new items is always
        // at the end.
        _insert_at_end = true;

        // The parsing is splitted into several chunks if it's a big document, so the UI
        // is not frozen.
        TextIter iter;
        _doc.get_iter_at_line (out iter, _start_parsing_line);

        TextIter? limit = null;
        int nb_lines = _doc.get_line_count ();
        int end_parsing_line = _start_parsing_line + MAX_NB_LINES_TO_PARSE;
        bool limit_parsing = nb_lines > end_parsing_line;

        if (_measure_parsing_time)
            limit_parsing = false;

        if (limit_parsing)
            _doc.get_iter_at_line (out limit, end_parsing_line);

        while (iter.forward_search ("\\",
            TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY,
            null, out iter, limit))
        {
            if (search_simple_command (iter))
                continue;
            search_figure_or_table (iter);
        }

        _insert_at_end = false;

        /* search comments (begin with '%') */

        _doc.get_iter_at_line (out iter, _start_parsing_line);

        while (iter.forward_search ("%",
            TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY,
            null, out iter, limit))
        {
            search_comment (iter);
            iter.forward_visible_line ();
        }

        if (limit_parsing)
        {
            _start_parsing_line = end_parsing_line;
            return true;
        }

        if (_measure_parsing_time)
        {
            timer.stop ();
            stdout.printf ("Structure parsing took %f seconds\n", timer.elapsed ());
        }

        return false;
    }

    private StructType? get_simple_command_type (TextIter after_backslash,
        out TextIter begin_contents_iter = null)
    {
        // set the limit to the end of the line
        TextIter limit = after_backslash;
        limit.forward_to_line_end ();

        // try to get the command name (between '\' and '{')

        TextIter end_name_iter;

        if (! after_backslash.forward_search ("{",
            TextSearchFlags.TEXT_ONLY | TextSearchFlags.VISIBLE_ONLY,
            out end_name_iter, out begin_contents_iter, limit))
        {
            // not a command
            return null;
        }

        string name = _doc.get_text (after_backslash, end_name_iter, false);
        return get_type_from_simple_command_name (name);
    }

    // Get the contents between '{' and the corresponding '}'.
    // The first char of 'text' is the char just after the '{'.
    private string? get_command_contents (string text)
    {
        int brace_level = 0;
        for (long i = 0 ; i < text.length ; i++)
        {
            if (text[i] == '{' && ! Utils.char_is_escaped (text, i))
            {
                brace_level++;
                continue;
            }

            if (text[i] == '}' && ! Utils.char_is_escaped (text, i))
            {
                if (brace_level > 0)
                {
                    brace_level--;
                    continue;
                }

                // found!
                string contents = text[0:i];

                // empty
                if (contents.length == 0)
                    return null;

                return contents;
            }
        }

        return null;
    }

    private bool search_simple_command (TextIter begin_name_iter)
    {
        // get command type
        TextIter begin_contents_iter;
        StructType? type = get_simple_command_type (begin_name_iter,
            out begin_contents_iter);

        if (type == null)
            return false;

        // get command contents

        TextIter limit = begin_contents_iter;
        limit.forward_to_line_end ();

        string end_line = _doc.get_text (begin_contents_iter, limit, false);
        string? contents = get_command_contents (end_line);
        if (contents == null)
            return false;

        TextIter mark_iter = begin_name_iter;
        mark_iter.backward_char ();
        add_item (type, contents, mark_iter);
        return true;
    }

    private void search_figure_or_table (TextIter after_backslash)
    {
        string text = get_text_to_line_end (after_backslash);

        if (text.has_prefix ("begin{figure}"))
            _in_figure_env = true;
        else if (text.has_prefix ("end{figure}"))
            _in_figure_env = false;
        else if (text.has_prefix ("begin{table}"))
            _in_table_env = true;
        else if (text.has_prefix ("end{table}"))
            _in_table_env = false;
    }

    private bool search_comment (TextIter after_percent)
    {
        TextIter begin_line;
        _doc.get_iter_at_line (out begin_line, after_percent.get_line ());
        string text_before = _doc.get_text (begin_line, after_percent, false);

        if (Utils.char_is_escaped (text_before, text_before.length - 1))
            return false;

        string text_after = get_text_to_line_end (after_percent).strip ();

        MatchInfo match_info;
        if (! _comment_regex.match (text_after, 0, out match_info))
            return false;

        string type_str = match_info.fetch_named ("type");
        StructType type;
        if (type_str == "TODO")
            type = StructType.TODO;
        else
            type = StructType.FIXME;

        string text = match_info.fetch_named ("text");

        TextIter mark_iter = after_percent;
        mark_iter.backward_char ();
        add_item (type, text, mark_iter);
        return true;
    }

    private string get_text_to_line_end (TextIter start)
    {
        TextBuffer doc = start.get_buffer ();
        TextIter line_end = start;
        line_end.forward_to_line_end ();
        return doc.get_text (start, line_end, false);
    }

    private void add_item (StructType type, string text, TextIter iter)
    {
        StructData data = {};
        data.type = type;
        data.text = text;
        data.mark = create_text_mark_from_iter (iter);

        if (_insert_at_end)
            _model.add_item_at_end (data);
        else
            _model.add_item_in_middle (data);
    }

    private TextMark create_text_mark_from_iter (TextIter iter)
    {
        TextBuffer doc = iter.get_buffer ();
        string name = MARK_NAME_PREFIX + _nb_marks.to_string ();
        TextMark mark = doc.create_mark (name, iter, false);
        _nb_marks++;

        return mark;
    }

    private void clear_all_structure_marks ()
    {
        for (int i = 0 ; i < _nb_marks ; i++)
        {
            string mark_name = MARK_NAME_PREFIX + i.to_string ();
            TextMark? mark = _doc.get_mark (mark_name);
            if (mark != null)
                _doc.delete_mark (mark);
        }

        _nb_marks = 0;
    }

    private StructType? get_type_from_simple_command_name (string name)
    {
        switch (name)
        {
            case "part":
            case "part*":
                return StructType.PART;

            case "chapter":
            case "chapter*":
                return StructType.CHAPTER;

            case "section":
            case "section*":
                return StructType.SECTION;

            case "subsection":
            case "subsection*":
                return StructType.SUBSECTION;

            case "subsubsection":
            case "subsubsection*":
                return StructType.SUBSUBSECTION;

            case "paragraph":
            case "paragraph*":
                return StructType.PARAGRAPH;

            case "subparagraph":
            case "subparagraph*":
                return StructType.SUBPARAGRAPH;

            case "label":
                return StructType.LABEL;

            case "input":
            case "include":
                return StructType.INCLUDE;

            case "caption":
                if (_in_figure_env)
                    return StructType.FIGURE;
                else if (_in_table_env)
                    return StructType.TABLE;
                return null;

            default:
                return null;
        }
    }
}
