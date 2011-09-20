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
    private bool latexmk_show_all;
    private Gtk.Action action_stop_exec;

    private File file;
    private string filename;
    private string shortname;
    private string directory;

    private unowned Gee.ArrayList<BuildJob?> jobs;
    private int job_num = 0;
    private BuildJob current_job;

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
        latexmk_show_all = settings.get_boolean ("latexmk-always-show-all");

        // verify if file extension is allowed for the build tool
        string[] extensions = tool.extensions.split (" ");
        if (0 < tool.extensions.length
            && ! (Utils.get_extension (filename) in extensions))
        {
            warning ("Bad file extension");
            return;
        }

        jobs = tool.jobs;
        this.view = view;
        view.clear ();
        root_partition = view.add_partition (tool.label, PartitionState.RUNNING, null,
            true);

        if (! add_job_partitions ())
            return;

        action_stop_exec.set_sensitive (true);
        proceed ();
    }

    // Returns true on success, false otherwise.
    private bool add_job_partitions ()
    {
        job_num = 0;

        foreach (BuildJob job in jobs)
        {
            string[] command;

            try
            {
                command = get_command_args (job.command, true);
            }
            catch (ShellError e)
            {
                TreeIter job_partition = view.add_partition (job.command,
                    PartitionState.FAILED, root_partition);

                BuildMsg message = BuildMsg ();
                message.text = "Failed to parse command line:";
                message.type = BuildMsgType.ERROR;
                message.lines_set = false;
                view.append_single_message (job_partition, message);

                message.text = e.message;
                message.type = BuildMsgType.OTHER;
                view.append_single_message (job_partition, message);

                failed ();
                return false;
            }

            job_partitions += view.add_partition (string.joinv (" ", command),
                PartitionState.RUNNING, root_partition);

            job_num++;
        }

        job_num = 0;
        return true;
    }

    private void execute (string[] command, string? working_directory) throws Error
    {
//        stdout.printf ("command arguments:\n");
//        foreach (string arg in command)
//            stdout.printf ("%s\n", arg);
//        stdout.printf ("\n");

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
            out_channel.set_encoding (null);

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

        string? text = null;
        size_t length;

        try
        {
            out_channel.read_to_end (out text, out length);
        }
        catch (ConvertError e)
        {
            warning ("Read output: convert error: %s", e.message);
        }
        catch (IOChannelError e)
        {
            warning ("Read output: IO channel error: %s", e.message);
        }

        if (length <= 0)
            return true;

        // check if the output is a valid UTF-8 string
        if (text.validate ())
        {
            output += text;
            return true;
        }

        // make the conversion into UTF-8 line by line, because if it is done to the all
        // string at once, there are some encodings troubles with the "latex" and
        // "pdflatex" commands (with accents in the filename for instance).
        string[] lines = text.split ("\n");
        foreach (string line in lines)
        {
            string? line_utf8 = line.locale_to_utf8 (-1, null, null);

            if (line_utf8 == null)
            {
                try
                {
                    line_utf8 = convert (line, -1, "UTF-8", "ISO-8859-1");
                }
                catch (ConvertError e) {}
            }

            if (line_utf8 != null && line_utf8.validate ())
                output += line_utf8 + "\n";
            else
                warning ("Read output failed: %s", line);
        }

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
            case PostProcessorType.ALL_OUTPUT:
                post_processor = new AllOutputPostProcessor ();
                break;
            case PostProcessorType.LATEX:
                post_processor = new LatexPostProcessor ();
                break;
            case PostProcessorType.LATEXMK:
                post_processor = new LatexmkPostProcessor (latexmk_show_all);
                break;
            case PostProcessorType.NO_OUTPUT:
                post_processor = new NoOutputPostProcessor ();
                break;
            case PostProcessorType.RUBBER:
                post_processor = new RubberPostProcessor ();
                break;
            default:
                warning ("Unknown post processor. Use no-output.");
                post_processor = new NoOutputPostProcessor ();
                break;
        }

        post_processor.set_status (status);
        post_processor.process (file, output);

        view.append_messages (job_partitions[job_num], post_processor.get_messages ());

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
        if (job_num >= jobs.size)
        {
            view.set_partition_state (root_partition, PartitionState.SUCCEEDED);
            action_stop_exec.set_sensitive (false);
            finished ();
            return;
        }

        // reset output because it's the same variable for all jobs
        output = "";

        current_job = jobs[job_num];
        string[] command;

        try
        {
            command = get_command_args (current_job.command);
        }
        catch (ShellError e)
        {
            // This should never append, since the command has already been parsed for
            // printing purpose.
            critical ("Separate command arguments worked the first time…");
            failed ();
            return;
        }

        // Attention, rubber doesn't support filenames with spaces, warn the user
        if (current_job.post_processor == PostProcessorType.RUBBER
            && filename.contains (" "))
        {
            BuildMsg message = BuildMsg ();
            message.text =
                _("Rubber may not support filenames with spaces (even in a directory)");
            message.type = BuildMsgType.WARNING;
            message.filename = filename;
            message.lines_set = false;

            view.append_single_message (job_partitions[job_num], message);
        }

        try
        {
            if (current_job.post_processor == PostProcessorType.NO_OUTPUT)
                execute_without_output (command, directory);
            else
                execute (command, directory);
        }
        catch (Error e)
        {
            view.set_partition_state (job_partitions[job_num], PartitionState.FAILED);

            BuildMsg error_msg = BuildMsg ();
            error_msg.text = e.message;
            error_msg.type = BuildMsgType.ERROR;
            error_msg.lines_set = false;
            view.append_single_message (job_partitions[job_num], error_msg);

            // If the command doesn't seem to be installed, display a more understandable
            // message.
            if (e is SpawnError.NOENT)
            {
                BuildMsg info_msg = BuildMsg ();
                info_msg.text =
                    _("%s doesn't seem to be installed.").printf (command[0]);
                info_msg.type = BuildMsgType.OTHER;
                info_msg.lines_set = false;
                view.append_single_message (job_partitions[job_num], info_msg);
            }

            if (current_job.must_succeed)
                failed ();
            else
            {
                job_num++;
                proceed ();
            }
        }
    }

    private string[] get_command_args (string command_line, bool for_printing = false)
        throws ShellError
    {
        /* separate arguments */
        string[] command = {};

        try
        {
            Shell.parse_argv (command_line, out command);
        }
        catch (ShellError e)
        {
            warning ("Separate command arguments: %s", e.message);
            throw e;
        }

        /* re-add quotes if needed */
        if (for_printing)
        {
            for (int cmd_num = 0 ; cmd_num < command.length ; cmd_num++)
            {
                string cur_cmd = command[cmd_num];
                if (cur_cmd.contains (" "))
                    command[cmd_num] = "\"" + cur_cmd + "\"";
            }
        }

        /* replace placeholders */
        string base_filename = file.get_basename ();
        string base_shortname = Utils.get_shortname (base_filename);

        for (int i = 0 ; i < command.length ; i++)
        {
            if (command[i].contains ("$view"))
            {
                command[i] = command[i].replace ("$view", document_view_program);
                continue;
            }
            if (command[i].contains ("$filename"))
            {
                command[i] = command[i].replace ("$filename", base_filename);
                continue;
            }
            if (command[i].contains ("$shortname"))
            {
                command[i] = command[i].replace ("$shortname", base_shortname);
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
