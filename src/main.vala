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

bool _option_version;
bool _option_new_document;
bool _option_new_window;

[CCode (array_length = false, array_null_terminated = true)]
string[] _remaining_args;

const OptionEntry[] _options =
{
    {"version", 'V', 0, OptionArg.NONE, ref _option_version,
        N_("Show the application's version"), null },

    { "new-document", 'n', 0, OptionArg.NONE, ref _option_new_document,
        N_("Create new document"), null },

    { "new-window", 0, 0, OptionArg.NONE, ref _option_new_window,
        N_("Create a new top-level window in an existing instance of LaTeXila"), null },

    { "", 0, 0, OptionArg.FILENAME_ARRAY, ref _remaining_args,
        null, "[FILE...]" },

    { null }
};

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

private void parse_cmd_line_options (string[] args)
{
    OptionContext context =
        new OptionContext (_("- Integrated LaTeX Environment for GNOME"));
    context.add_main_entries (_options, Config.GETTEXT_PACKAGE);
    context.add_group (Gtk.get_option_group (false));

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

    if (_option_version)
    {
        stdout.printf ("%s %s\n", Config.APP_NAME, Config.APP_VERSION);
        Process.exit (0);
    }
}

int main (string[] args)
{
    check_xdg_data_dirs ();
    init_i18n ();

    Latexila app = new Latexila ();
    return app.run (args);
}
