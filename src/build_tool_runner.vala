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
    private BuildTool _tool;
    private File _on_file;
    private BuildView _view;

    private TreeIter _main_title;

    // Used during the execution
    private int _job_num = 0;
    private BuildJob _current_job;
    private TreeIter? _current_job_title = null;
    private BuildJobRunner? _current_job_runner = null;

    // Keep references
    private TreeIter[] _job_titles = {};
    private BuildJobRunner[] _job_runners = {};

    private bool _aborted = false;

    public signal void finished ();

    public BuildToolRunner (BuildTool build_tool, File on_file, BuildView build_view)
    {
        _tool = build_tool;
        _on_file = on_file;
        _view = build_view;

        _view.clear ();
        _view.has_details = false;
        _main_title = _view.add_main_title (_tool.label, BuildState.RUNNING);

        /* Update the "has-details" property of the build view (which in turn determines
         * the sensitivity of the "show details" action).
         */
        finished.connect (() =>
        {
            foreach (BuildJobRunner job_runner in _job_runners)
            {
                if (job_runner.has_details ())
                {
                    _view.has_details = true;
                    return;
                }
            }
        });

        /* Show/hide details */
        _view.notify["show-details"].connect (() =>
        {
            for (int job_num = 0 ; job_num < _job_titles.length ; job_num++)
            {
                TreeIter job_title = _job_titles[job_num];
                BuildJobRunner job_runner = _job_runners[job_num];

                if (job_runner.has_details ())
                {
                    _view.remove_children (job_title);

                    Gee.List<BuildMsg?> messages;
                    if (_view.show_details)
                        messages = job_runner.get_detailed_messages ();
                    else
                        messages = job_runner.get_messages ();

                    _view.append_messages (job_title, messages);
                }
            }
        });
    }

    public void abort ()
    {
        if (_current_job_runner != null)
            _current_job_runner.abort ();

        _view.set_title_state (_main_title, BuildState.ABORTED);

        if (_current_job_title != null)
            _view.set_title_state (_current_job_title, BuildState.ABORTED);

        _aborted = true;
        finished ();
    }

    public void run ()
    {
        if (_job_num > 0)
        {
            _job_titles += _current_job_title;
            _job_runners += _current_job_runner;
        }

        _current_job_runner = null;

        // Run the next job.
        if (_job_num < _tool.jobs.size)
        {
            _current_job = _tool.jobs[_job_num];
            run_current_job ();
        }

        // All the jobs have run successfully, open the files.
        else if (open_files ())
        {
            _view.set_title_state (_main_title, BuildState.SUCCEEDED);
            finished ();
        }
    }

    private void run_current_job ()
    {
        _current_job_runner = new BuildJobRunner (_current_job, _on_file);

        if (! add_job_title ())
        {
            failed ();
            return;
        }

        _current_job_runner.finished.connect ((success) =>
        {
            Gee.List<BuildMsg?> messages;
            if (_view.show_details)
                messages = _current_job_runner.get_detailed_messages ();
            else
                messages = _current_job_runner.get_messages ();

            _view.append_messages (_current_job_title, messages);

            if (_aborted)
                return;

            BuildState state = success ? BuildState.SUCCEEDED : BuildState.FAILED;
            _view.set_title_state (_current_job_title, state);

            _job_num++;
            run ();
        });

        try
        {
            _current_job_runner.run ();
        }
        catch (ShellError e)
        {
            // This error is already catched in add_job_title() normally.
            critical ("Failed to parse command line a second time: %s", e.message);
            failed ();
        }
        catch (Error e)
        {
            BuildMsg error_msg = BuildMsg ();
            error_msg.text = e.message;
            error_msg.type = BuildMsgType.ERROR;
            _view.append_single_message (_current_job_title, error_msg);

            // If the command doesn't seem to be installed, display a more understandable
            // message.
            if (e is SpawnError.NOENT)
            {
                string command_name = _current_job_runner.get_command_name ();

                BuildMsg info_msg = BuildMsg ();
                info_msg.text =
                    _("%s doesn't seem to be installed.").printf (command_name);

                _view.append_single_message (_current_job_title, info_msg);
            }

            failed ();
        }
    }

    // Returns true on success.
    private bool add_job_title ()
    {
        try
        {
            string command_line = _current_job_runner.get_command_line ();
            _current_job_title = _view.add_job_title (command_line, BuildState.RUNNING);
            return true;
        }
        catch (ShellError error)
        {
            _current_job_title =
                _view.add_job_title (_current_job.command, BuildState.FAILED);

            BuildMsg message = BuildMsg ();
            message.text = "Failed to parse command line:";
            message.type = BuildMsgType.ERROR;
            _view.append_single_message (_current_job_title, message);

            message.text = error.message;
            message.type = BuildMsgType.INFO;
            _view.append_single_message (_current_job_title, message);

            return false;
        }
    }

    private bool open_files ()
    {
        string[] files_to_open = _tool.files_to_open.split (" ");

        foreach (string file_to_open in files_to_open)
        {
            if (! open_file (file_to_open))
                return false;
        }

        return true;
    }

    // Returns true on success.
    private bool open_file (string file_to_open)
    {
        /* Replace placeholders */

        string filename = _on_file.get_uri ();
        string shortname = Utils.get_shortname (filename);

        string uri;

        if (file_to_open.contains ("$filename"))
            uri = file_to_open.replace ("$filename", filename);

        else if (file_to_open.contains ("$shortname"))
            uri = file_to_open.replace ("$shortname", shortname);

        else
            uri = "file://" + file_to_open;

        /* Add title in the build view */

        string basename = Path.get_basename (uri);

        _current_job_title = _view.add_job_title (_("Open %s").printf (basename),
            BuildState.RUNNING);

        /* Check if the file exists */

        File file = File.new_for_uri (uri);
        if (! file.query_exists ())
        {
            BuildMsg message = BuildMsg ();
            message.text = _("The file '%s' doesn't exist.").printf (uri);
            message.type = BuildMsgType.ERROR;
            _view.append_single_message (_current_job_title, message);

            failed ();
            return false;
        }

        /* Show uri */

        try
        {
            Gtk.show_uri (_view.get_screen (), uri, Gdk.CURRENT_TIME);
        }
        catch (Error e)
        {
            BuildMsg message = BuildMsg ();
            message.text = _("Failed to open '%s':").printf (uri);
            message.type = BuildMsgType.ERROR;
            _view.append_single_message (_current_job_title, message);

            message.text = e.message;
            _view.append_single_message (_current_job_title, message);

            failed ();
            return false;
        }

        _view.set_title_state (_current_job_title, BuildState.SUCCEEDED);

        return true;
    }

    private void failed ()
    {
        _view.set_title_state (_main_title, BuildState.FAILED);
        _view.set_title_state (_current_job_title, BuildState.FAILED);

        finished ();
    }
}
