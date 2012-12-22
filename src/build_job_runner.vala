/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2012 Sébastien Wilmet
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
 *
 * Author: Sébastien Wilmet
 */

public class BuildJobRunner : GLib.Object
{
    private BuildJob _build_job;
    private File _on_file;

    private BuildCommandRunner? _command_runner = null;
    private PostProcessor? _post_processor = null;

    public signal void finished (bool success);

    public BuildJobRunner (BuildJob build_job, File on_file)
    {
        _build_job = build_job;
        _on_file = on_file;
    }

    public string get_command_line () throws ShellError
    {
        string[] command_args = get_command_args (true);
        return string.joinv (" ", command_args);
    }

    public string get_command_name ()
    {
        try
        {
            string[] command_args = get_command_args (true);

            if (command_args.length == 0)
                return "";

            return command_args[0];
        }
        catch (ShellError e)
        {
            return "";
        }
    }

    public void run () throws ShellError, Error
    {
        string[] command_args = get_command_args ();
        string working_directory = _on_file.get_parent ().get_parse_name ();

        _command_runner = new BuildCommandRunner (command_args, working_directory);

        _command_runner.finished.connect ((exit_status) =>
        {
            create_post_processor (exit_status);
            _post_processor.process (_on_file, _command_runner.get_output ());

            finished (exit_status == 0);

            _command_runner = null;
        });

        if (_build_job.post_processor == PostProcessorType.NO_OUTPUT)
            _command_runner.execute_without_output ();
        else
            _command_runner.execute_with_output ();
    }

    public bool has_details ()
    {
        if (_post_processor == null)
            return false;
        else
            return _post_processor.has_details ();
    }

    public Gee.List<BuildMsg?> get_messages ()
    {
        if (_post_processor == null)
        {
            warning ("Build job runner: try to get messages too early");

            return new Gee.LinkedList<BuildMsg?> ();
        }

        return _post_processor.get_messages ();
    }

    public Gee.List<BuildMsg?> get_detailed_messages ()
    {
        if (_post_processor == null)
            return get_messages ();
        else
            return _post_processor.get_detailed_messages ();
    }

    public void abort ()
    {
        if (_command_runner != null)
            _command_runner.abort ();
    }

    private string[] get_command_args (bool for_printing = false) throws ShellError
    {
        /* Separate arguments */
        string[] args = {};
        Shell.parse_argv (_build_job.command, out args);

        /* Re-add quotes if needed */
        if (for_printing)
        {
            string[] new_args = {};
            foreach (string arg in args)
            {
                if (arg.contains (" "))
                    new_args += "\"" + arg + "\"";
                else
                    new_args += arg;
            }

            args = new_args;
        }

        /* Replace placeholders */
        string base_filename = _on_file.get_basename ();
        string base_shortname = Utils.get_shortname (base_filename);

        string[] new_args = {};
        foreach (string arg in args)
        {
            if (arg.contains ("$filename"))
                new_args += arg.replace ("$filename", base_filename);

            else if (arg.contains ("$shortname"))
                new_args += arg.replace ("$shortname", base_shortname);

            else if (arg.contains ("$view"))
            {
                warning ("Build job runner: the '$view' placeholder is deprecated.");
                new_args += arg.replace ("$view", "xdg-open");
            }

            else
                new_args += arg;
        }

        return new_args;
    }

    private void create_post_processor (int exit_status)
    {
        switch (_build_job.post_processor)
        {
            case PostProcessorType.ALL_OUTPUT:
                _post_processor = new AllOutputPostProcessor ();
                break;

            case PostProcessorType.LATEX:
                _post_processor = new LatexPostProcessor ();
                break;

            case PostProcessorType.LATEXMK:
                _post_processor = new LatexmkPostProcessor (exit_status);
                break;

            case PostProcessorType.NO_OUTPUT:
                _post_processor = new NoOutputPostProcessor ();
                break;

            default:
                warning ("Unknown post processor. Use no-output.");
                _post_processor = new NoOutputPostProcessor ();
                break;
        }
    }
}
