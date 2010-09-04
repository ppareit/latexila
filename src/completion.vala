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
    }

    private static CompletionProvider instance = null;
    private List<SourceCompletionItem> proposals;

    private CompletionCommand current_command;
    private CompletionArgument current_arg;

    private CompletionProvider ()
    {
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
                break;

            case "argument":
                current_command.args += current_arg;
                break;
        }
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

    private string get_match_text (TextIter iter)
    {
        int line = iter.get_line ();
        TextBuffer doc = iter.get_buffer ();

        TextIter iter_start;
        doc.get_iter_at_line (out iter_start, line);

        string text = doc.get_text (iter_start, iter, false);

        for (long i = text.length - 1 ; i >= 0 ; i--)
        {
            if (text[i] == '\\')
                return text[i:text.length];
            if (! text[i].isalpha ())
                break;
        }

        return "";
    }

    // static because of bug #627736
    private static int compare_proposals (SourceCompletionItem a, SourceCompletionItem b)
    {
        return a.text.collate (b.text);
    }

    public string get_name ()
    {
        return "LaTeX";
    }

    public unowned Gdk.Pixbuf get_icon ()
    {
        return null;
    }

    public void populate (SourceCompletionContext context)
    {
        TextIter iter = {};
        context.get_iter (iter);
        string text = get_match_text (iter);

        if (text == "")
            context.add_proposals (this, proposals, true);
        else
        {
            List<SourceCompletionItem> proposals_filtered = null;
            foreach (SourceCompletionItem item in proposals)
            {
                if (item.text.has_prefix (text))
                    proposals_filtered.prepend (item);
            }
            proposals_filtered.reverse ();
            context.add_proposals (this, proposals_filtered, true);
        }
    }

    public SourceCompletionActivation get_activation ()
    {
        return SourceCompletionActivation.USER_REQUESTED;
    }

    public bool match (SourceCompletionContext context)
    {
        return true;
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

    public bool activate_proposal (SourceCompletionProposal proposal, TextIter iter)
    {
        string match = get_match_text (iter);
        string text = proposal.get_text ();
        string text_to_insert = text[match.length:text.length];

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

    public int get_interactive_delay ()
    {
        return -1;
    }

    public int get_priority ()
    {
        return 0;
    }
}
