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

    private static CompletionProvider instance = null;
    private List<SourceCompletionItem> proposals;
    private Gee.HashMap<string, CompletionCommand?> commands;

    private GLib.Settings settings;

    private CompletionCommand current_command;
    private CompletionArgument current_arg;

    private bool show_all_proposals = false;

    private Gdk.Pixbuf icon_normal_cmd;
    private Gdk.Pixbuf icon_normal_choice;
    private Gdk.Pixbuf icon_package_required;

    private SourceCompletionInfo calltip_window = null;
    private Label calltip_window_label = null;

    /* CompletionProvider is a singleton */
    private CompletionProvider ()
    {
        settings = new GLib.Settings ("org.gnome.latexila.preferences.latex");
        commands = new Gee.HashMap<string, CompletionCommand?> ();

        // icons
        icon_normal_cmd = Utils.get_pixbuf_from_stock ("completion_cmd", IconSize.MENU);
        icon_normal_choice = Utils.get_pixbuf_from_stock ("completion_choice",
            IconSize.MENU);
        icon_package_required = Utils.get_pixbuf_from_stock (STOCK_DIALOG_WARNING,
            IconSize.MENU);

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

    public unowned Gdk.Pixbuf? get_icon ()
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
        bool in_argument = false;
        bool valid_arg_contents = false;
        show_all_proposals = false;

        TextIter iter = {};
        context.get_iter (iter);
        string? cmd = get_latex_command_at_iter (iter);

        if (cmd == null)
            in_argument = in_latex_command_argument (iter, null, null, null,
                out valid_arg_contents);

        if (context.activation == SourceCompletionActivation.USER_REQUESTED)
        {
            show_all_proposals = cmd == null && ! in_argument;
            return true;
        }

        if (! settings.get_boolean ("interactive-completion")
            || (in_argument && ! valid_arg_contents))
            return false;

        if (in_argument && valid_arg_contents)
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

        bool in_argument = false;
        string cmd_name = null;
        Gee.ArrayList<bool> arguments = new Gee.ArrayList<bool> ();
        string argument_contents = null;
        bool valid_arg_contents = false;

        if (cmd == null)
            in_argument = in_latex_command_argument (iter, out cmd_name, out arguments,
                out argument_contents, out valid_arg_contents);

        // clear
        if ((! show_all_proposals && cmd == null && ! in_argument)
            || (context.activation == SourceCompletionActivation.INTERACTIVE
                && ! settings.get_boolean ("interactive-completion"))
            || (in_argument && ! commands.has_key (cmd_name)))
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
        string prefix = null;
        // try to complete a command
        if (! in_argument)
        {
            proposals_to_filter = proposals;
            prefix = cmd;
        }
        // try to complete a command argument choice
        else if (valid_arg_contents && commands.has_key (cmd_name))
        {
            proposals_to_filter = get_argument_proposals (commands[cmd_name], arguments);
            prefix = argument_contents ?? "";
        }

        // show calltip?
        if (in_argument && proposals_to_filter == null)
        {
            clear_context (context);

            // show calltip only on user request
            if (context.activation == SourceCompletionActivation.INTERACTIVE)
            {
                hide_calltip_window ();
                return;
            }

            CompletionCommand command = commands[cmd_name];
            int num = get_argument_num (command.args, arguments);
            if (num != -1)
            {
                string info = get_command_info (command, num);
                show_calltip_info (info);
            }
            return;
        }

        hide_calltip_window ();

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
        string text = proposal.get_text ();
        if (text == null || text == "")
            return true;

        string? cmd = get_latex_command_at_iter (iter);

        // if it's an argument choice
        if (cmd == null && text[0] != '\\')
        {
            string cmd_name = null;
            string argument_contents = null;

            bool in_argument = in_latex_command_argument (iter, out cmd_name, null,
                out argument_contents);

            if (in_argument)
            {
                activate_proposal_argument_choice (proposal, iter, cmd_name,
                    argument_contents);
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
        doc.insert (iter, text_to_insert, -1);
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
        TextIter iter, string cmd_name, string? argument_contents)
    {
        string text = proposal.get_text ();

        long index_start = argument_contents != null ? argument_contents.length : 0;
        string text_to_insert = text[index_start : text.length];

        TextBuffer doc = iter.get_buffer ();
        doc.begin_user_action ();
        doc.insert (iter, text_to_insert, -1);

        // close environment: \begin{env} => \end{env}
        if (cmd_name == "\\begin")
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
        TextBuffer doc = iter.get_buffer ();
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
            doc.insert (iter, "}", -1);
        else
            iter.forward_chars ((int) i + 1);

        /* get current indentation */

        // for example ("X" are spaces to take into account):
        // some text
        // \begin{figure}
        // XX\begin{center[enter]

        TextIter start_iter;
        doc.get_iter_at_line (out start_iter, line);
        text = doc.get_text (start_iter, iter, false);
        string current_indent = "";
        for (i = 0 ; i < text.length ; i++)
        {
            if (text[i].isspace ())
                current_indent += text[i].to_string ();
            else
                break;
        }

        /* close environment */

        Document document = (Document) doc;
        var view = document.tab.view;
        string indent = Utils.get_indentation_style (view);

        doc.insert (iter, @"\n$current_indent$indent", -1);
        TextMark cursor_pos = doc.create_mark (null, iter, true);
        doc.insert (iter, @"\n$current_indent\\end{" + env_name + "}", -1);

        doc.get_iter_at_mark (out iter, cursor_pos);
        doc.place_cursor (iter);
    }

    private void init_calltip_window ()
    {
        Application app = Application.get_default ();
        calltip_window = new SourceCompletionInfo ();
        calltip_window.set_transient_for (app.active_window);
        calltip_window.set_sizing (800, 200, true, true);
        calltip_window_label = new Label (null);
        calltip_window.set_widget (calltip_window_label);
    }

    private void show_calltip_info (string markup)
    {
        if (calltip_window == null)
            init_calltip_window ();

        MainWindow win = Application.get_default ().active_window;

        // calltip at a fixed place (after the '{' or '[' of the current arg)
        TextIter pos;
        TextBuffer buffer = win.active_view.buffer;
        buffer.get_iter_at_mark (out pos, buffer.get_insert ());
        string text = get_text_line_at_iter (pos);
        for (long i = text.length - 1 ; i >= 0 ; i--)
        {
            if (text[i] == '[' || text[i] == '{')
            {
                if (char_is_escaped (text, i))
                    continue;
                pos.backward_chars ((int) (text.length - 1 - i));
                break;
            }
        }

        calltip_window_label.set_markup (markup);

        calltip_window.set_transient_for (win);
        calltip_window.move_to_iter (win.active_view, pos);
        calltip_window.show_all ();
    }

    public void hide_calltip_window ()
    {
        if (calltip_window == null)
            return;

        calltip_window.hide ();
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
                Gdk.Pixbuf pixbuf = current_command.package != null
                    ? icon_package_required : icon_normal_cmd;
                var item = new SourceCompletionItem (current_command.name,
                    get_command_text (current_command),
                    pixbuf,
                    get_command_info (current_command));

                proposals.append (item);

                // we don't need to store commands that have no argument
                if (current_command.args.length > 0)
                    commands[current_command.name] = current_command;
                break;

            case "argument":
                current_command.args += current_arg;
                break;
        }
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
                pixbuf = icon_package_required;
            }
            else
                pixbuf = icon_normal_choice;

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
                if (char_is_escaped (text, i))
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
                                            out string cmd_name = null,
                                            out Gee.ArrayList<bool> arguments = null,
                                            out string argument_contents = null,
                                            out bool valid_arg_contents = null)
    {
        string text = get_text_line_at_iter (iter);

        bool fetch_argument_contents = true;
        long index_start_argument_contents = -1;
        bool in_other_argument = false;
        char other_argument_opening_bracket = '{';

        if (&arguments != null)
            arguments = new Gee.ArrayList<bool> ();

        if (&valid_arg_contents != null)
            valid_arg_contents = true;

        for (long i = text.length - 1 ; i >= 0 ; i--)
        {
            if (fetch_argument_contents)
            {
                // end of argument content
                if ((text[i] == '{' || text[i] == '[') && ! char_is_escaped (text, i))
                {
                    if (&arguments != null)
                        arguments.insert (0, text[i] == '[');

                    if (&argument_contents != null && index_start_argument_contents != -1)
                        argument_contents =
                            text[index_start_argument_contents : text.length];

                    // argument contents fetched
                    fetch_argument_contents = false;
                    continue;
                }

                // invalid argument content (no choice available)
                if (&valid_arg_contents != null && ! text[i].isalpha () && text[i] != '*')
                    valid_arg_contents = false;

                index_start_argument_contents = i;
            }

            else if (in_other_argument)
            {
                if (text[i] == other_argument_opening_bracket)
                    in_other_argument = char_is_escaped (text, i);
                continue;
            }

            // Maybe between two arguments,
            // or between the first argument and the command name,
            // or we were not in a latex command argument.
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

                // maybe the end of another argument
                if (text[i] == '}' || text[i] == ']')
                {
                    if (char_is_escaped (text, i))
                        return false;

                    in_other_argument = true;
                    other_argument_opening_bracket = text[i] == '}' ? '{' : '[';

                    if (&arguments != null)
                        arguments.insert (0, text[i] == ']');
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
        // the second argument can not be null so we use a variable...
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
