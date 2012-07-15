/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010-2012 Sébastien Wilmet
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
    // Store all the messages. A message can have children.
    protected Gee.List<BuildMsg?> _all_messages = new Gee.LinkedList<BuildMsg?> ();

    // These two attributes can be ignored for post-processors that don't support
    // detailed messages.
    protected bool _has_details = false;
    protected Gee.List<BuildMsg?> _messages_without_details =
        new Gee.LinkedList<BuildMsg?> ();

    public bool has_details ()
    {
        return _has_details;
    }

    public Gee.List<BuildMsg?> get_messages ()
    {
        if (_has_details)
            return _messages_without_details;
        else
            return _all_messages;
    }

    public Gee.List<BuildMsg?> get_detailed_messages ()
    {
        return _all_messages;
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

        for (int line_num = 0 ; line_num < nb_lines ; line_num++)
        {
            message.text = lines[line_num];
            _all_messages.add (message);
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
            warning ("RubberPostProcessor: %s", e.message);
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
            if (message.text.contains ("Underfull") ||
                message.text.contains ("Overfull"))
            {
                message.type = BuildMsgType.BADBOX;
            }

            // line
            string? line = match_info.fetch_named ("line");
            if (line != null && 0 < line.length)
            {
                string[] parts = line.split ("-");
                message.start_line = int.parse (parts[0]);
                if (1 < parts.length && parts[1] != null && 0 < parts[1].length)
                    message.end_line = int.parse (parts[1]);
            }

            // filename
            message.filename = match_info.fetch_named ("file");
            if (message.filename[0] != '/')
                message.filename = "%s/%s".printf (parent_path, message.filename);

            _all_messages.add (message);

            try
            {
                match_info.next ();
            }
            catch (RegexError e)
            {
                warning ("RubberPostProcessor: %s", e.message);
                break;
            }
        }
    }
}

private class LatexmkPostProcessor : PostProcessor
{
    private static Regex? _reg_rule = null;
    private static Regex? _reg_no_rule = null;
    private int _exit_status;

    public LatexmkPostProcessor (int exit_status)
    {
        _exit_status = exit_status;

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
            warning ("LatexmkPostProcessor: %s", e.message);
        }
    }

    public override void process (File file, string output)
    {
        return_if_fail (_reg_rule != null && _reg_no_rule != null);

        // We run the 'latex' post-processor only on the last latex or pdflatex rule.
        // The first latex rules most probably have warnings that are fixed in the last
        // latex rule.
        string? last_latex_output = null;
        int last_latex_child_num = 0;
        bool last_rule_is_latex_rule = false;

        MatchInfo match_info;
        _reg_rule.match (output, 0, out match_info);
        while (match_info.matches ())
        {
            BuildMsg msg = BuildMsg ();
            msg.type = BuildMsgType.JOB_SUB_COMMAND;

            // Do not expand the row, so the user have first a global view of what have
            // been executed.
            msg.expand = false;

            /* Title */

            msg.text = match_info.fetch_named ("title");

            /* Command line */

            BuildMsg cmd_line_msg = BuildMsg ();
            cmd_line_msg.text = "$ " + match_info.fetch_named ("cmd");
            msg.children.add (cmd_line_msg);

            /* Command output */

            string rule = match_info.fetch_named ("rule");

            // If the rule is latex or pdflatex, we store the output.
            bool is_latex_cmd = rule == "latex" || rule == "pdflatex";
            last_rule_is_latex_rule = is_latex_cmd;

            if (is_latex_cmd)
            {
                last_latex_output = match_info.fetch_named ("output");
                last_latex_child_num = _all_messages.size;
            }

            // If it's another rule (bibtex, makeindex, etc), we show all output.
            else
            {
                string cmd_output = match_info.fetch_named ("output");
                PostProcessor all_output_pp = new AllOutputPostProcessor ();
                all_output_pp.process (file, cmd_output);
                msg.children.add_all (all_output_pp.get_messages ());
            }

            _all_messages.add (msg);

            /* Latexmk output */

            BuildMsg latexmk_msg = BuildMsg ();
            latexmk_msg.type = BuildMsgType.JOB_SUB_COMMAND;
            latexmk_msg.text = _("Latexmk messages");
            latexmk_msg.expand = false;

            string latexmk_output = match_info.fetch_named ("latexmk");
            PostProcessor all_output_pp = new AllOutputPostProcessor ();
            all_output_pp.process (file, latexmk_output);
            latexmk_msg.children = all_output_pp.get_messages ();

            _all_messages.add (latexmk_msg);

            try
            {
                match_info.next ();
            }
            catch (RegexError e)
            {
                warning ("LatexmkPostProcessor: %s", e.message);
                break;
            }
        }

        /* Run the latex post processor on the last latex or pdflatex output */
        if (last_latex_output != null)
        {
            PostProcessor latex_pp = new LatexPostProcessor ();
            latex_pp.process (file, last_latex_output);

            // Almost all the time, the user wants to see only the latex output.
            // If an error has occured, we verify if the last command was a latex command.
            // If it is the case, there is no need to show all output.
            if (_exit_status == 0 || last_rule_is_latex_rule)
            {
                _has_details = true;
                _messages_without_details = latex_pp.get_messages ();
            }

            /* Add the latex messages */

            BuildMsg msg = _all_messages.get (last_latex_child_num);
            msg.children.add_all (latex_pp.get_messages ());

            // Expand only the last latex command.
            msg.expand = true;

            _all_messages.set (last_latex_child_num, msg);
        }

        if (_all_messages.size > 0)
            return;

        /* Show all output since there were no rule executed */

        PostProcessor all_output_pp = new AllOutputPostProcessor ();

        if (_reg_no_rule.match (output, 0, out match_info))
        {
            // Almost all output
            string all_output = match_info.fetch_named ("output");
            all_output_pp.process (file, all_output);
        }
        else
            all_output_pp.process (file, output);

        _all_messages = all_output_pp.get_messages ();
    }
}
