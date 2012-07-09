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
 *
 * Author: Sébastien Wilmet
 */

// Run a single command line.

public class BuildCommandRunner : GLib.Object
{
    private string[] _command_args;
    private string? _working_directory;

    private Pid? _child_pid = null;
    private uint _child_watch_handler = 0;
    private IOChannel? _out_channel = null;

    public signal void finished (int exit_status);

    public BuildCommandRunner (string[] command_args, string? working_directory)
    {
        _command_args = command_args;
        _working_directory = working_directory;
    }

    public void execute_with_output () throws Error
    {
        int std_out;

        Process.spawn_async_with_pipes (
            _working_directory,
            _command_args,
            null,
            SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH,
            redirect_stderr_to_stdout,
            out _child_pid,
            null,
            out std_out
        );

        _child_watch_handler = ChildWatch.add (_child_pid, on_exit);

        _out_channel = new IOChannel.unix_new (std_out);
        _out_channel.set_encoding (null);
    }

    public void execute_without_output () throws Error
    {
        SpawnFlags flags =
            SpawnFlags.DO_NOT_REAP_CHILD |
            SpawnFlags.SEARCH_PATH |
            SpawnFlags.STDOUT_TO_DEV_NULL |
            SpawnFlags.STDERR_TO_DEV_NULL;

        Process.spawn_async (_working_directory, _command_args, null, flags, null,
            out _child_pid);

        _child_watch_handler = ChildWatch.add (_child_pid, on_exit);
    }

    public void abort ()
    {
        if (_child_pid != null)
        {
            Posix.kill (_child_pid, Posix.SIGTERM);
            _child_pid = null;
        }
    }

    public string get_output ()
    {
        if (_out_channel == null)
            return "";

        /* Read the output */

        string output = "";

        try
        {
            _out_channel.read_to_end (out output, null);
        }
        catch (ConvertError e)
        {
            warning ("Read output: convert error: %s", e.message);
        }
        catch (IOChannelError e)
        {
            warning ("Read output: IO channel error: %s", e.message);
        }

        /* Close the channel */

        try
        {
            _out_channel.shutdown (false);
        }
        catch (Error e) {}

        _out_channel = null;

        /* Return the result */

        // Check if the output is a valid UTF-8 string
        if (output.validate ())
            return output;

        return validate_output (output);
    }

    private void on_exit (Pid pid, int exit_status)
    {
        _child_watch_handler = 0;
        _child_pid = null;

        finished (exit_status);
    }

    private void redirect_stderr_to_stdout ()
    {
        Posix.dup2 (Posix.STDOUT_FILENO, Posix.STDERR_FILENO);
    }

    // Convert the output to UTF-8
    private string validate_output (string output)
    {
        // Make the conversion into UTF-8 line by line, because if it is done to the all
        // string at once, there are some encodings troubles with the "latex" and
        // "pdflatex" commands (with accents in the filename for instance).

        string new_output = "";
        string[] lines = output.split ("\n");

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
                new_output += line_utf8 + "\n";
            else
                warning ("Read output failed: %s", line);
        }

        return new_output;
    }
}
