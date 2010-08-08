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

public class ExternalCommands : GLib.Object
{
    private MainWindow window;
    private LogZone log_zone;
    private CustomStatusbar statusbar;
    private uint statusbar_context_id;
    private Settings settings;

    private static const string CMD_CHAR_1 = "%";
    private static const string CMD_CHAR_2 = "#";
    private static const string view_msg = _("Viewing in progress. Please wait...");

    public ExternalCommands (MainWindow window, LogZone log_zone,
        CustomStatusbar statusbar)
    {
        this.window = window;
        this.log_zone = log_zone;
        this.statusbar = statusbar;
        statusbar_context_id = statusbar.get_context_id ("running-action");
        settings = new Settings ("org.gnome.latexila.preferences.latex");
    }

    public void run_compilation (string title, string command)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
    }

    public void view_current_document (string title, string doc_extension)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());

        LogStore log_store = log_zone.add_simple_action (title);

        try
        {
            string command_line = "%s %s.%s".printf (settings.get_string ("command-view"),
                CMD_CHAR_1, doc_extension);
            string[] command = process_command_line (log_store, command_line, false);
            ExecuteCommand exec = new ExecuteCommand.without_output (log_store, command,
                null, view_msg);
            exec.finished.connect (() => log_zone.output_view_columns_autosize ());
        }
        catch (Error e) {}
    }

    public void view_document (string title, File file)
    {
    }

    public void convert_document (string title, string setting)
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());

        LogStore log_store = log_zone.add_simple_action (title);

        try
        {
            string command_line = settings.get_string (setting);
            string[] command = process_command_line (log_store, command_line, false);
            string msg = _("Converting in progress. Please wait...");

            statusbar.push (statusbar_context_id, msg);
            Utils.flush_queue ();

            string working_directory =
                window.active_document.location.get_parent ().get_path ();
            ExecuteCommand exec = new ExecuteCommand.without_output (log_store, command,
                working_directory, msg);
            exec.finished.connect (() =>
            {
                log_zone.output_view_columns_autosize ();
                statusbar.pop (statusbar_context_id);
            });
        }
        catch (Error e) {}
    }

    public void run_bibtex ()
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
    }

    public void run_makeindex ()
    {
        return_if_fail (window.active_tab != null);
        return_if_fail (window.active_document.is_tex_document ());
    }

    public void view_in_web_browser (string title, File file)
    {
    }

    private string[] process_command_line (LogStore log_store, string command_line,
        bool basename) throws FileError
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
}

public class ExecuteCommand : GLib.Object
{
    enum OutputStatus
    {
        GO_FETCHING,
        IS_FETCHING,
        STOP_REQUEST
    }

    private LogStore log_store;
    private int? child_pid_exit_code = null;
    //private OutputStatus output_status = OutputStatus.GO_FETCHING;

    public signal void finished ();

    public ExecuteCommand.without_output (LogStore log_store, string[] command,
        string? working_directory, string msg)
    {
        this.log_store = log_store;
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

        finished ();
    }
}
