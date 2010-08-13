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
    //private OutputStatus output_status = OutputStatus.GO_FETCHING;

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
    }

    public ExternalCommand.view_current_document (MainWindow window, string title,
        string doc_extension)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());

        this (window);

        log_store = log_zone.add_simple_action (title);

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

        log_store = log_zone.add_simple_action (title);

        try
        {
            string command_line = settings.get_string (setting);
            string[] command = process_command_line (command_line, false);
            string msg = _("Converting in progress. Please wait...");

            statusbar.push (context_id, msg);
            msg_in_statusbar = true;
            Utils.flush_queue ();

            string working_directory =
                window.active_document.location.get_parent ().get_path ();
            execute_without_output (command, working_directory, msg);
        }
        catch (Error e) {}
    }

    public ExternalCommand.run_bibtex (MainWindow window)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
        this (window);
    }

    public ExternalCommand.run_makeindex (MainWindow window)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
        this (window);
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

    private void execute_without_output (string[] command, string? working_directory,
        string msg)
    {
        try
        {
            Pid child_pid;
            Process.spawn_async (working_directory, command, null,
                SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH, null,
                out child_pid);

            log_store.print_output_info (msg);

            // we want to know the exit code
            ChildWatch.add (child_pid, child_watch_func);
        }
        catch (SpawnError e)
        {
            string exit_msg = _("execution failed: %s").printf (e.message);
            log_store.print_output_exit (42, exit_msg);
        }
    }

    private void child_watch_func (Pid pid, int status)
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
        return_if_fail (child_pid_exit_code != null);

        if (child_pid_exit_code > -1)
            log_store.print_output_exit (child_pid_exit_code);
        else
            log_store.print_output_exit (42, _("The child process exited abnormally"));

        log_zone.output_view_columns_autosize ();
        if (msg_in_statusbar)
            statusbar.pop (context_id);
    }
}
