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
 *
 * Authors: Sébastien Wilmet
 *          Pieter Pareit
 */

using Gtk;

public class CompletionProvider : GLib.Object, SourceCompletionProvider
{
    struct CompletionCommand
    {
        string name;
        string? package;
        CompletionArgument[] args;
    }

    struct CompletionArgument
    {
        string label;
        bool optional;
        CompletionChoice[] choices;
    }

    struct CompletionChoice
    {
        string name;
        string? package;
        string? insert;
        string? insert_after;
    }

    private static CompletionProvider _instance = null;

    private GLib.Settings _settings;

    private List<SourceCompletionItem> _proposals;
    private Gee.HashMap<string, CompletionCommand?> _commands;
    // contains only environments that have extra info
    private Gee.HashMap<string, CompletionChoice?> _environments;

    // while parsing, keep track of current command/argument/choice
    private CompletionCommand _current_command;
    private CompletionArgument _current_arg;
    private CompletionChoice _current_choice;

    private Gdk.Pixbuf _icon_cmd;
    private Gdk.Pixbuf _icon_choice;
    private Gdk.Pixbuf _icon_package_required;

    private SourceCompletionInfo _calltip_window = null;
    private Label _calltip_window_label = null;

    /* CompletionProvider is a singleton */
    private CompletionProvider ()
    {
        _settings = new GLib.Settings ("org.gnome.latexila.preferences.latex");

        // icons
        _icon_cmd = Utils.get_pixbuf_from_stock ("completion_cmd", IconSize.MENU);
        _icon_choice = Utils.get_pixbuf_from_stock ("completion_choice", IconSize.MENU);
        _icon_package_required = Utils.get_pixbuf_from_stock (Stock.DIALOG_WARNING,
            IconSize.MENU);

        load_data ();
    }

    public static CompletionProvider get_default ()
    {
        if (_instance == null)
            _instance = new CompletionProvider ();

        return _instance;
    }

    public string get_name ()
    {
        return "LaTeX";
    }

    public SourceCompletionActivation get_activation ()
    {
        // This function is called only once, so if we disable interactive
        // completion here, there would be a problem because in this case,
        // if the user enables the option, it will take effect only on restart.
        return SourceCompletionActivation.USER_REQUESTED
            | SourceCompletionActivation.INTERACTIVE;
    }

    public bool match (SourceCompletionContext context)
    {
        TextIter iter = context.get_iter ();

        // if text selected, NO completion
        TextBuffer buf = iter.get_buffer ();
        if (buf.has_selection)
            return false;

        if (is_user_request (context))
            return true;

        // Since get_activation() is not dynamic, we do that here.
        return _settings.get_boolean ("interactive-completion");
    }

    public void populate (SourceCompletionContext context)
    {
        TextIter iter = context.get_iter ();

        /* The cursor is in a command name */
        string? cmd = get_latex_command_at_iter (iter);
        if (cmd != null)
        {
            populate_command (context, cmd);
            return;
        }

        /* The cursor is probably in a command's argument */

        string arg_cmd = null;
        Gee.ArrayList<bool> arguments = new Gee.ArrayList<bool> ();
        string arg_contents = null;
        bool valid_arg_contents = false;

        bool in_arg = in_latex_command_argument (iter, out arg_cmd, out arguments,
            out arg_contents, out valid_arg_contents);

        bool user_request = is_user_request (context);
        if (! in_arg)
        {
            if (user_request)
                show_all_proposals (context);
            else
                show_no_proposals (context);
            return;
        }

        /* OK, we are in an argument */

        // invalid argument's command
        if (! _commands.has_key (arg_cmd))
        {
            show_no_proposals (context);
            return;
        }

        unowned List<SourceCompletionItem> proposals_to_filter = null;

        if (valid_arg_contents)
            proposals_to_filter = get_argument_proposals (_commands[arg_cmd], arguments);

        if (proposals_to_filter == null)
        {
            if (user_request)
                show_calltip (arg_cmd, arguments);
            else
                show_no_proposals (context);
            return;
        }

        show_filtered_proposals (context, proposals_to_filter, arg_contents);
    }

    private void populate_command (SourceCompletionContext context, string cmd)
    {
        if (! is_user_request (context))
        {
            uint min_nb_chars;
            _settings.get ("interactive-completion-num", "u", out min_nb_chars);

            if (cmd.length <= min_nb_chars)
            {
                show_no_proposals (context);
                return;
            }
        }

        if (cmd == "\\")
        {
            show_all_proposals (context);
            return;
        }

        show_filtered_proposals (context, _proposals, cmd);
    }

    private bool is_user_request (SourceCompletionContext context)
    {
        return context.activation == SourceCompletionActivation.USER_REQUESTED;
    }

    // It has the same effect as returning false in match().
    private void show_no_proposals (SourceCompletionContext context)
    {
        // FIXME: maybe this method is not sure, because sometimes segfault occur,
        // but it's really difficult to diagnose...
        // see bug #618004

        // The second argument can not be null so we use a variable...
        // The vapi should be fixed.
        List<SourceCompletionItem> empty_proposals = null;
        context.add_proposals ((SourceCompletionProvider) this, empty_proposals, true);
    }

    private void show_all_proposals (SourceCompletionContext context)
    {
        context.add_proposals ((SourceCompletionProvider) this, _proposals, true);
    }

    private void show_filtered_proposals (SourceCompletionContext context,
        List<SourceCompletionItem> proposals_to_filter, string? prefix)
    {
        // No filtering needed.
        if (prefix == null || prefix == "")
        {
            context.add_proposals ((SourceCompletionProvider) this,
                proposals_to_filter, true);
            return;
        }

        List<SourceCompletionItem> filtered_proposals = null;
        foreach (SourceCompletionItem item in proposals_to_filter)
        {
            if (item.text.has_prefix (prefix))
                filtered_proposals.prepend (item);
        }

        // Since we have prepend items we must reverse the list to keep the proposals
        // in ascending order.
        if (filtered_proposals != null)
            filtered_proposals.reverse ();

        // No match, show a message so the completion widget doesn't disappear.
        else
        {
            var dummy_proposal = new SourceCompletionItem (_("No matching proposal"),
                "", null, null);
            filtered_proposals.prepend (dummy_proposal);
        }

        context.add_proposals ((SourceCompletionProvider) this, filtered_proposals, true);
    }

    private void show_calltip (string arg_cmd, Gee.ArrayList<bool> arguments)
    {
        return_if_fail (_commands.has_key (arg_cmd));

        CompletionCommand command = _commands[arg_cmd];
        int num = get_argument_num (command.args, arguments);
        if (num != -1)
        {
            string info = get_command_info (command, num);
            show_calltip_info (info);
        }
    }

    public bool activate_proposal (SourceCompletionProposal proposal, TextIter iter)
    {
        string text = proposal.get_text ();
        if (text == null || text == "")
            return true;

        string? cmd = get_latex_command_at_iter (iter);

        // if it's an argument choice
        if (cmd == null && text[0] != '\\')
        {
            string arg_cmd = null;
            string arg_contents = null;

            bool in_arg = in_latex_command_argument (iter, out arg_cmd, null,
                out arg_contents);

            if (in_arg)
            {
                activate_proposal_argument_choice (proposal, iter, arg_cmd,
                    arg_contents);
                return true;
            }
        }

        activate_proposal_command_name (proposal, iter, cmd);
        return true;
    }

    private void activate_proposal_command_name (SourceCompletionProposal proposal,
        TextIter iter, string? cmd)
    {
        string text = proposal.get_text ();

        long index_start = cmd != null ? cmd.length : 0;
        string text_to_insert = text[index_start : text.length];

        TextBuffer doc = iter.get_buffer ();
        doc.begin_user_action ();
        doc.insert (ref iter, text_to_insert, -1);
        doc.end_user_action ();

        // where to place the cursor?
        int i;
        for (i = 0 ; i < text_to_insert.length ; i++)
        {
            if (text_to_insert[i] == '{')
                break;
        }

        if (i < text_to_insert.length)
        {
            if (iter.backward_chars ((int) text_to_insert.length - i - 1))
                doc.place_cursor (iter);
        }
    }

    private void activate_proposal_argument_choice (SourceCompletionProposal proposal,
        TextIter iter, string arg_cmd, string? arg_contents)
    {
        string text = proposal.get_text ();

        long index_start = arg_contents != null ? arg_contents.length : 0;
        string text_to_insert = text[index_start : text.length];

        TextBuffer doc = iter.get_buffer ();
        doc.begin_user_action ();
        doc.insert (ref iter, text_to_insert, -1);

        // close environment: \begin{env} => \end{env}
        if (arg_cmd == "\\begin")
            close_environment (text, iter);

        // TODO place cursor, go to next argument, if any
        else
        {
        }

        doc.end_user_action ();
    }

    private void close_environment (string env_name, TextIter iter)
    {
        // two cases are supported here:
        // - \begin{env[iter]} : the iter is between the end of env_name and '}'
        //                       (spaces can be present between iter and '}')
        // - \begin{env[iter]  : the iter is at the end of env_name, but the '}' has not
        //                       been inserted (the user has written "\begin{" without
        //                       auto-completion)

        /* check if '}' is present */

        // get text between iter and end of line
        int line = iter.get_line ();
        Document doc = (Document) iter.get_buffer ();
        TextIter end_iter;
        doc.get_iter_at_line (out end_iter, line + 1);
        string text = doc.get_text (iter, end_iter, false);

        bool found = false;
        long i;
        for (i = 0 ; i < text.length ; i++)
        {
            if (text[i] == '}')
            {
                found = true;
                break;
            }
            if (text[i].isspace ())
                continue;
            break;
        }

        if (! found)
            doc.insert (ref iter, "}", -1);
        else
            iter.forward_chars ((int) i + 1);

        /* get current indentation */

        // for example ("X" are spaces to take into account):
        // some text
        // \begin{figure}
        // XX\begin{center[enter]

        string current_indent = doc.get_current_indentation (line);

        /* get current choice */
        CompletionChoice? environment = _environments[env_name];

        /* close environment */

        Document document = (Document) doc;
        string indent = document.tab.view.get_indentation_style ();

        doc.insert (ref iter, @"\n$current_indent$indent", -1);
        if (environment != null && environment.insert != null)
            doc.insert (ref iter, environment.insert, -1);
        TextMark cursor_pos = doc.create_mark (null, iter, true);
        if (environment != null && environment.insert_after != null)
            doc.insert (ref iter, environment.insert_after, -1);
        doc.insert (ref iter, @"\n$current_indent\\end{" + env_name + "}", -1);

        doc.get_iter_at_mark (out iter, cursor_pos);
        doc.place_cursor (iter);
    }

    private void init_calltip_window ()
    {
        Latexila app = Latexila.get_default ();
        _calltip_window = new SourceCompletionInfo ();
        _calltip_window.set_transient_for (app.active_window);
        _calltip_window.set_sizing (800, 200, true, true);
        _calltip_window_label = new Label (null);
        _calltip_window.set_widget (_calltip_window_label);
    }

    private void show_calltip_info (string markup)
    {
        if (_calltip_window == null)
            init_calltip_window ();

        MainWindow win = Latexila.get_default ().active_window;

        // calltip at a fixed place (after the '{' or '[' of the current arg)
        TextIter pos;
        TextBuffer buffer = win.active_view.buffer;
        buffer.get_iter_at_mark (out pos, buffer.get_insert ());
        string text = get_text_line_at_iter (pos);
        for (long i = text.length - 1 ; i >= 0 ; i--)
        {
            if (text[i] == '[' || text[i] == '{')
            {
                if (Utils.char_is_escaped (text, i))
                    continue;
                pos.backward_chars ((int) (text.length - 1 - i));
                break;
            }
        }

        _calltip_window_label.set_markup (markup);

        _calltip_window.set_transient_for (win);
        _calltip_window.move_to_iter (win.active_view, pos);
        _calltip_window.show_all ();
    }

    public void hide_calltip_window ()
    {
        if (_calltip_window == null)
            return;

        _calltip_window.hide ();
    }

    private unowned List<SourceCompletionItem>? get_argument_proposals (
        CompletionCommand cmd, Gee.ArrayList<bool> arguments)
    {
        if (cmd.args.length == 0)
            return null;

        string info = get_command_info (cmd);

        int num = get_argument_num (cmd.args, arguments);
        if (num == -1)
            return null;

        CompletionArgument arg = cmd.args[num - 1];
        unowned List<SourceCompletionItem> items = null;

        foreach (CompletionChoice choice in arg.choices)
        {
            string info2 = null;
            Gdk.Pixbuf pixbuf;
            if (choice.package != null)
            {
                info2 = info + "\nPackage: " + choice.package;
                pixbuf = _icon_package_required;
            }
            else
                pixbuf = _icon_choice;

            SourceCompletionItem item = new SourceCompletionItem (
                choice.name, choice.name, pixbuf, info2 ?? info);
            items.prepend (item);
        }

        if (items == null)
            return null;

        items.sort ((CompareFunc) compare_proposals);
        return items;
    }

    private int get_argument_num (CompletionArgument[] all_args,
        Gee.ArrayList<bool> args)
    {
        return_val_if_fail (args.size <= all_args.length, -1);

        int num = 0;
        foreach (bool arg in args)
        {
            while (true)
            {
                if (num >= all_args.length)
                    return -1;

                if (all_args[num].optional == arg)
                    break;

                // missing non-optional argument
                else if (! all_args[num].optional)
                    return -1;

                num++;
            }
            num++;
        }

        // first = 1
        return num;
    }

    private string get_command_text (CompletionCommand cmd)
    {
        string text_to_insert = cmd.name;
        foreach (CompletionArgument arg in cmd.args)
        {
            if (! arg.optional)
                text_to_insert += "{}";
        }
        return text_to_insert;
    }

    private string get_command_info (CompletionCommand cmd, int num = -1)
    {
        string info = cmd.name;
        int i = 1;
        foreach (CompletionArgument arg in cmd.args)
        {
            if (num == i)
                info += "<b>";

            if (arg.optional)
                info += "[" + arg.label + "]";
            else
                info += "{" + arg.label + "}";

            if (num == i)
                info += "</b>";
            i++;
        }

        if (cmd.package != null)
            info += "\nPackage: " + cmd.package;

        return info;
    }

    private string? get_latex_command_at_iter (TextIter iter)
    {
        string text = get_text_line_at_iter (iter);
        return get_latex_command_at_index (text, text.length - 1);
    }

    // get the text between the beginning of the iter line and the iter position
    private string get_text_line_at_iter (TextIter iter)
    {
        int line = iter.get_line ();
        TextBuffer doc = iter.get_buffer ();

        TextIter iter_start;
        doc.get_iter_at_line (out iter_start, line);

        return doc.get_text (iter_start, iter, false);
    }

    private string? get_latex_command_at_index (string text, long index)
    {
        return_val_if_fail (text.length > index, null);

        for (long i = index ; i >= 0 ; i--)
        {
            if (text[i] == '\\')
            {
                // if the backslash is escaped, it's not a latex command
                if (Utils.char_is_escaped (text, i))
                    break;

                return text[i : index + 1];
            }
            if (! text[i].isalpha () && text[i] != '*')
                break;
        }

        return null;
    }

    /* Are we in a latex command argument?
     * If yes, we also want to know:
     *     - the command name
     *     - the arguments: true if optional
     *       The last argument is the one where we are.
     *       We use an ArrayList because a dynamic array as an out param is not supported.
     *     - the current argument contents
     *     - if the argument contents is valid, i.e. if some choices could exist.
     *       Valid chars are letters and '*'. If the argument contents contains other char
     *       it is considered as not valid because no choice contain such chars.
     * Returns true if iter is in a latex command argument.
     */
    private bool in_latex_command_argument (TextIter iter,
                                            out string arg_cmd = null,
                                            out Gee.ArrayList<bool> arguments = null,
                                            out string arg_contents = null,
                                            out bool valid_arg_contents = null)
    {
        arg_cmd = null;
        arguments = new Gee.ArrayList<bool> ();
        arg_contents = null;
        valid_arg_contents = true;

        string text = get_text_line_at_iter (iter);
        long end_pos = text.length - 1;

        /* Fetch the argument contents */
        long opening_bracket_pos = -1;

        for (long cur_pos = end_pos ; 0 <= cur_pos ; cur_pos--)
        {
            bool opening_bracket = (text[cur_pos] == '{' || text[cur_pos] == '[')
                && ! Utils.char_is_escaped (text, cur_pos);

            // end of argument contents
            if (opening_bracket)
            {
                opening_bracket_pos = cur_pos;
                arguments.insert (0, text[cur_pos] == '[');

                if (cur_pos < end_pos)
                    arg_contents = text[cur_pos + 1 : end_pos + 1];

                break;
            }

            // invalid argument contents (no choice available)
            if (! text[cur_pos].isalpha () && text[cur_pos] != '*')
                valid_arg_contents = false;
        }

        // not in an argument
        if (opening_bracket_pos <= 0)
            return false;

        /* Traverse the previous arguments, and find the command name */
        bool in_prev_arg = false;
        char prev_arg_opening_bracket = '{';

        for (long cur_pos = opening_bracket_pos - 1 ; 0 <= cur_pos ; cur_pos--)
        {
            if (in_prev_arg)
            {
                if (text[cur_pos] == prev_arg_opening_bracket)
                    in_prev_arg = Utils.char_is_escaped (text, cur_pos);
                continue;
            }

            // We are maybe between two arguments,
            // or between the first argument and the command name,
            // or we were not in a latex command argument.

            if (text[cur_pos].isspace ())
                continue;

            // last character of the command name
            if (text[cur_pos].isalpha () || text[cur_pos] == '*')
            {
                arg_cmd = get_latex_command_at_index (text, cur_pos);
                return arg_cmd != null;
            }

            // maybe the end of a previous argument
            if (text[cur_pos] == '}' || text[cur_pos] == ']')
            {
                if (Utils.char_is_escaped (text, cur_pos))
                    return false;

                in_prev_arg = true;
                prev_arg_opening_bracket = text[cur_pos] == '}' ? '{' : '[';

                arguments.insert (0, text[cur_pos] == ']');
                continue;
            }

            return false;
        }

        return false;
    }

    // static because of bug #627736
    // (and also because it's more efficient)
    private static int compare_proposals (SourceCompletionItem a, SourceCompletionItem b)
    {
        return a.text.collate (b.text);
    }

    /*************************************************************************/
    // Load the data contained in the XML file

    private void load_data ()
    {
        _commands = new Gee.HashMap<string, CompletionCommand?> ();
        _environments = new Gee.HashMap<string, CompletionChoice?> ();

        try
        {
            File file = File.new_for_path (Config.DATA_DIR + "/completion.xml");

            uint8[] chars;
            file.load_contents (null, out chars);
            string contents = (string) (owned) chars;

            MarkupParser parser = { parser_start, parser_end, parser_text, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);
            _proposals.sort ((CompareFunc) compare_proposals);
        }
        catch (GLib.Error e)
        {
            warning ("Impossible to load completion data: %s", e.message);
        }
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "commands":
                break;

            case "command":
                parser_add_command (attr_names, attr_values);
                break;

            case "argument":
                parser_add_argument (attr_names, attr_values);
                break;

            case "choice":
                parser_add_choice (attr_names, attr_values);
                break;

            // insert and insert_after don't contain any attributes, but
            // contain content, which is parsed in parser_text()
            case "insert":
            case "insert_after":
                break;

            // not yet supported
            case "placeholder":
            case "component":
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private void parser_add_command (string[] attr_names, string[] attr_values)
        throws MarkupError
    {
        _current_command = CompletionCommand ();
        for (int attr_num = 0 ; attr_num < attr_names.length ; attr_num++)
        {
            switch (attr_names[attr_num])
            {
                case "name":
                    _current_command.name = "\\" + attr_values[attr_num];
                    break;

                case "package":
                    _current_command.package = attr_values[attr_num];
                    break;

                // not yet supported
                case "environment":
                    break;

                default:
                    throw new MarkupError.UNKNOWN_ATTRIBUTE (
                        "unknown command attribute \"" + attr_names[attr_num] + "\"");
            }
        }
    }

    private void parser_add_argument (string[] attr_names, string[] attr_values)
        throws MarkupError
    {
        _current_arg = CompletionArgument ();
        _current_arg.optional = false;

        for (int attr_num = 0 ; attr_num < attr_names.length ; attr_num++)
        {
            switch (attr_names[attr_num])
            {
                case "label":
                    _current_arg.label = attr_values[attr_num];
                    break;

                case "type":
                    _current_arg.optional = attr_values[attr_num] == "optional";
                    break;

                default:
                    throw new MarkupError.UNKNOWN_ATTRIBUTE (
                        "unknown argument attribute \"" + attr_names[attr_num] + "\"");
            }
        }
    }

    private void parser_add_choice (string[] attr_names, string[] attr_values)
        throws MarkupError
    {
        _current_choice = CompletionChoice ();

        for (int attr_num = 0 ; attr_num < attr_names.length ; attr_num++)
        {
            switch (attr_names[attr_num])
            {
                case "name":
                    _current_choice.name = attr_values[attr_num];
                    break;

                case "package":
                    _current_choice.package = attr_values[attr_num];
                    break;

                default:
                    throw new MarkupError.UNKNOWN_ATTRIBUTE (
                        "unknown choice attribute \"" + attr_names[attr_num] + "\"");
            }
        }
    }

    private void parser_end (MarkupParseContext context, string name) throws MarkupError
    {
        switch (name)
        {
            case "command":
                Gdk.Pixbuf pixbuf = _current_command.package != null
                    ? _icon_package_required : _icon_cmd;

                var item = new SourceCompletionItem (_current_command.name,
                    get_command_text (_current_command),
                    pixbuf,
                    get_command_info (_current_command));

                _proposals.append (item);

                // We don't need to store commands that have no arguments,
                // they are only in _proposals, it's sufficient.
                if (0 < _current_command.args.length)
                    _commands[_current_command.name] = _current_command;
                break;

            case "argument":
                _current_command.args += _current_arg;
                break;

            case "choice":
                _current_arg.choices += _current_choice;
                if (_current_choice.insert != null
                    || _current_choice.insert_after != null)
                    _environments[_current_choice.name] = _current_choice;
                break;
        }
    }

    private void parser_text (MarkupParseContext context, string text, size_t text_len)
        throws MarkupError
    {
        switch (context.get_element ())
        {
            case "insert":
                _current_choice.insert = text;
                break;

            case "insert_after":
                _current_choice.insert_after = text;
                break;
        }
    }

    /*
    private void print_command_args (CompletionCommandArgs cmd_args)
    {
        stdout.printf ("\n=== COMMAND ARGS ===\n");
        foreach (unowned List<SourceCompletionItem> items in cmd_args.optional_args)
        {
            stdout.printf ("= optional arg =\n");
            foreach (SourceCompletionItem item in items)
                stdout.printf ("%s\n", item.label);
        }

        foreach (unowned List<SourceCompletionItem> items in cmd_args.args)
        {
            stdout.printf ("= normal arg =\n");
            foreach (SourceCompletionItem item in items)
                stdout.printf ("%s\n", item.label);
        }
    }
    */
}
