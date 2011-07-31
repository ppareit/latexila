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
 */

private abstract class PostProcessor : GLib.Object
{
    protected Node<BuildMsg?> _all_messages = new Node<BuildMsg?> (BuildMsg ());
    private unowned Node<BuildMsg?> _prev_message = null;

    public bool successful { get; protected set; }

    public Node<BuildMsg?> get_messages ()
    {
        return (owned) _all_messages;
    }

    protected unowned Node<BuildMsg?> append_message (BuildMsg message)
    {
        unowned Node<BuildMsg?> new_message;

        bool prev_msg_is_invalid = _prev_message != null && _prev_message.next != null;

        // If _prev_message is not the last node, do a normal 'append'.
        if (_prev_message == null || prev_msg_is_invalid)
            new_message = _all_messages.append_data (message);

        else
        {
            // 'insert_after' is O(1), whereas 'append' is O(N).
            // That's why we keep the previous node.
            new_message = _all_messages.insert_after (_prev_message,
                new Node<BuildMsg?> (message));
        }

        _prev_message = new_message;
        return new_message;
    }

    public void set_status (int status)
    {
        successful = status == 0;
    }

    public abstract void process (File file, string output);
}

private class NoOutputPostProcessor : PostProcessor
{
    public override void process (File file, string output)
    {
    }
}

private class AllOutputPostProcessor : PostProcessor
{
    public override void process (File file, string output)
    {
        if (output.length == 0)
            return;

        string[] lines = output.split ("\n");
        int nb_lines = lines.length;
        return_if_fail (nb_lines > 0);

        // Generally there is a \n at the end of the output so an empty line is added,
        // but we don't want to display it.
        if (lines[nb_lines - 1].length == 0)
            nb_lines--;

        BuildMsg message = BuildMsg ();
        message.type = BuildMsgType.OTHER;
        message.filename = null;
        message.lines_set = false;

        for (int line_num = 0 ; line_num < nb_lines ; line_num++)
        {
            message.text = lines[line_num];
            append_message (message);
        }
    }
}

private class RubberPostProcessor : PostProcessor
{
    private static Regex? _pattern = null;

    public RubberPostProcessor ()
    {
        if (_pattern != null)
            return;

        try
        {
            _pattern = new Regex (
                "(?P<file>[^:\n]+)(:(?P<line>[\\d\\-]+))?:(?P<text>.+)$",
                RegexCompileFlags.MULTILINE | RegexCompileFlags.OPTIMIZE);
        }
        catch (RegexError e)
        {
            stderr.printf ("RubberPostProcessor: %s\n", e.message);
        }
    }

    public override void process (File file, string output)
    {
        return_if_fail (_pattern != null);

        string parent_path = file.get_parent ().get_parse_name ();

        MatchInfo match_info;
        _pattern.match (output, 0, out match_info);
        while (match_info.matches ())
        {
            BuildMsg message = BuildMsg ();
            message.text = match_info.fetch_named ("text");

            // message type
            message.type = BuildMsgType.ERROR;
            if (message.text.contains ("Underfull") || message.text.contains ("Overfull"))
                message.type = BuildMsgType.BADBOX;

            // line
            message.lines_set = false;
            string? line = match_info.fetch_named ("line");
            if (line != null && 0 < line.length)
            {
                message.lines_set = true;
                string[] parts = line.split ("-");
                message.start_line = int.parse (parts[0]);
                if (1 < parts.length && parts[1] != null && 0 < parts[1].length)
                    message.end_line = int.parse (parts[1]);
                else
                    message.end_line = -1;
            }

            // filename
            message.filename = match_info.fetch_named ("file");
            if (message.filename[0] != '/')
                message.filename = "%s/%s".printf (parent_path, message.filename);

            append_message (message);

            try
            {
                match_info.next ();
            }
            catch (RegexError e)
            {
                stderr.printf ("Warning: RubberPostProcessor: %s\n", e.message);
                break;
            }
        }
    }
}

private class LatexmkPostProcessor : PostProcessor
{
    private static Regex? _reg_rule = null;
    private static Regex? _reg_no_rule = null;
    private bool _force_show_all;

    public LatexmkPostProcessor (bool force_show_all)
    {
        _force_show_all = force_show_all;

        if (_reg_rule != null)
            return;

        try
        {
            string ungreedy_lines = "((?U)(.*\\R)*)";

            string reg_rule_str = "(?P<title>Run number \\d+ of rule '(?P<rule>.*)')\\R";
            reg_rule_str += "(-{12}\\R){2}";
            reg_rule_str += "Running '(?P<cmd>.*)'\\R";
            reg_rule_str += "-{12}\\R";
            reg_rule_str += ungreedy_lines;
            reg_rule_str += "(Latexmk: applying rule .*\\R)+";
            reg_rule_str += "(For rule '.*', running .*\\R)?";
            reg_rule_str += "(?P<output>" + ungreedy_lines + ")";
            reg_rule_str += "(?P<latexmk>(Latexmk:|Rule '.*':)" + ungreedy_lines + ")";
            reg_rule_str += "(-{12}\\R|$)"; // the $ matches only the end of the string

            _reg_rule = new Regex (reg_rule_str, RegexCompileFlags.OPTIMIZE);

            string reg_no_rule_str = "(Latexmk: This is Latexmk.*\\R)?";
            reg_no_rule_str += "(\\*{4} Report bugs.*\\R)?";
            reg_no_rule_str += "(?P<output>(.*\\R)*)";

            _reg_no_rule = new Regex (reg_no_rule_str);
        }
        catch (RegexError e)
        {
            stderr.printf ("LatexmkPostProcessor: %s\n", e.message);
        }
    }

    public override void process (File file, string output)
    {
        return_if_fail (_reg_rule != null && _reg_no_rule != null);

        string last_latex_output = null;
        unowned Node<BuildMsg?> last_latex_node = null;

        MatchInfo match_info;
        _reg_rule.match (output, 0, out match_info);
        while (match_info.matches ())
        {
            Node<BuildMsg?> cmd_messages = null;

            /* command output */
            string rule = match_info.fetch_named ("rule");

            // if the rule is latex or pdflatex, we store the output
            bool is_latex_cmd = rule == "latex" || rule == "pdflatex";
            if (is_latex_cmd)
            {
                last_latex_output = match_info.fetch_named ("output");
                cmd_messages = new Node<BuildMsg?> (BuildMsg ());
            }

            // if it's another rule (bibtex, makeindex, etc), we show all output
            else
            {
                string cmd_output = match_info.fetch_named ("output");
                PostProcessor all_output_pp = new AllOutputPostProcessor ();
                all_output_pp.process (file, cmd_output);
                cmd_messages = all_output_pp.get_messages ();
            }

            /* title */
            BuildMsg title_msg = BuildMsg ();
            title_msg.type = BuildMsgType.OTHER;
            title_msg.lines_set = false;
            title_msg.text = match_info.fetch_named ("title");

            cmd_messages.data = title_msg;

            /* command line */
            BuildMsg cmd_line_msg = BuildMsg ();
            cmd_line_msg.type = BuildMsgType.OTHER;
            cmd_line_msg.lines_set = false;
            cmd_line_msg.text = "$ " + match_info.fetch_named ("cmd");

            cmd_messages.insert_data (0, cmd_line_msg);

            if (is_latex_cmd)
                last_latex_node = _all_messages.append ((owned) cmd_messages);
            else
                _all_messages.append ((owned) cmd_messages);

            /* Latexmk output */
            string latexmk_output = match_info.fetch_named ("latexmk");
            PostProcessor all_output_pp = new AllOutputPostProcessor ();
            all_output_pp.process (file, latexmk_output);
            Node<BuildMsg?> latexmk_messages = all_output_pp.get_messages ();

            title_msg.text = _("Latexmk messages");
            latexmk_messages.data = title_msg;
            _all_messages.append ((owned) latexmk_messages);

            try
            {
                match_info.next ();
            }
            catch (RegexError e)
            {
                stderr.printf ("Warning: LatexmkPostProcessor: %s\n", e.message);
                break;
            }
        }

        /* Run the latex post processor on the last latex or pdflatex output */
        if (last_latex_output != null)
        {
            PostProcessor latex_pp = new LatexPostProcessor ();
            latex_pp.process (file, last_latex_output);
            Node<BuildMsg?> latex_messages = latex_pp.get_messages ();

            bool last_cmd_is_latex_cmd =
                _all_messages.last_child ().prev_sibling () == last_latex_node;

            // Almost all the time, the user wants to see only the latex output.
            // If an error has occured, we verify if the last command was a latex command.
            // If it is the case, there is no need to show all output.
            if (! _force_show_all && (successful || last_cmd_is_latex_cmd))
                _all_messages = (owned) latex_messages;

            // Replace 'last_latex_node' by 'latex_messages'
            else
            {
                // take the title
                latex_messages.data = last_latex_node.data;

                // take the command line
                latex_messages.insert (0, last_latex_node.first_child ().unlink ());

                // replace
                int pos = _all_messages.child_position (last_latex_node);
                last_latex_node.unlink ();
                _all_messages.insert (pos, (owned) latex_messages);
            }
        }

        if (_all_messages.children != null)
            return;

        /* show all output since there were no rule executed */

        PostProcessor all_output_pp = new AllOutputPostProcessor ();

        if (_reg_no_rule.match (output, 0, out match_info))
        {
            // almost all output
            string all_output = match_info.fetch_named ("output");
            all_output_pp.process (file, all_output);
        }
        else
            all_output_pp.process (file, output);

        _all_messages = all_output_pp.get_messages ();
    }
}
