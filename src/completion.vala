/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010 Sébastien Wilmet
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
    }

    struct CompletionCommandArgs
    {
        List<SourceCompletionItem>*[] args;
        List<SourceCompletionItem>*[] optional_args;
    }

    private static CompletionProvider instance = null;
    private List<SourceCompletionItem> proposals;
    private Gee.HashMap<string, CompletionCommandArgs?> args_proposals;

    private GLib.Settings settings;

    private CompletionCommand current_command;
    private CompletionArgument current_arg;

    private bool show_all_proposals = false;

//    private bool    _in_param = false;
//    private string  _in_param_cmd_name;
//    private int     _param_num;
//    private bool    _param_is_optional;
//    private string  _param_contents;

    /* CompletionProvider is a singleton */
    private CompletionProvider ()
    {
        settings = new GLib.Settings ("org.gnome.latexila.preferences.latex");
        args_proposals = new Gee.HashMap<string, CompletionCommandArgs?> ();

        try
        {
            File file = File.new_for_path (Config.DATA_DIR + "/completion.xml");

            string contents;
            file.load_contents (null, out contents);

            MarkupParser parser = { parser_start, parser_end, null, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);
            proposals.sort ((CompareFunc) compare_proposals);
        }
        catch (GLib.Error e)
        {
            stderr.printf ("Warning: impossible to load completion data: %s\n",
                e.message);
        }
    }

    public static CompletionProvider get_default ()
    {
        if (instance == null)
            instance = new CompletionProvider ();
        return instance;
    }

    public string get_name ()
    {
        return "LaTeX";
    }

    public unowned Gdk.Pixbuf get_icon ()
    {
        return null;
    }

    public SourceCompletionActivation get_activation ()
    {
        SourceCompletionActivation ret = SourceCompletionActivation.USER_REQUESTED;

        if (settings.get_boolean ("interactive-completion"))
            ret |= SourceCompletionActivation.INTERACTIVE;

        return ret;
    }

    public unowned Gtk.Widget? get_info_widget (SourceCompletionProposal proposal)
    {
        return null;
    }

    public void update_info (SourceCompletionProposal proposal, SourceCompletionInfo info)
    {
    }

    public bool get_start_iter (SourceCompletionContext context,
        SourceCompletionProposal proposal, TextIter iter)
    {
        return false;
    }

    public int get_interactive_delay ()
    {
        return -1;
    }

    public int get_priority ()
    {
        return 0;
    }

    public bool match (SourceCompletionContext context)
    {
        bool in_param = false;
        show_all_proposals = false;

        TextIter iter = {};
        context.get_iter (iter);
        string? cmd = get_latex_command_at_iter (iter);

        if (cmd == null)
            in_param = in_latex_command_parameter (iter);

        if (context.activation == SourceCompletionActivation.USER_REQUESTED)
        {
            show_all_proposals = cmd == null && ! in_param;
            return true;
        }

        if (! settings.get_boolean ("interactive-completion"))
            return false;

        // The minimum number of characters for interactive completion is not taken into
        // account for parameters.
        if (in_param)
            return true;

        int min_nb_chars = settings.get_int ("interactive-completion-num");
        min_nb_chars = min_nb_chars.clamp (0, 8);

        return cmd != null && cmd.length > min_nb_chars;
    }

    public void populate (SourceCompletionContext context)
    {
        TextIter iter = {};
        context.get_iter (iter);
        string? cmd = get_latex_command_at_iter (iter);

        bool in_param = false;
        string cmd_name = null;
        int param_num = 0;
        bool param_is_optional = false;
        string param_contents = null;

        if (cmd == null)
            in_param = in_latex_command_parameter (iter, out cmd_name, out param_num,
                out param_is_optional, out param_contents);

        // clear
        if ((! show_all_proposals && cmd == null && ! in_param)
            || (context.activation == SourceCompletionActivation.INTERACTIVE
                && ! settings.get_boolean ("interactive-completion"))
            || (in_param && ! args_proposals.has_key (cmd_name)))
        {
            clear_context (context);
            return;
        }

        // show all proposals
        if (show_all_proposals || cmd == "\\")
        {
            show_all_proposals = false;
            context.add_proposals ((SourceCompletionProvider) this, proposals, true);
            return;
        }

        // filter proposals
        unowned List<SourceCompletionItem> proposals_to_filter = null;
        string prefix;
        if (in_param)
        {
            CompletionCommandArgs tmp = args_proposals[cmd_name];
            if (param_is_optional)
            {
                if (param_num > tmp.optional_args.length)
                {
                    clear_context (context);
                    return;
                }
                proposals_to_filter = tmp.optional_args[param_num - 1];
            }
            else
            {
                if (param_num > tmp.args.length)
                {
                    clear_context (context);
                    return;
                }
                proposals_to_filter = tmp.args[param_num - 1];
            }

            prefix = param_contents ?? "";
        }
        else
        {
            proposals_to_filter = proposals;
            prefix = cmd;
        }

        List<SourceCompletionItem> filtered_proposals = null;
        foreach (SourceCompletionItem item in proposals_to_filter)
        {
            if (item.text.has_prefix (prefix))
                filtered_proposals.prepend (item);
        }

        // no match, show a message so the completion widget doesn't disappear
        if (filtered_proposals == null)
        {
            var dummy_proposal = new SourceCompletionItem (_("No matching proposal"),
                "", null, null);
            filtered_proposals.prepend (dummy_proposal);
        }

        // Since we have prepend items we must reverse the list to keep the proposals
        // in ascending order.
        // FIXME maybe it's better to sort the proposals in descending order so when
        // we prepend items it's in ascending order and we avoid reversing the list each
        // time. But when we have to display all proposals (see above) it takes more time,
        // but generally that occurs less often unless the minimum number of chars for
        // interactive completion is 0.
        else
            filtered_proposals.reverse ();

        context.add_proposals ((SourceCompletionProvider) this, filtered_proposals,
            true);
    }

    public bool activate_proposal (SourceCompletionProposal proposal, TextIter iter)
    {
        string? cmd = get_latex_command_at_iter (iter);
        string text = proposal.get_text ();

        if (text == null || text == "")
            return true;

        long index_start = cmd != null ? cmd.length : 0;
        string text_to_insert = text[index_start : text.length];

        TextBuffer doc = iter.get_buffer ();
        doc.begin_user_action ();
        doc.insert (iter, text_to_insert, -1);
        doc.end_user_action ();

        // how to place the cursor?
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

        return true;
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "commands":
                break;

            case "command":
                current_command = CompletionCommand ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "name":
                            current_command.name = "\\" + attr_values[i];
                            break;
                        case "package":
                            current_command.package = attr_values[i];
                            break;
                        case "environment":
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown command attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "argument":
                current_arg = CompletionArgument ();
                current_arg.optional = false;
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "label":
                            current_arg.label = attr_values[i];
                            break;
                        case "type":
                            current_arg.optional = attr_values[i] == "optional";
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown argument attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "choice":
                CompletionChoice choice = CompletionChoice ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "name":
                            choice.name = attr_values[i];
                            break;
                        case "package":
                            choice.package = attr_values[i];
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown choice attribute \"" + attr_names[i] + "\"");
                    }
                }
                current_arg.choices += choice;
                break;

            case "placeholder":
            case "component":
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private void parser_end (MarkupParseContext context, string name) throws MarkupError
    {
        switch (name)
        {
            case "command":
                var item = new SourceCompletionItem (current_command.name,
                    get_command_text (current_command),
                    null,
                    get_command_info (current_command));
                proposals.append (item);
                fill_args_proposals (current_command);
                break;

            case "argument":
                current_command.args += current_arg;
                break;
        }
    }

    private void fill_args_proposals (CompletionCommand cmd)
    {
        if (cmd.args.length == 0)
            return;

        CompletionCommandArgs cmd_args = CompletionCommandArgs ();

        string info = get_command_info (cmd);

        foreach (CompletionArgument arg in cmd.args)
        {
            List<SourceCompletionItem> *items = null;

            foreach (CompletionChoice choice in arg.choices)
            {
                string info2 = null;
                if (choice.package != null)
                    info2 = info + "\nPackage: " + choice.package;

                SourceCompletionItem item = new SourceCompletionItem (choice.name,
                    choice.name, null, info2 ?? info);
                items->prepend (item);
            }

            if (items == null)
            {
                SourceCompletionItem item = new SourceCompletionItem (arg.label, "",
                    null, info);
                items->prepend (item);
            }
            else
                items->sort ((CompareFunc) compare_proposals);

            if (arg.optional)
                cmd_args.optional_args += items;
            else
                cmd_args.args += items;
        }

        args_proposals[cmd.name] = cmd_args;
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

    private string get_command_info (CompletionCommand cmd)
    {
        string info = cmd.name;
        foreach (CompletionArgument arg in cmd.args)
        {
            if (arg.optional)
                info += "[" + arg.label + "]";
            else
                info += "{" + arg.label + "}";
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
                if (char_is_escaped (text, i))
                    break;

                return text[i : index + 1];
            }
            if (! text[i].isalpha () && text[i] != '*')
                break;
        }

        return null;
    }

    private bool in_latex_command_parameter (TextIter iter,
                                             out string cmd_name = null,
                                             out int param_num = null,
                                             out bool param_is_optional = null,
                                             out string param_contents = null)
    {
        string text = get_text_line_at_iter (iter);

        bool fetch_param_contents = true;
        long index_start_param_contents = -1;
        bool in_other_param = false;
        char other_param_opening_bracket = '{';
        bool _param_is_optional = false;

        for (long i = text.length - 1 ; i >= 0 ; i--)
        {
            if (fetch_param_contents)
            {
                // valid param content
                if (text[i].isalpha () || text[i] == '*')
                {
                    index_start_param_contents = i;
                    continue;
                }

                // maybe the end of param content
                if (text[i] == '{' || text[i] == '[')
                {
                    // invalid param content
                    if (char_is_escaped (text, i))
                        return false;

                    // OK, param contents fetched
                    _param_is_optional = text[i] == '[';

                    if (&param_is_optional != null)
                        param_is_optional = _param_is_optional;
                    if (&param_num != null)
                        param_num = 1;
                    if (&param_contents != null && index_start_param_contents != -1)
                        param_contents = text[index_start_param_contents : text.length];
                    fetch_param_contents = false;
                    continue;
                }

                // We are not in a parameter,
                // or the parameter contents has no matching proposal
                return false;
            }

            else if (in_other_param)
            {
                if (text[i] == other_param_opening_bracket)
                    in_other_param = char_is_escaped (text, i);
                continue;
            }

            // Maybe between two parameters,
            // or between the first parameter and the command name,
            // or we were not in a latex command parameter.
            else
            {
                if (text[i].isspace ())
                    continue;

                // last character of the command name
                if (text[i].isalpha () || text[i] == '*')
                {
                    string tmp = get_latex_command_at_index (text, i);
                    if (&cmd_name != null)
                        cmd_name = tmp;
                    return tmp != null;
                }

                // maybe the end of another parameter
                if (text[i] == '}' || text[i] == ']')
                {
                    if (char_is_escaped (text, i))
                        return false;

                    in_other_param = true;
                    other_param_opening_bracket = text[i] == '}' ? '{' : '[';

                    if (_param_is_optional == (text[i] == ']') && &param_num != null)
                        param_num++;
                    continue;
                }

                return false;
            }
        }

        return false;
    }

    private bool char_is_escaped (string text, long index)
    {
        bool escaped = false;
        for (long i = index - 1 ; i >= 0 ; i--)
        {
            if (text[i] == '\\')
                escaped = ! escaped;
            else
                break;
        }
        return escaped;
    }

    // static because of bug #627736
    private static int compare_proposals (SourceCompletionItem a, SourceCompletionItem b)
    {
        return a.text.collate (b.text);
    }

    private void clear_context (SourceCompletionContext context)
    {
        // the second parameter can not be null so we use a variable...
        // the vapi should be fixed
        List<SourceCompletionItem> empty_proposals = null;
        context.add_proposals ((SourceCompletionProvider) this, empty_proposals, true);
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
