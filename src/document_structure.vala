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

    private static Regex? _chars_regex = null;
    private static Regex? _comment_regex = null;
    private static Regex? _command_name_regex = null;

    private bool _in_figure_env = false;
    private bool _in_table_env = false;
    private bool _in_verbatim_env = false;

    private static const int MAX_NB_LINES_TO_PARSE = 2000;
    private int _start_parsing_line = 0;
    private TextIter _cur_line_iter;

    private static const bool _measure_parsing_time = false;
    private Timer _timer = null;

    public bool parsing_done { get; private set; default = false; }

    public DocumentStructure (TextBuffer doc)
    {
        _doc = doc;

        if (_comment_regex == null)
        {
            try
            {
                _chars_regex = new Regex ("\\\\|%");

                _comment_regex =
                    new Regex ("^(?P<type>TODO|FIXME)[[:space:]:]*(?P<text>.*)$");

                _command_name_regex = new Regex ("^(?P<name>[a-z]+\\*?)[[:space:]]*{");
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
        parsing_done = false;
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
        if (_measure_parsing_time)
        {
            if (_timer == null)
                _timer = new Timer ();
            else
                _timer.continue ();
        }

        // When parsing all the document at once, the items are always inserted at the end
        _insert_at_end = true;

        int cur_line = _start_parsing_line;
        int nb_lines = _doc.get_line_count ();

        _doc.get_iter_at_line (out _cur_line_iter, cur_line);

        while (cur_line < nb_lines)
        {
            // If it's a big document, the parsing is splitted into several chunks,
            // so the UI is not frozen.
            if (cur_line == _start_parsing_line + MAX_NB_LINES_TO_PARSE)
            {
                _start_parsing_line = cur_line;

                if (_measure_parsing_time)
                    _timer.stop ();

                return true;
            }

            // get the text of the current line
            TextIter next_line_iter;
            if (cur_line == nb_lines - 1)
                _doc.get_end_iter (out next_line_iter);
            else
                _doc.get_iter_at_line (out next_line_iter, cur_line + 1);

            string line = _doc.get_text (_cur_line_iter, next_line_iter, false);

            // search the character '\' or '%'
            MatchInfo match_info;
            _chars_regex.match (line, 0, out match_info);

            while (match_info.matches ())
            {
                int index;
                if (! match_info.fetch_pos (0, null, out index))
                {
                    stderr.printf ("Structure parsing: position can not be fetched\n");
                    break;
                }

                if (! Utils.char_is_escaped (line, index - 1))
                {
                    string char_matched = match_info.fetch (0);

                    // search markup (begin with a backslash)
                    if (char_matched == "\\")
                        search_markup (line, index);

                    // search comments (begin with '%')
                    else if (! _in_verbatim_env)
                    {
                        search_comment (line, index);

                        // commented items are not displayed in the structure
                        break;
                    }
                }

                try
                {
                    match_info.next ();
                }
                catch (RegexError e)
                {
                    stderr.printf ("Warning: structure parsing: %s\n", e.message);
                    break;
                }
            }

            _cur_line_iter = next_line_iter;
            cur_line++;
        }

        if (_measure_parsing_time)
        {
            _timer.stop ();
            stdout.printf ("Structure parsing took %f seconds\n", _timer.elapsed ());
            _timer.reset ();
        }

        parsing_done = true;
        return false;
    }

    // Try to get the markup name (between '\' and '{').
    private string? get_markup_name (string line, int after_backslash_index,
        out int begin_contents_index = null)
    {
        string after_backslash_text = line.substring (after_backslash_index);

        MatchInfo match_info;
        if (! _command_name_regex.match (after_backslash_text, 0, out match_info))
            return null;

        if (&begin_contents_index != null)
        {
            int pos;
            match_info.fetch_pos (0, null, out pos);
            begin_contents_index = pos + after_backslash_index;
        }

        return match_info.fetch_named ("name");
    }

    // Get the contents between '{' and the corresponding '}'.
    private string? get_markup_contents (string line, int begin_contents_index)
    {
        int brace_level = 0;

        int line_length = line.length;
        for (long i = begin_contents_index ; i < line_length ; i++)
        {
            if (line[i] == '{' && ! Utils.char_is_escaped (line, i))
            {
                brace_level++;
                continue;
            }

            if (line[i] == '}' && ! Utils.char_is_escaped (line, i))
            {
                if (brace_level > 0)
                {
                    brace_level--;
                    continue;
                }

                // found!
                string contents = line[begin_contents_index : i];

                // empty
                if (contents == "")
                    return null;

                return contents;
            }
        }

        return null;
    }

    private void search_markup (string line, int after_backslash_index)
    {
        /* get markup name */
        int begin_contents_index;
        string? name = get_markup_name (line, after_backslash_index,
            out begin_contents_index);

        if (name == null)
            return;

        /* environment */
        bool is_begin_env = name == "begin";
        if (is_begin_env || name == "end")
        {
            search_env (line, begin_contents_index, is_begin_env);
            return;
        }

        /* simple markup */
        if (_in_verbatim_env)
            return;

        StructType? type = get_markup_type (name);
        if (type == null)
            return;

        string? contents = get_markup_contents (line, begin_contents_index);
        if (contents == null)
            return;

        add_item (type, contents);
    }

    private void search_env (string line, int begin_contents_index, bool is_begin_env)
    {
        string? contents = get_markup_contents (line, begin_contents_index);
        if (contents == null)
            return;

        if (contents == "verbatim" || contents == "verbatim*")
        {
            _in_verbatim_env = is_begin_env;
            return;
        }

        if (_in_verbatim_env)
            return;

        switch (contents)
        {
            case "figure":
                _in_figure_env = is_begin_env;
                break;

            case "table":
                _in_table_env = is_begin_env;
                break;
        }
    }

    private void search_comment (string line, int after_percent_index)
    {
        string text_after = line.substring (after_percent_index).strip ();

        MatchInfo match_info;
        if (! _comment_regex.match (text_after, 0, out match_info))
            return;

        string type_str = match_info.fetch_named ("type");
        StructType type;
        if (type_str == "TODO")
            type = StructType.TODO;
        else
            type = StructType.FIXME;

        string contents = match_info.fetch_named ("text");

        add_item (type, contents);
        return;
    }

    private void add_item (StructType type, string text)
    {
        StructData data = {};
        data.type = type;
        data.text = text;
        data.mark = create_text_mark_from_iter (_cur_line_iter);

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

    private StructType? get_markup_type (string markup_name)
    {
        switch (markup_name)
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
