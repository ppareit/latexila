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
        END_DOCUMENT,
        CAPTION
    }

    private unowned Document _doc;
    private int _nb_marks = 0;
    private static const string MARK_NAME_PREFIX = "struct_item_";
    private TextMark? _end_document_mark = null;

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

    public DocumentStructure (Document doc)
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

        _end_document_mark = null;
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
            string line = get_document_line_contents (cur_line);

            // in one line there could be several items

            int start_index = 0;
            int line_length = line.length;
            while (start_index < line_length)
            {
                LowLevelType? type;
                string? contents;
                int? start_match_index;
                int? end_match_index;

                bool item_found = search_low_level_item (line, start_index, out type,
                    out contents, out start_match_index, out end_match_index);

                if (! item_found)
                    break;

                TextIter iter;
                _doc.get_iter_at_line_index (out iter, cur_line, start_match_index);
                handle_item (type, contents, iter);

                start_index = end_match_index;
            }

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

        if (contents == "document" && ! is_begin_env)
        {
            type = LowLevelType.END_DOCUMENT;
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

    private void handle_item (LowLevelType type, string? contents, TextIter iter)
    {
        // we are currently in a verbatim env
        if (_in_verbatim_env)
        {
            if (type == LowLevelType.END_VERBATIM)
                _in_verbatim_env = false;

            return;
        }

        // the low-level type is common with the high-level type
        if (type < LowLevelType.NB_COMMON_TYPES)
            add_item ((StructType) type, contents, iter);

        // begin of a verbatim env
        else if (type == LowLevelType.BEGIN_VERBATIM)
            _in_verbatim_env = true;

        // begin of a figure or table env
        else if (type == LowLevelType.BEGIN_FIGURE || type == LowLevelType.BEGIN_TABLE)
            create_new_environment (type, iter);

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
            _env_data.end_mark = create_text_mark_from_iter (iter);
            add_item_data (_env_data, true);
        }

        // end of the document
        else if (type == LowLevelType.END_DOCUMENT)
            _end_document_mark = create_text_mark_from_iter (iter);
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
            comment_item (tree_iter);
            return;
        }

        if (action_type != StructAction.SELECT)
            return;

        TextIter? start_iter;
        TextIter? end_iter;
        if (get_exact_item_bounds (tree_iter, out start_iter, out end_iter))
            _doc.select_range (start_iter, end_iter);
    }

    private void comment_item (TreeIter tree_iter)
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
            comment_between (start_iter, end_iter);
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

        bool go_one_line_backward = true;

        // the end of the section is the end of the document
        if (next_section_iter == null)
        {
            bool end_of_file;
            end_iter = get_end_document_iter (out end_of_file);
            go_one_line_backward = ! end_of_file;
        }

        else
        {
            _model.get (next_section_iter,
                StructColumn.START_MARK, out end_mark,
                -1);

            _doc.get_iter_at_mark (out end_iter, end_mark);
        }

        if (go_one_line_backward)
        {
            if (! end_iter.backward_line ())
                end_iter = null;
        }

        comment_between (start_iter, end_iter);
    }

    // comment the lines between start_iter and end_iter included
    private void comment_between (TextIter start_iter, TextIter? end_iter)
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

    // Returns true only if the bounds are correctly set.
    private bool get_exact_item_bounds (TreeIter tree_iter, out TextIter? start_iter,
        out TextIter? end_iter)
    {
        /* get item data */
        StructType item_type;
        TextMark start_mark = null;
        TextMark end_mark = null;
        string item_contents = null;

        _model.get (tree_iter,
            StructColumn.TYPE, out item_type,
            StructColumn.START_MARK, out start_mark,
            StructColumn.END_MARK, out end_mark,
            StructColumn.TEXT, out item_contents,
            -1);

        /* search 'start_iter' */
        _doc.get_iter_at_mark (out start_iter, start_mark);

        // Place 'end_iter' to the end of the low level type. If it's not the good place,
        // it will be changed below.
        bool found = get_low_level_item_bounds (item_type, item_contents, start_iter,
            true, out end_iter);

        if (! found)
            return false;

        /* search 'end_iter' */

        // a section
        if (Structure.is_section (item_type))
        {
            TreeIter? next_section_iter = null;
            try
            {
                next_section_iter = _model.get_next_sibling_or_parent (tree_iter);
            }
            catch (StructError e)
            {
                stderr.printf ("Structure: get next sibling or parent: %s\n", e.message);
                return false;
            }

            // the end of the section is the end of the document
            if (next_section_iter == null)
            {
                end_iter = get_end_document_iter ();
                return true;
            }

            _model.get (next_section_iter,
                StructColumn.TYPE, out item_type,
                StructColumn.START_MARK, out start_mark,
                StructColumn.TEXT, out item_contents,
                -1);

            _doc.get_iter_at_mark (out end_iter, start_mark);

            return get_low_level_item_bounds (item_type, item_contents, end_iter, true,
                null);
        }

        // an other common type: the end iter is already at the good place
        else if (item_type < StructType.NB_COMMON_TYPES)
            return true;

        // an environment
        if (end_mark == null)
            return false;

        TextIter end_env_iter;
        _doc.get_iter_at_mark (out end_env_iter, end_mark);

        return get_low_level_item_bounds (item_type, item_contents, end_env_iter, false,
            out end_iter);
    }

    private bool get_low_level_item_bounds (StructType item_type, string item_contents,
        TextIter start_match_iter, bool is_start, out TextIter? end_match_iter)
    {
        int line_num = start_match_iter.get_line ();
        string line = get_document_line_contents (line_num);

        /* parse the line */
        int start_index = start_match_iter.get_line_index ();
        LowLevelType? low_level_type;
        string? contents;
        int? start_match_index;
        int? end_match_index;

        bool found = search_low_level_item (line, start_index, out low_level_type,
            out contents, out start_match_index, out end_match_index);

        // If an item is found, it should be located at exactly the same place.
        if (! found || start_index != start_match_index)
            return false;

        if (contents == null)
            contents = "";

        // compare the item found with the structure item
        if (same_items (item_type, item_contents, low_level_type, contents, is_start))
        {
            _doc.get_iter_at_line_index (out end_match_iter, line_num, end_match_index);
            return true;
        }

        return false;
    }

    // Compare a structure item with another low-level item
    // If 'start' is true, and if the structure item is an environment, a \begin{} is
    // expected. Otherwise, a \end{} is expected.
    private bool same_items (StructType item_type, string item_contents,
        LowLevelType item_found_type, string item_found_contents, bool start)
    {
        if (item_found_type < LowLevelType.NB_COMMON_TYPES)
        {
            bool same_type = item_type == (StructType) item_found_type;
            bool same_contents = item_contents == item_found_contents;
            return same_type && same_contents;
        }

        if (item_type == StructType.FIGURE)
        {
            if (start)
                return item_found_type == LowLevelType.BEGIN_FIGURE;
            else
                return item_found_type == LowLevelType.END_FIGURE;
        }

        if (item_type == StructType.TABLE)
        {
            if (start)
                return item_found_type == LowLevelType.BEGIN_TABLE;
            else
                return item_found_type == LowLevelType.END_TABLE;
        }

        return false;
    }

    private string? get_document_line_contents (int line_num)
    {
        int nb_lines = _doc.get_line_count ();
        return_val_if_fail (0 <= line_num && line_num < nb_lines, null);

        TextIter begin;
        _doc.get_iter_at_line (out begin, line_num);

        // If the line is empty, and if we do a forward_to_line_end(), we go to the end of
        // the _next_ line, so we must handle this special case.
        if (begin.ends_line ())
            return "";

        TextIter end = begin;
        end.forward_to_line_end ();

        return _doc.get_text (begin, end, false);
    }

    // Take into account \end{document}
    private TextIter get_end_document_iter (out bool end_of_file = null)
    {
        if (_end_document_mark != null)
        {
            end_of_file = false;
            TextIter end_document_iter;
            _doc.get_iter_at_mark (out end_document_iter, _end_document_mark);
            return end_document_iter;
        }

        end_of_file = true;
        TextIter eof_iter;
        _doc.get_end_iter (out eof_iter);
        return eof_iter;
    }
}
