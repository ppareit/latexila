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

    private int _job_num;
    private BuildJob _current_job;
    private TreeIter _current_job_title;
    private BuildJobRunner? _current_job_runner = null;

    private bool _aborted = false;

    public signal void finished ();

    public BuildToolRunner (BuildTool build_tool, File on_file, BuildView build_view)
    {
        _tool = build_tool;
        _on_file = on_file;
        _view = build_view;

        if (! match_allowed_extensions ())
        {
            warning ("Build tool runner: bad file extension");
            return;
        }

        _view.clear ();
        _main_title = _view.add_main_title (_tool.label, BuildState.RUNNING);

        _job_num = 0;
        proceed ();
    }

    public void abort ()
    {
        if (_current_job_runner != null)
            _current_job_runner.abort ();

        _view.set_title_state (_main_title, BuildState.ABORTED);
        _view.set_title_state (_current_job_title, BuildState.ABORTED);

        _aborted = true;
        finished ();
    }

    private bool match_allowed_extensions ()
    {
        string[] allowed_extensions = _tool.extensions.split (" ");

        if (allowed_extensions.length == 0)
            return true;

        string filename = _on_file.get_parse_name ();
        string extension = Utils.get_extension (filename);

        return extension in allowed_extensions;
    }

    private void proceed ()
    {
        // All jobs executed, finished.
        if (_tool.jobs.size <= _job_num)
        {
            _view.set_title_state (_main_title, BuildState.SUCCEEDED);
            finished ();
            return;
        }

        _current_job = _tool.jobs[_job_num];
        run_current_job ();
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
            _view.append_messages (_current_job_title,
                _current_job_runner.get_messages ());

            if (_aborted)
                return;

            BuildState state = success ? BuildState.SUCCEEDED : BuildState.FAILED;
            _view.set_title_state (_current_job_title, state);

            _job_num++;
            proceed ();
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

    private void failed ()
    {
        _view.set_title_state (_main_title, BuildState.FAILED);
        _view.set_title_state (_current_job_title, BuildState.FAILED);

        finished ();
    }
}
