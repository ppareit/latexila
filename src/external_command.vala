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

public class ExternalCommand : GLib.Object
{
    private MainWindow window;
    private LogZone log_zone;
    private CustomStatusbar statusbar;
    private uint context_id;
    private bool msg_in_statusbar = false;
    private Settings settings;
    private LogStore log_store;

    private static const string CMD_CHAR_1 = "%";
    private static const string CMD_CHAR_2 = "#";
    private static const string view_msg = _("Viewing in progress. Please wait...");

    enum OutputStatus
    {
        GO_FETCHING,
        IS_FETCHING,
        STOP_REQUEST
    }

    private int? child_pid_exit_code = null;
    private Pid child_pid;
    private OutputStatus output_status = OutputStatus.GO_FETCHING;

    private ExternalCommand (MainWindow window)
    {
        this.window = window;
        log_zone = window.get_log_zone ();
        statusbar = window.get_statusbar ();
        context_id = statusbar.get_context_id ("running-action");
        settings = new Settings ("org.gnome.latexila.preferences.latex");
    }

    public ExternalCommand.run_compilation (MainWindow window, string title,
        string setting)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
        this (window);

        log_store = log_zone.add_simple_action (this, title);

        try
        {
            string command_line = settings.get_string (setting);
            string[] command = process_command_line (command_line, true);

            statusbar.push (context_id, _("Compilation in progress. Please wait..."));
            msg_in_statusbar = true;
            Utils.flush_queue ();

            execute_with_output (command, get_working_directory ());
        }
        catch (Error e) {}
    }

    public ExternalCommand.view_current_document (MainWindow window, string title,
        string doc_extension)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
        this (window);

        log_store = log_zone.add_simple_action (this, title);

        try
        {
            string command_line = "%s %s.%s".printf (settings.get_string ("command-view"),
                CMD_CHAR_1, doc_extension);
            string[] command = process_command_line (command_line, false);
            execute_without_output (command, null, view_msg);
        }
        catch (Error e) {}
    }

    public ExternalCommand.view_document (MainWindow window, string title, File file)
    {
        this (window);
    }

    public ExternalCommand.convert_document (MainWindow window, string title,
        string setting)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
        this (window);

        log_store = log_zone.add_simple_action (this, title);

        try
        {
            string command_line = settings.get_string (setting);
            string[] command = process_command_line (command_line, true);
            string msg = _("Converting in progress. Please wait...");

            statusbar.push (context_id, msg);
            msg_in_statusbar = true;
            Utils.flush_queue ();

            execute_without_output (command, get_working_directory (), msg);
        }
        catch (Error e) {}
    }

    public ExternalCommand.run_bibtex (MainWindow window)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
        this (window);

        log_store = log_zone.add_simple_action (this, "BibTeX");

        try
        {
            string command_line = settings.get_string ("command-bibtex");
            string[] command = process_command_line (command_line, true);

            statusbar.push (context_id, _("BibTeX is running. Please wait..."));
            msg_in_statusbar = true;
            Utils.flush_queue ();

            execute_with_output (command, get_working_directory ());
        }
        catch (Error e) {}
    }

    public ExternalCommand.run_makeindex (MainWindow window)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
        this (window);

        log_store = log_zone.add_simple_action (this, "MakeIndex");

        try
        {
            string command_line = settings.get_string ("command-makeindex");
            string[] command = process_command_line (command_line, true);

            statusbar.push (context_id, _("MakeIndex is running. Please wait..."));
            msg_in_statusbar = true;
            Utils.flush_queue ();

            execute_with_output (command, get_working_directory ());
        }
        catch (Error e) {}
    }

    public ExternalCommand.view_in_web_browser (MainWindow window, string title,
        File file)
    {
        this (window);
    }

    private string[] process_command_line (string command_line, bool basename)
        throws FileError
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());

        // get filename without extension
        string path = window.active_document.location.get_parse_name ();
        string path_without_extension = path[0:-4];
        string path_replace = basename ? Path.get_basename (path_without_extension)
            : path_without_extension;

        string[] command = command_line.split (" ");
        string[] files_to_check = {};

        // replace special chars by filename without extension
        for (int i = 0 ; i < command.length ; i++)
        {
            if (command[i].contains (CMD_CHAR_1))
            {
                files_to_check += command[i].replace (CMD_CHAR_1, path_without_extension);
                command[i] = command[i].replace (CMD_CHAR_1, path_replace);
            }
            else if (command[i].contains (CMD_CHAR_2))
                command[i] = command[i].replace (CMD_CHAR_2, path_replace);
        }

        // print command line
        log_store.print_output_info ("$ " + string.joinv (" ", command));

        // check if files exist
        foreach (string file_to_check in files_to_check)
        {
            File file = File.new_for_path (file_to_check);
            if (! file.query_exists ())
            {
                string exit_msg = Path.get_basename (file_to_check) + " "
                    + _("does not exist.");
                log_store.print_output_exit (1337, exit_msg);
                throw new FileError.EXIST (exit_msg);
            }
        }

        return command;
    }

    private string get_working_directory ()
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.location != null);
        return window.active_document.location.get_parent ().get_path ();
    }

    private void execute_without_output (string[] command, string? working_directory,
        string msg)
    {
        try
        {
            Process.spawn_async (working_directory, command, null,
                SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH, null,
                out child_pid);

            log_store.print_output_info (msg);

            // we don't care about output status, but finish_execute () expects to have
            // this value
            output_status = OutputStatus.STOP_REQUEST;

            // we want to know the exit code
            ChildWatch.add (child_pid, on_child_watch);
        }
        catch (SpawnError e)
        {
            string exit_msg = _("execution failed: %s").printf (e.message);
            log_store.print_output_exit (42, exit_msg);
        }
    }

    private void execute_with_output (string[] command, string? working_directory)
    {
        try
        {
            int output;

            Process.spawn_async_with_pipes (working_directory, command, null,
                SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH, on_spawn_setup,
                out child_pid, null, out output);

            // we want to know the exit code
            ChildWatch.add (child_pid, on_child_watch);

            // create the channel
            IOChannel out_channel = new IOChannel.unix_new (output);
            try
            {
                out_channel.set_encoding (null);
            }
            catch (IOChannelError e) {}

            out_channel.add_watch (IOCondition.IN | IOCondition.HUP, on_watch_output);
        }
        catch (SpawnError e)
        {
            string exit_msg = _("execution failed: %s").printf (e.message);
            log_store.print_output_exit (42, exit_msg);
        }
    }

    private void on_spawn_setup ()
    {
        Posix.dup2 (Posix.STDOUT_FILENO, Posix.STDERR_FILENO);
    }

    private bool on_watch_output (IOChannel source, IOCondition condition)
    {
        switch (output_status)
        {
            case OutputStatus.GO_FETCHING:
                break;

            case OutputStatus.IS_FETCHING:
                return false;

            case OutputStatus.STOP_REQUEST:
                //finish_execute ();
                return false;
        }

        output_status = OutputStatus.IS_FETCHING;

        if (IOCondition.IN in condition)
        {
            string line = null;
            try
            {
                var gio_status = source.read_line (out line, null, null);
                if (gio_status == IOStatus.NORMAL
                    && output_status == OutputStatus.IS_FETCHING)
                {
                    string line_utf8 = null;
                    if (line != null)
                    {
                        line_utf8 = line.locale_to_utf8 (-1, null, null);
                        if (line_utf8 == null)
                        {
                            try
                            {
                                line_utf8 = convert (line, -1, "UTF-8", "ISO-8859-1");
                            }
                            catch (ConvertError e) {}
                        }
                    }

                    // the line is not displayed if it contains bad characters
                    if (line_utf8 != null)
                    {
                        // delete \n
                        line_utf8 = line_utf8[0:-1];
                        log_store.print_output_normal (line_utf8);
                    }

                    gio_status = source.read_line (out line, null, null);
                }

                if (gio_status == IOStatus.EOF)
                {
                    output_status = OutputStatus.STOP_REQUEST;
                    //finish_execute ();
                    return false;
                }
            }
            catch (Error e)
            {
                stderr.printf ("Warning: IO channel error: %s\n", e.message);
            }
        }

        if (IOCondition.HUP in condition)
        {
            output_status = OutputStatus.STOP_REQUEST;
            //finish_execute ();
            return false;
        }

        if (output_status == OutputStatus.IS_FETCHING)
            output_status = OutputStatus.GO_FETCHING;

        return true;
    }

    private void on_child_watch (Pid pid, int status)
    {
        Process.close_pid (pid);
        if (Process.if_exited (status))
            child_pid_exit_code = Process.exit_status (status);
        else
            child_pid_exit_code = -1;

        finish_execute ();
    }

    private void finish_execute ()
    {
        return_if_fail (child_pid_exit_code != null
            && output_status == OutputStatus.STOP_REQUEST);

        if (child_pid_exit_code > -1)
            log_store.print_output_exit (child_pid_exit_code);
        else
            log_store.print_output_exit (42, _("The child process exited abnormally"));

        log_zone.output_view_columns_autosize ();
        if (msg_in_statusbar)
            statusbar.pop (context_id);
    }

    public void stop_execution ()
    {
        output_status = OutputStatus.STOP_REQUEST;
        Posix.kill (child_pid, Posix.SIGTERM);
        //log_store.can_stop = false;
    }
}
