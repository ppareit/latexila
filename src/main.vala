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

using Gtk;

private struct CmdLineData
{
    bool new_document;
    bool new_window;
}

private void check_xdg_data_dirs ()
{
    // GSettings looks for compiled schemas in locations specified by the XDG_DATA_DIRS
    // environment variable.

    // Environment.get_system_data_dirs() is not used because this function store the
    // value in a cache. If we change the value of the environment variable, the cache is
    // not modified...
    string? data_dirs_env = Environment.get_variable ("XDG_DATA_DIRS");
    if (data_dirs_env == null)
        data_dirs_env = "/usr/local/share:/usr/share";

    string[] data_dirs = data_dirs_env.split (":");
    if (! (Config.SCHEMA_DIR in data_dirs))
    {
        Environment.set_variable ("XDG_DATA_DIRS",
            Config.SCHEMA_DIR + ":" + data_dirs_env, true);
    }
}

private void init_i18n ()
{
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);
}

private CmdLineData parse_cmd_line_options (string[] args)
{
    bool show_version = false;
    string[] files_list;
    CmdLineData data = CmdLineData ();

    OptionEntry[] options = new OptionEntry[5];

    options[0] = { "version", 'V', 0, OptionArg.NONE, ref show_version,
        N_("Show the application's version"), null };

    options[1] = { "new-document", 'n', 0, OptionArg.NONE, ref data.new_document,
        N_("Create new document"), null };

    options[2] = { "new-window", 0, 0, OptionArg.NONE, ref data.new_window,
        N_("Create a new top-level window in an existing instance of LaTeXila"), null };

    options[3] = { "", 0, 0, OptionArg.FILENAME_ARRAY, ref files_list,
        null, "[FILE...]" };

    options[4] = { null };

    OptionContext context = Utils.get_option_context (options);

    try
    {
        context.parse (ref args);
    }
    catch (OptionError e)
    {
        warning ("%s", e.message);
        stderr.printf (
            _("Run '%s --help' to see a full list of available command line options.\n"),
            args[0]);

        Process.exit (1);
    }

    if (show_version)
    {
        stdout.printf ("%s %s\n", Config.APP_NAME, Config.APP_VERSION);
        Process.exit (0);
    }

    return data;
}

int main (string[] args)
{
    check_xdg_data_dirs ();
    init_i18n ();

    CmdLineData data = parse_cmd_line_options (args);

    Latexila app = new Latexila ();

    try
    {
        app.register ();
    }
    catch (Error e)
    {
        error ("Failed to register the application: %s", e.message);
    }

    if (data.new_window)
        app.activate_action ("new-window", null);

    if (data.new_document)
        app.activate_action ("new-document", null);

    return app.run ();
}
