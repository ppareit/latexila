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
    private enum LowLevelType
    {
        // First part: must be exactly the same as the first part of StructType
        // (in Structure).
        PART,
        CHAPTER,
        SECTION,
        SUBSECTION,
        SUBSUBSECTION,
        PARAGRAPH,
        SUBPARAGRAPH,
        LABEL,
        INCLUDE,
        IMAGE,
        TODO,
        FIXME,
        NB_COMMON_TYPES,

        // Second part: "low-level" only
        BEGIN_FIGURE,
        END_FIGURE,
        BEGIN_TABLE,
        END_TABLE,
        BEGIN_VERBATIM,
        END_VERBATIM,
        CAPTION
    }


    private unowned TextBuffer _doc;
    private int _nb_marks = 0;
    private static const string MARK_NAME_PREFIX = "struct_item_";

    private StructureModel _model = null;

    private static Regex? _chars_regex = null;
    private static Regex? _comment_regex = null;
    private static Regex? _command_name_regex = null;

    private bool _in_verbatim_env = false;

    // we can not take all data for figures and tables at once
    private StructData? _env_data = null;

    private static const int CAPTION_MAX_LENGTH = 60;

    private static const int MAX_NB_LINES_TO_PARSE = 2000;
    private int _start_parsing_line = 0;

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

                // the LaTeX command can contain some optional arguments
                // TODO a better implementation of this regex would be to parse the line
                // character by character, so we can verify if some chars are escaped.
                _command_name_regex =
                    new Regex ("^(?P<name>[a-z]+\\*?)[[:space:]]*(\\[[^\\]]*\\][[:space:]]*)*{");
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
        _env_data = null;
        _start_parsing_line = 0;

        clear_all_structure_marks ();

        Idle.add (() =>
        {
            return parse_impl ();
        });
    }

    public StructureModel get_model ()
    {
        return _model;
    }

    /*************************************************************************/
    // Parsing stuff

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

        int cur_line = _start_parsing_line;
        int nb_lines = _doc.get_line_count ();
        int stop_parsing_line = _start_parsing_line + MAX_NB_LINES_TO_PARSE;

        TextIter cur_line_iter;
        _doc.get_iter_at_line (out cur_line_iter, cur_line);

        // The parsing is done line-by-line.
        while (cur_line < nb_lines)
        {
            // If it's a big document, the parsing is splitted into several chunks,
            // so the UI is not frozen.
            if (cur_line == stop_parsing_line)
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

            string line = _doc.get_text (cur_line_iter, next_line_iter, false);

            // in one line there could be several items

            int start_index = 0;
            int line_length = line.length;
            while (start_index < line_length)
            {
                LowLevelType? type;
                string? contents;
                int? end_match_index;

                bool item_found = search_low_level_item (line, start_index, out type,
                    out contents, null, out end_match_index);

                if (! item_found)
                    break;

                handle_item (type, contents, cur_line_iter);

                start_index = end_match_index;
            }

            cur_line_iter = next_line_iter;
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

    // Search a "low-level" item in 'line'. The "high-level" items displayed in the
    // structure can be composed of several low-level items, for example a figure is
    // composed of \begin{figure}, the first \caption{} and \end{figure}.
    //
    // Begin the search at 'start_index'.
    // Returns true if an item has been found, false otherwise.
    // With the out arguments we can fetch the information we are intersted in.
    private bool search_low_level_item (string line, int start_index,
        out LowLevelType? type, out string? contents,
        out int? start_match_index, out int? end_match_index)
    {
        /* search the character '\' or '%' */
        MatchInfo match_info;
        try
        {
            _chars_regex.match_full (line, -1, start_index, 0, out match_info);
        }
        catch (Error e)
        {
            stderr.printf ("Structure parsing: chars regex: %s\n", e.message);
            return false;
        }

        if (! match_info.matches ())
            return false;

        int after_char_index;
        if (! match_info.fetch_pos (0, out start_match_index, out after_char_index))
        {
            stderr.printf ("Structure parsing: position can not be fetched\n");
            return false;
        }

        if (Utils.char_is_escaped (line, start_match_index))
            return false;

        string char_matched = match_info.fetch (0);

        // search markup (begin with a backslash)
        if (char_matched == "\\")
            return search_markup (line, after_char_index, out type, out contents,
                out end_match_index);

        // search comments (begin with '%')
        return search_comment (line, after_char_index, out type, out contents,
            out end_match_index);
    }

    private bool search_markup (string line, int after_backslash_index,
        out LowLevelType? type, out string? contents, out int? end_match_index)
    {
        /* get markup name */
        int? begin_contents_index;
        string? name = get_markup_name (line, after_backslash_index,
            out begin_contents_index);

        if (name == null)
            return false;

        /* environment */
        bool is_begin_env = name == "begin";
        if (is_begin_env || name == "end")
        {
            contents = null;
            return search_env (line, begin_contents_index, is_begin_env, out type,
                out end_match_index);
        }

        /* simple markup */
        type = get_markup_low_level_type (name);
        if (type == null)
            return false;

        contents = get_markup_contents (line, begin_contents_index, out end_match_index);
        return contents != null;
    }

    private bool search_env (string line, int begin_contents_index, bool is_begin_env,
        out LowLevelType? type, out int? end_match_index)
    {
        string? contents = get_markup_contents (line, begin_contents_index,
            out end_match_index);

        if (contents == null)
            return false;

        if (contents == "verbatim" || contents == "verbatim*")
        {
            type = is_begin_env ? LowLevelType.BEGIN_VERBATIM : LowLevelType.END_VERBATIM;
            return true;
        }

        if (contents == "figure")
        {
            type = is_begin_env ? LowLevelType.BEGIN_FIGURE : LowLevelType.END_FIGURE;
            return true;
        }

        if (contents == "table")
        {
            type = is_begin_env ? LowLevelType.BEGIN_TABLE : LowLevelType.END_TABLE;
            return true;
        }

        return false;
    }

    // Try to get the markup name (between '\' and '{').
    private string? get_markup_name (string line, int after_backslash_index,
        out int? begin_contents_index = null)
    {
        string after_backslash_text = line.substring (after_backslash_index);

        MatchInfo match_info;
        if (! _command_name_regex.match (after_backslash_text, 0, out match_info))
            return null;

        int pos;
        match_info.fetch_pos (0, null, out pos);
        begin_contents_index = pos + after_backslash_index;

        return match_info.fetch_named ("name");
    }

    // Get the contents between '{' and the corresponding '}'.
    private string? get_markup_contents (string line, int begin_contents_index,
        out int? end_match_index)
    {
        int brace_level = 0;

        int line_length = line.length;
        for (int i = begin_contents_index ; i < line_length ; i++)
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

                // but empty
                if (contents == "")
                    return null;

                end_match_index = i + 1;

                return contents;
            }
        }

        return null;
    }

    private bool search_comment (string line, int after_percent_index,
        out LowLevelType? type, out string? contents, out int? end_match_index)
    {
        string text_after = line.substring (after_percent_index).strip ();

        MatchInfo match_info;
        if (! _comment_regex.match (text_after, 0, out match_info))
            return false;

        string type_str = match_info.fetch_named ("type");
        type = type_str == "TODO" ? LowLevelType.TODO : LowLevelType.FIXME;

        contents = match_info.fetch_named ("text");
        end_match_index = line.length;

        return true;
    }

    private void handle_item (LowLevelType type, string? contents, TextIter cur_line_iter)
    {
        // we are currently in a verbatim env
        if (_in_verbatim_env)
        {
            if (type == LowLevelType.END_VERBATIM)
                _in_verbatim_env = false;

            return;
        }

        // the low-level type is common with the high-level type
        else if (type < LowLevelType.NB_COMMON_TYPES)
            add_item ((StructType) type, contents, cur_line_iter);

        // begin of a verbatim env
        else if (type == LowLevelType.BEGIN_VERBATIM)
            _in_verbatim_env = true;

        // begin of a figure or table env
        else if (type == LowLevelType.BEGIN_FIGURE || type == LowLevelType.BEGIN_TABLE)
            create_new_environment (type, cur_line_iter);

        // a caption (we take only the first)
        else if (type == LowLevelType.CAPTION && _env_data != null
            && _env_data.text == null)
        {
            string? short_caption = null;
            if (contents.length > CAPTION_MAX_LENGTH)
                short_caption = contents.substring (0, CAPTION_MAX_LENGTH);

            _env_data.text = short_caption ?? contents;
        }

        // end of a figure or table env
        else if (verify_end_environment_type (type))
        {
            _env_data.end_mark = create_text_mark_from_iter (cur_line_iter);
            add_item_data (_env_data, true);
        }
    }

    private void create_new_environment (LowLevelType type, TextIter start_iter)
    {
        return_if_fail (type == LowLevelType.BEGIN_FIGURE
            || type == LowLevelType.BEGIN_TABLE);

        _env_data = StructData ();
        _env_data.text = null;
        _env_data.start_mark = create_text_mark_from_iter (start_iter);
        _env_data.end_mark = null;

        if (type == LowLevelType.BEGIN_TABLE)
            _env_data.type = StructType.TABLE;
        else
            _env_data.type = StructType.FIGURE;
    }

    private bool verify_end_environment_type (LowLevelType type)
    {
        if (_env_data == null)
            return false;

        if (type == LowLevelType.END_TABLE)
            return _env_data.type == StructType.TABLE;

        if (type == LowLevelType.END_FIGURE)
            return _env_data.type == StructType.FIGURE;

        return false;
    }

    private void add_item (StructType type, string? text, TextIter start_iter)
    {
        StructData data = {};
        data.type = type;
        data.text = text;
        data.start_mark = create_text_mark_from_iter (start_iter);
        data.end_mark = null;

        add_item_data (data);
    }

    private void add_item_data (StructData data, bool insert_in_middle = false)
    {
        if (data.text == null)
            data.text = "";

        if (insert_in_middle)
            _model.add_item_in_middle (data);
        else
            _model.add_item_at_end (data);
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

    private LowLevelType? get_markup_low_level_type (string markup_name)
    {
        switch (markup_name)
        {
            case "part":
            case "part*":
                return LowLevelType.PART;

            case "chapter":
            case "chapter*":
                return LowLevelType.CHAPTER;

            case "section":
            case "section*":
                return LowLevelType.SECTION;

            case "subsection":
            case "subsection*":
                return LowLevelType.SUBSECTION;

            case "subsubsection":
            case "subsubsection*":
                return LowLevelType.SUBSUBSECTION;

            case "paragraph":
            case "paragraph*":
                return LowLevelType.PARAGRAPH;

            case "subparagraph":
            case "subparagraph*":
                return LowLevelType.SUBPARAGRAPH;

            case "label":
                return LowLevelType.LABEL;

            case "input":
            case "include":
                return LowLevelType.INCLUDE;

            case "includegraphics":
                return LowLevelType.IMAGE;

            case "caption":
                return LowLevelType.CAPTION;

            default:
                return null;
        }
    }

    /*************************************************************************/
    // Actions: cut, copy, delete, select, comment, shift left/right

    public void do_action (StructAction action_type, TreeIter tree_iter)
    {
        if (action_type == StructAction.COMMENT)
        {
            do_comment (tree_iter);
            return;
        }
    }

    private void do_comment (TreeIter tree_iter)
    {
        StructType type;
        TextMark start_mark = null;
        TextMark end_mark = null;

        _model.get (tree_iter,
            StructColumn.TYPE, out type,
            StructColumn.START_MARK, out start_mark,
            StructColumn.END_MARK, out end_mark,
            -1);

        TextIter start_iter;
        TextIter? end_iter = null;

        _doc.get_iter_at_mark (out start_iter, start_mark);

        if (end_mark != null)
            _doc.get_iter_at_mark (out end_iter, end_mark);

        /* comment a simple item */
        if (! Structure.is_section (type))
        {
            comment (start_iter, end_iter);
            return;
        }

        /* comment a section */

        // get next sibling or parent
        TreeIter? next_section_iter = null;
        try
        {
            next_section_iter = _model.get_next_sibling_or_parent (tree_iter);
        }
        catch (StructError e)
        {
            stderr.printf ("Structure: get next sibling or parent: %s\n", e.message);
            return;
        }

        // the end of the section is the end of the document
        if (next_section_iter == null)
            _doc.get_end_iter (out end_iter);

        // go one line backward
        else
        {
            _model.get (next_section_iter,
                StructColumn.START_MARK, out end_mark,
                -1);

            _doc.get_iter_at_mark (out end_iter, end_mark);
            if (! end_iter.backward_line ())
                end_iter = null;
        }

        comment (start_iter, end_iter);
    }

    // comment the lines between start_iter and end_iter included
    private void comment (TextIter start_iter, TextIter? end_iter)
    {
        int start_line = start_iter.get_line ();
        int end_line = start_line;

        if (end_iter != null)
            end_line = end_iter.get_line ();

        _doc.begin_user_action ();
        for (int line_index = start_line ; line_index <= end_line ; line_index++)
        {
            TextIter iter;
            _doc.get_iter_at_line (out iter, line_index);
            _doc.insert (iter, "% ", -1);
        }
        _doc.end_user_action ();
    }
}
