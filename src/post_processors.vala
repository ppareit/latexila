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

public struct PostProcessorIssues
{
    public string? partition_msg;
    public PartitionState partition_state;
    public Gee.ArrayList<BuildIssue?> issues;
}

private interface PostProcessor : GLib.Object
{
    public abstract bool successful { get; protected set; }
    public abstract void process (File file, string output, int status);
    public abstract PostProcessorIssues[] get_issues ();
}

private class NoOutputPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }

    public void process (File file, string output, int status)
    {
        successful = status == 0;
    }

    public PostProcessorIssues[] get_issues ()
    {
        // empty
        PostProcessorIssues[] issues = {};
        return issues;
    }
}

private class AllOutputPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }
    private Gee.ArrayList<BuildIssue?> issues = new Gee.ArrayList<BuildIssue?> ();

    public void process (File file, string output, int status)
    {
        successful = status == 0;

        if (output.length == 0)
            return;

        string[] lines = output.split ("\n");
        int l = lines.length;
        return_if_fail (l > 0);

        // Generally there is a \n at the end of the output so an empty line is added,
        // but we don't want to display it.
        if (lines[l-1].length == 0)
            l--;

        BuildIssue issue = BuildIssue ();
        issue.message_type = BuildMessageType.OTHER;
        issue.filename = null;
        issue.start_line = -1;
        issue.end_line = -1;

        for (int i = 0 ; i < l ; i++)
        {
            issue.message = lines[i];
            issues.add (issue);
        }
    }

    public PostProcessorIssues[] get_issues ()
    {
        PostProcessorIssues[] pp_issues = new PostProcessorIssues[1];
        pp_issues[0].partition_msg = null;
        pp_issues[0].issues = issues;
        return pp_issues;
    }
}

private class RubberPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }
    private static Regex? pattern = null;
    private Gee.ArrayList<BuildIssue?> issues = new Gee.ArrayList<BuildIssue?> ();

    public RubberPostProcessor ()
    {
        if (pattern == null)
        {
            try
            {
                pattern = new Regex (
                    "(?P<file>[^:\n]+)(:(?P<line>[0-9\\-]+))?:(?P<text>.+)$",
                    RegexCompileFlags.MULTILINE);
            }
            catch (RegexError e)
            {
                stderr.printf ("RubberPostProcessor: %s\n", e.message);
            }
        }
    }

    public void process (File file, string output, int status)
    {
        successful = status == 0;
        if (pattern == null)
            return;

        MatchInfo match_info;
        pattern.match (output, 0, out match_info);
        while (match_info.matches ())
        {
            BuildIssue issue = BuildIssue ();
            string text = issue.message = match_info.fetch_named ("text");

            // message type
            // TODO add an option to rubber that writes which type of message it is
            // e.g.: test.tex:5:box: Overfull blabla
            // types of messages: box, ref, misc, error (see --warn option)
            // update: this is not needed because we will use latexmk instead

            issue.message_type = BuildMessageType.ERROR;
            if (text.contains ("Underfull") || text.contains ("Overfull"))
                issue.message_type = BuildMessageType.BADBOX;

            // line
            issue.start_line = issue.end_line = -1;
            string line = match_info.fetch_named ("line");
            if (line != null && line.length > 0)
            {
                string[] parts = line.split ("-");
                issue.start_line = parts[0].to_int ();
                if (parts.length > 1 && parts[1] != null && parts[1].length > 0)
                    issue.end_line = parts[1].to_int ();
            }

            // filename
            issue.filename = match_info.fetch_named ("file");
            if (issue.filename[0] != '/')
                issue.filename = "%s/%s".printf (file.get_parent ().get_parse_name (),
                    issue.filename);

            issues.add (issue);

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

    public PostProcessorIssues[] get_issues ()
    {
        PostProcessorIssues[] pp_issues = new PostProcessorIssues[1];
        pp_issues[0].partition_msg = null;
        pp_issues[0].issues = issues;
        return pp_issues;
    }
}

private class LatexmkPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }
    private PostProcessorIssues[] all_issues = {};

    private static Regex? reg_rule = null;

    public LatexmkPostProcessor ()
    {
        if (reg_rule == null)
        {
            try
            {
                string reg_rule_str = "^-{12}\n";
                reg_rule_str += "(?P<line>Run number [0-9]+ of rule '(?P<rule>.*)')\n";
                reg_rule_str += "(-{12}\n){2}";
                reg_rule_str += "Running '(?P<cmd>.*)'\n";
                reg_rule_str += "-{12}\n";
                reg_rule_str += "Latexmk: applying rule .*\n";
                reg_rule_str += "(?P<output>(.*\n)*)";
                reg_rule_str += "Latexmk:.*";
                reg_rule = new Regex (reg_rule_str,
                    RegexCompileFlags.MULTILINE | RegexCompileFlags.UNGREEDY);
            }
            catch (RegexError e)
            {
                stderr.printf ("LatexmkPostProcessor: %s\n", e.message);
            }
        }
    }

    public void process (File file, string output, int status)
    {
        //stdout.printf ("*** OUTPUT ***\n\n%s\n\n*** END OUTPUT ***\n\n", output);
        successful = status == 0;
        if (reg_rule == null)
            return;

        string latex_output = null;
        int last_latex_cmd_index = 0;

        MatchInfo match_info;
        reg_rule.match (output, 0, out match_info);
        for (int i = 0 ; match_info.matches () ; i++)
        {
            PostProcessorIssues pp_issues = PostProcessorIssues ();
            pp_issues.partition_msg = match_info.fetch_named ("line");
            pp_issues.partition_state = PartitionState.SUCCEEDED;

            Gee.ArrayList<BuildIssue?> issues = new Gee.ArrayList<BuildIssue?> ();

            BuildIssue issue = BuildIssue ();
            issue.message_type = BuildMessageType.OTHER;
            issue.start_line = -1;
            issue.message = "$ " + match_info.fetch_named ("cmd");
            issues.add (issue);

            string rule = match_info.fetch_named ("rule");

            // if the rule is latex or pdflatex, we store the output
            if (rule.has_suffix ("latex"))
            {
                latex_output = match_info.fetch_named ("output");
                last_latex_cmd_index = i;
            }

            // if it's another rule (bibtex, makeindex, etc), we show all output
            else
            {
                string cmd_output = match_info.fetch_named ("output");
                PostProcessor all_output_pp = new AllOutputPostProcessor ();
                all_output_pp.process (file, cmd_output, 0);
                PostProcessorIssues[] all_output_issues = all_output_pp.get_issues ();

                // normally there is no partition in the output
                return_if_fail (all_output_issues.length == 1
                    && all_output_issues[0].partition_msg == null);

                issues.add_all (all_output_issues[0].issues);
            }

            pp_issues.issues = issues;
            all_issues += pp_issues;

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

        // Run latex post processor on the last latex or pdflatex output
        if (latex_output != null)
        {
            PostProcessor latex_pp = new LatexPostProcessor ();
            latex_pp.process (file, latex_output, 0);
            PostProcessorIssues[] latex_issues = latex_pp.get_issues ();

            // normally there is no partition in the latex output
            return_if_fail (latex_issues.length == 1
                && latex_issues[0].partition_msg == null);

            all_issues[last_latex_cmd_index].issues.add_all (latex_issues[0].issues);
        }
    }

    public PostProcessorIssues[] get_issues ()
    {
        return all_issues;
    }
}
