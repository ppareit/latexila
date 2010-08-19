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

public abstract class BuildToolProcess : GLib.Object
{
    private static const int POLL_INTERVAL = 250;
    private Pid? child_pid = null;
    private uint[] handlers = new uint[3];
    private IOChannel out_channel;
    private IOChannel err_channel;

    protected void execute (string[] command, string? working_directory)
    {
        try
        {
            int std_out, std_err;
            Process.spawn_async_with_pipes (working_directory, command, null,
                SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH, null,
                out child_pid, null, out std_out, out std_err);

            // we want to know the exit code
            handlers[0] = ChildWatch.add (child_pid, _on_exit);

            out_channel = new IOChannel.unix_new (std_out);
            err_channel = new IOChannel.unix_new (std_err);
            out_channel.set_flags (IOFlags.NONBLOCK);
            err_channel.set_flags (IOFlags.NONBLOCK);

            handlers[1] = Timeout.add (POLL_INTERVAL, _on_stdout);
            handlers[2] = Timeout.add (POLL_INTERVAL, _on_stderr);
        }
        catch (Error e)
        {
        }
    }

    /* Abort the running process */
    public void abort ()
    {
        if (child_pid != null)
        {
            foreach (uint handler in handlers)
                Source.remove (handler);
            Posix.kill (child_pid, Posix.SIGTERM);
            on_abort ();
        }
    }

    private bool _on_stdout ()
    {
        try
        {
            string text;
            size_t length;
            out_channel.read_to_end (out text, out length);
            if (length > 0)
                on_stdout (text);
        }
        catch (Error e) {}
        return true;
    }

    private bool _on_stderr ()
    {
        try
        {
            string text;
            size_t length;
            err_channel.read_to_end (out text, out length);
            if (length > 0)
                on_stderr (text);
        }
        catch (Error e) {}
        return true;
    }

    private void _on_exit (Pid pid, int status)
    {
        foreach (uint handler in handlers)
            Source.remove (handler);

        // read remaining output
        _on_stdout ();
        _on_stderr ();

        on_exit (status);
    }

    protected abstract void on_stdout (string text);
    protected abstract void on_stderr (string text);
    protected abstract void on_abort ();
    protected abstract void on_exit (int status);
}

public class BuildToolRunner : BuildToolProcess
{
    private File file;
    private string filename;
    private string shortname;
    private string directory;

    private string stdout_text = "";
    private string stderr_text = "";
    private unowned List<BuildJob?> jobs;
    private int job_num = 0;
    private unowned BuildJob current_job;
    private BuildView view;
    private TreeIter root_partition;
    private TreeIter[] job_partitions;

    public BuildToolRunner (File file, BuildTool tool, BuildView view)
    {
        this.file = file;
        filename = file.get_parse_name ();
        shortname = Utils.get_shortname (filename);
        directory = file.get_parent ().get_parse_name ();

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
            job_partitions += view.add_partition (job.command, PartitionState.RUNNING,
                root_partition);

        view.set_can_abort (true, this);
        proceed ();
    }

    private void proceed ()
    {
        // all jobs executed, finished
        if (job_num >= jobs.length ())
        {
            view.set_partition_state (root_partition, PartitionState.SUCCEEDED);
            return;
        }

        current_job = jobs.nth_data (job_num);
        string[] command = current_job.command.split (" ");

        // replace placeholders
        for (int i = 0 ; i < command.length ; i++)
        {
            if (command[i].contains ("$filename"))
            {
                command[i] = command[i].replace ("$filename", filename);
                continue;
            }
            else if (command[i].contains ("$shortname"))
            {
                command[i] = command[i].replace ("$shortname", shortname);
                continue;
            }
            else if (command[i].contains ("$directory"))
            {
                command[i] = command[i].replace ("$directory", directory);
                continue;
            }
        }

        execute (command, directory);
    }

    protected override void on_stdout (string text)
    {
        stdout_text += text;
    }

    protected override void on_stderr (string text)
    {
        stderr_text += text;
    }

    protected override void on_abort ()
    {
        view.set_can_abort (false, null);
        view.set_partition_state (root_partition, PartitionState.ABORTED);
        for (int i = job_num ; i < job_partitions.length ; i++)
            view.set_partition_state (job_partitions[i], PartitionState.ABORTED);
    }

    protected override void on_exit (int status)
    {
        // create post processor
        PostProcessor post_processor;
        switch (current_job.post_processor)
        {
            case "GenericPostProcessor":
            // TODO rubber post processor
            case "RubberPostProcessor":
                post_processor = new GenericPostProcessor ();
                break;
            default:
                stderr.printf ("Warning: unknown post processor \"%s\". Use GenericPostProcessor.",
                    current_job.post_processor);
                post_processor = new GenericPostProcessor ();
                break;
        }

        post_processor.process (file, stdout_text, stderr_text, status);
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
            {
                view.set_partition_state (root_partition, PartitionState.FAILED);
                for (int i = job_num + 1 ; i < job_partitions.length ; i++)
                    view.set_partition_state (job_partitions[i], PartitionState.ABORTED);

                view.set_can_abort (false, null);
            }
            else
            {
                job_num++;
                proceed ();
            }
        }
    }
}

private interface PostProcessor : GLib.Object
{
    public abstract bool successful { get; protected set; }
    public abstract void process (File file, string stdout, string stderr, int status);
    public abstract BuildIssue[] get_issues ();
    public abstract string summary ();
}

private class GenericPostProcessor : GLib.Object, PostProcessor
{
    public bool successful { get; protected set; }

    public void process (File file, string stdout, string stderr, int status)
    {
        successful = status == 0;
    }

    public BuildIssue[] get_issues ()
    {
        // empty
        BuildIssue[] issues = {};
        return issues;
    }

    public string summary ()
    {
        return "";
    }
}
