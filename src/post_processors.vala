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

private interface PostProcessor : GLib.Object
{
    public abstract bool successful { get; protected set; }
    public abstract void process (File file, string output, int status);
    public abstract BuildIssue[] get_issues ();
}

private class NoOutputPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }

    public void process (File file, string output, int status)
    {
        successful = status == 0;
    }

    public BuildIssue[] get_issues ()
    {
        // empty
        BuildIssue[] issues = {};
        return issues;
    }
}

private class AllOutputPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }
    private BuildIssue[] issues = {};

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

        issues = new BuildIssue[l];

        BuildIssue issue = BuildIssue ();
        issue.message_type = BuildMessageType.OTHER;
        issue.filename = null;
        issue.start_line = -1;
        issue.end_line = -1;

        for (int i = 0 ; i < l ; i++)
        {
            issues[i] = issue;
            issues[i].message = (owned) lines[i];
        }
    }

    public BuildIssue[] get_issues ()
    {
        return issues;
    }
}

private class RubberPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }
    private static Regex? pattern = null;
    private BuildIssue[] issues = {};

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
                stderr.printf ("Warning in RubberPostProcessor: %s\n", e.message);
            }
        }
    }

    public void process (File file, string output, int status)
    {
        successful = status == 0;
        if (pattern == null)
            return;

        string parent_path = file.get_parent ().get_parse_name ();

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
                issue.filename = "%s/%s".printf (parent_path, issue.filename);

            issues += issue;

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

    public BuildIssue[] get_issues ()
    {
        return issues;
    }
}
