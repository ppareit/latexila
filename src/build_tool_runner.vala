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

using Gtk;

public class BuildToolRunner : GLib.Object
{
    private BuildCommandRunner? _command_runner = null;

    private BuildView view;
    private bool latexmk_show_all;
    private Gtk.Action action_stop_exec;

    private File file;
    private string filename;
    private string shortname;
    private string directory;

    private unowned Gee.ArrayList<BuildJob?> jobs;
    private int job_num = 0;
    private BuildJob current_job;

    private TreeIter main_title;
    private TreeIter[] job_titles;

    public signal void finished ();

    public BuildToolRunner (File file, BuildTool tool, BuildView view,
        Gtk.Action action_stop_exec)
    {
        this.file = file;
        this.action_stop_exec = action_stop_exec;

        filename = file.get_parse_name ();
        shortname = Utils.get_shortname (filename);
        directory = file.get_parent ().get_parse_name ();

        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.latex");
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
        main_title = view.add_main_title (tool.label, BuildState.RUNNING);

        if (! add_job_titles ())
            return;

        action_stop_exec.set_sensitive (true);
        proceed ();
    }

    // Returns true on success, false otherwise.
    private bool add_job_titles ()
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
                TreeIter job_title =
                    view.add_job_title (job.command, BuildState.FAILED);

                BuildMsg message = BuildMsg ();
                message.text = "Failed to parse command line:";
                message.type = BuildMsgType.ERROR;
                view.append_single_message (job_title, message);

                message.text = e.message;
                message.type = BuildMsgType.INFO;
                view.append_single_message (job_title, message);

                failed ();
                return false;
            }

            string job_title = string.joinv (" ", command);
            job_titles += view.add_job_title (job_title, BuildState.RUNNING);

            job_num++;
        }

        job_num = 0;
        return true;
    }

    /* Abort the running process */
    public void abort ()
    {
        if (_command_runner != null)
            _command_runner.abort ();

        action_stop_exec.set_sensitive (false);
        view.set_title_state (main_title, BuildState.ABORTED);
        for (int i = job_num ; i < job_titles.length ; i++)
            view.set_title_state (job_titles[i], BuildState.ABORTED);
    }

    private void on_command_finished (int exit_status)
    {
        return_if_fail (_command_runner != null);

        // Create post processor
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

        post_processor.set_status (exit_status);
        post_processor.process (file, _command_runner.get_output ());

        view.append_messages (job_titles[job_num], post_processor.get_messages ());

        if (post_processor.successful)
        {
            view.set_title_state (job_titles[job_num], BuildState.SUCCEEDED);
            job_num++;
            proceed ();
        }
        else
        {
            view.set_title_state (job_titles[job_num], BuildState.FAILED);
            failed ();
        }
    }

    private void proceed ()
    {
        // all jobs executed, finished
        if (job_num >= jobs.size)
        {
            view.set_title_state (main_title, BuildState.SUCCEEDED);
            action_stop_exec.set_sensitive (false);
            finished ();
            return;
        }

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

            view.append_single_message (job_titles[job_num], message);
        }

        _command_runner = new BuildCommandRunner (command, directory);

        try
        {
            if (current_job.post_processor == PostProcessorType.NO_OUTPUT)
                _command_runner.execute_without_output ();
            else
                _command_runner.execute_with_output ();
        }
        catch (Error e)
        {
            view.set_title_state (job_titles[job_num], BuildState.FAILED);

            BuildMsg error_msg = BuildMsg ();
            error_msg.text = e.message;
            error_msg.type = BuildMsgType.ERROR;
            view.append_single_message (job_titles[job_num], error_msg);

            // If the command doesn't seem to be installed, display a more understandable
            // message.
            if (e is SpawnError.NOENT)
            {
                BuildMsg info_msg = BuildMsg ();
                info_msg.text =
                    _("%s doesn't seem to be installed.").printf (command[0]);
                view.append_single_message (job_titles[job_num], info_msg);
            }

            failed ();
        }

        _command_runner.finished.connect (on_command_finished);
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
                // TODO use gtk_show_uri() instead of xdg-open
                command[i] = command[i].replace ("$view", "xdg-open");
            }
            else if (command[i].contains ("$filename"))
            {
                command[i] = command[i].replace ("$filename", base_filename);
            }
            else if (command[i].contains ("$shortname"))
            {
                command[i] = command[i].replace ("$shortname", base_shortname);
            }
        }

        return command;
    }

    private void failed ()
    {
        view.set_title_state (main_title, BuildState.FAILED);
        for (int i = job_num + 1 ; i < job_titles.length ; i++)
            view.set_title_state (job_titles[i], BuildState.ABORTED);

        action_stop_exec.set_sensitive (false);
    }
}
