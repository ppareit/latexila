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

using Gtk;

public class BuildToolRunner : GLib.Object
{
    private static const int POLL_INTERVAL = 250;
    private Pid? child_pid = null;
    private uint[] handlers = {};
    private IOChannel out_channel;
    private bool read_output = true;
    private string output = "";

    private BuildView view;
    private bool compilation;
    private string document_view_program;
    private Gtk.Action action_stop_exec;

    private File file;
    private string filename;
    private string shortname;
    private string directory;

    private unowned List<BuildJob?> jobs;
    private int job_num = 0;
    private unowned BuildJob current_job;

    private TreeIter root_partition;
    private TreeIter[] job_partitions;

    public signal void finished ();

    public BuildToolRunner (File file, BuildTool tool, BuildView view,
        Gtk.Action action_stop_exec)
    {
        this.file = file;
        this.compilation = tool.compilation;
        this.action_stop_exec = action_stop_exec;

        filename = file.get_parse_name ();
        shortname = Utils.get_shortname (filename);
        directory = file.get_parent ().get_parse_name ();

        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.latex");
        document_view_program = settings.get_string ("document-view-program");

        // verify if file extension is allowed for the build tool
        string[] extensions = tool.extensions.split (" ");
        if (tool.extensions.length > 0
            && ! (Utils.get_extension (filename) in extensions))
        {
            stderr.printf ("Warning: bad file extension\n");
            return;
        }

        jobs = tool.jobs;
        this.view = view;
        view.clear ();
        root_partition = view.add_partition ("<b>" + tool.label + "</b>",
            PartitionState.RUNNING, null);

        foreach (BuildJob job in jobs)
        {
            string[] command = get_command (job, true);
            job_partitions += view.add_partition (string.joinv (" ", command),
                PartitionState.RUNNING, root_partition);
        }

        action_stop_exec.set_sensitive (true);
        proceed ();
    }

    public BuildToolRunner.web_browser (File file, string label, BuildView view,
        Gtk.Action action_stop_exec)
    {
        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.editor");

        BuildTool build_tool = BuildTool ();
        build_tool.extensions = "";
        build_tool.label = label;

        BuildJob build_job = BuildJob ();
        build_job.post_processor = "no-output";
        build_job.must_succeed = true;
        build_job.command = "%s $filename".printf (settings.get_string ("web-browser"));

        build_tool.jobs.append (build_job);

        this (file, build_tool, view, action_stop_exec);
    }

    private void execute (string[] command, string? working_directory) throws Error
    {
//        stdout.printf ("\nexecute ()\n");
//        stdout.printf ("working dir: %s\n", working_directory);
//        stdout.printf ("COMMAND:\n");
//        foreach (string cmd in command)
//            stdout.printf ("%s\n", cmd);

        try
        {
            int std_out;

            Process.spawn_async_with_pipes (working_directory, command, null,
                SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH,

                // redirect stderr into stdout
                () => { Posix.dup2 (Posix.STDOUT_FILENO, Posix.STDERR_FILENO); },

                out child_pid, null, out std_out);

            // we want to know the exit code
            handlers += ChildWatch.add (child_pid, on_exit);

            out_channel = new IOChannel.unix_new (std_out);
            out_channel.set_flags (IOFlags.NONBLOCK);

            handlers += Timeout.add (POLL_INTERVAL, on_output);
        }
        catch (Error e)
        {
            throw e;
        }
    }

    private void execute_without_output (string[] command, string? working_directory)
        throws Error
    {
        read_output = false;

        try
        {
            Process.spawn_async (working_directory, command, null,
                SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH, null,
                out child_pid);

            // we want to know the exit code
            handlers += ChildWatch.add (child_pid, on_exit);
        }
        catch (Error e)
        {
            throw e;
        }
    }

    /* Abort the running process */
    public void abort ()
    {
        if (child_pid == null)
            return;

        foreach (uint handler in handlers)
            Source.remove (handler);
        Posix.kill (child_pid, Posix.SIGTERM);

        action_stop_exec.set_sensitive (false);
        view.set_partition_state (root_partition, PartitionState.ABORTED);
        for (int i = job_num ; i < job_partitions.length ; i++)
            view.set_partition_state (job_partitions[i], PartitionState.ABORTED);
    }

    private bool on_output ()
    {
        return_val_if_fail (read_output, false);
        try
        {
            string text;
            size_t length;
            out_channel.read_to_end (out text, out length);
            if (length > 0)
                output += text;
        }
        catch (Error e) {}

        return true;
    }

    private void on_exit (Pid pid, int status)
    {
        foreach (uint handler in handlers)
            Source.remove (handler);

        // read remaining output
        if (read_output)
            on_output ();

        // create post processor
        PostProcessor post_processor;
        switch (current_job.post_processor)
        {
            case "no-output":
                //stdout.printf ("no-output post processor\n");
                post_processor = new NoOutputPostProcessor ();
                break;
            case "all-output":
                //stdout.printf ("all-output post processor\n");
                post_processor = new AllOutputPostProcessor ();
                break;
            case "rubber":
                //stdout.printf ("rubber post processor\n");
                post_processor = new RubberPostProcessor ();
                break;
            default:
                stderr.printf ("Warning: unknown post processor \"%s\". Use no-output.",
                    current_job.post_processor);
                post_processor = new NoOutputPostProcessor ();
                break;
        }

        post_processor.process (file, output, status);
        view.append_issues (job_partitions[job_num], post_processor.get_issues ());

        if (post_processor.successful)
        {
            view.set_partition_state (job_partitions[job_num], PartitionState.SUCCEEDED);
            job_num++;
            proceed ();
        }
        else
        {
            view.set_partition_state (job_partitions[job_num], PartitionState.FAILED);
            if (current_job.must_succeed)
                failed ();
            else
            {
                job_num++;
                proceed ();
            }
        }
    }

    private void proceed ()
    {
        // all jobs executed, finished
        if (job_num >= jobs.length ())
        {
            view.set_partition_state (root_partition, PartitionState.SUCCEEDED);
            action_stop_exec.set_sensitive (false);
            finished ();
            return;
        }

        // reset output because it's the same variable for all jobs
        output = "";

        current_job = jobs.nth_data (job_num);
        string[] command = get_command (current_job, false);

        try
        {
            if (current_job.post_processor == "no-output")
                execute_without_output (command, directory);

            // rubber
            else
            {
                // Attention, rubber doesn't support filenames with spaces, warn the user
                if (filename.contains (" "))
                {
                    BuildIssue[] issues = new BuildIssue[1];
                    BuildIssue issue = BuildIssue ();
                    issue.message = _("Rubber may not support filenames with spaces (even in a directory)");
                    issue.message_type = BuildMessageType.WARNING;
                    issue.filename = filename;
                    issues[0] = issue;

                    view.append_issues (job_partitions[job_num], issues);
                }
                execute (command, directory);
            }
        }
        catch (Error e)
        {
            view.set_partition_state (job_partitions[job_num], PartitionState.FAILED);
            view.add_partition (e.message, PartitionState.FAILED,
                job_partitions[job_num]);

            if (current_job.must_succeed)
                failed ();
            else
            {
                job_num++;
                proceed ();
            }
        }
    }

    private string[] get_command (BuildJob build_job, bool basename)
    {
        string base_filename = null;
        string base_shortname = null;
        if (basename)
        {
            base_filename = file.get_basename ();
            base_shortname = Utils.get_shortname (base_filename);
        }

        string[] command = build_job.command.split (" ");

        // replace placeholders
        for (int i = 0 ; i < command.length ; i++)
        {
            if (command[i].contains ("$view"))
            {
                command[i] = command[i].replace ("$view", document_view_program);
                continue;
            }
            if (command[i].contains ("$filename"))
            {
                command[i] = command[i].replace ("$filename", base_filename ?? filename);
                continue;
            }
            if (command[i].contains ("$shortname"))
            {
                command[i] = command[i].replace ("$shortname",
                    base_shortname ?? shortname);
                continue;
            }
        }

        return command;
    }

    private void failed ()
    {
        view.set_partition_state (root_partition, PartitionState.FAILED);
        for (int i = job_num + 1 ; i < job_partitions.length ; i++)
            view.set_partition_state (job_partitions[i], PartitionState.ABORTED);

        action_stop_exec.set_sensitive (false);
    }
}
