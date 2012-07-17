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

using Gtk;

public class MainWindowBuildTools
{
    private const Gtk.ActionEntry[] _action_entries =
    {
        { "Build", null, N_("_Build") },

        { "BuildClean", Stock.CLEAR, N_("Cleanup Build _Files"), null,
            N_("Clean-up build files (*.aux, *.log, *.out, *.toc, etc)"),
            on_build_clean },

        { "BuildStopExecution", Stock.STOP, N_("_Stop Execution"), null,
            N_("Stop Execution"), on_build_stop_execution },

        { "BuildViewLog", "view_log", N_("View _Log"), null,
            N_("View Log"), on_build_view_log },

        { "BuildToolsPreferences", Stock.PREFERENCES, N_("_Manage Build Tools"), null,
            N_("Manage Build Tools"), on_build_tools_preferences }
    };

    private const ToggleActionEntry[] _toggle_action_entries =
    {
        { "BuildShowDetails", Stock.ZOOM_IN, N_("Show _Details"), null,
            N_("Show Details"), null },

        { "BuildShowWarnings", Stock.DIALOG_WARNING, N_("Show _Warnings"), null,
            N_("Show Warnings"), null },

        { "BuildShowBadBoxes", "badbox", N_("Show _Bad Boxes"), null,
            N_("Show Bad Boxes"), null }
    };

    private unowned MainWindow _main_window;
    private UIManager _ui_manager;
    private BuildView _build_view;
    private FileBrowser _file_browser;

    private Gtk.ActionGroup _static_action_group;
    private Gtk.ActionGroup _dynamic_action_group;
    private uint _menu_ui_id;
    private BuildToolRunner _build_tool_runner;

    public MainWindowBuildTools (MainWindow main_window, UIManager ui_manager,
        BuildView build_view, FileBrowser file_browser)
    {
        _main_window = main_window;
        _ui_manager = ui_manager;
        _build_view = build_view;

        // TODO It would be better if the file browser could detect file updates.
        _file_browser = file_browser;

        /* Static Gtk.Actions */
        _static_action_group = new Gtk.ActionGroup ("BuildMenuActionGroup");
        _static_action_group.set_translation_domain (Config.GETTEXT_PACKAGE);
        _static_action_group.add_actions (_action_entries, this);
        _static_action_group.add_toggle_actions (_toggle_action_entries, this);

        Gtk.Action stop_exec = _static_action_group.get_action ("BuildStopExecution");
        stop_exec.sensitive = false;

        connect_toggle_actions ();

        ui_manager.insert_action_group (_static_action_group, 0);

        /* Dynamic Gtk.Actions (the placeholder) */
        _dynamic_action_group = new Gtk.ActionGroup ("BuildToolsActions");
        ui_manager.insert_action_group (_dynamic_action_group, 0);
        update_menu ();

        PersonalBuildTools build_tools = PersonalBuildTools.get_default ();
        build_tools.modified.connect (() => update_menu ());
    }

    public void update_sensitivity ()
    {
        Gtk.Action clean_action = _static_action_group.get_action ("BuildClean");
        Gtk.Action view_log_action = _static_action_group.get_action ("BuildViewLog");

        if (_main_window.active_tab == null)
        {
            _dynamic_action_group.set_sensitive (false);
            clean_action.set_sensitive (false);
            view_log_action.set_sensitive (false);
            return;
        }

        _dynamic_action_group.set_sensitive (true);

        Document active_doc = _main_window.active_document;

        bool is_tex = active_doc.is_main_file_a_tex_file ();
        clean_action.set_sensitive (is_tex);
        view_log_action.set_sensitive (is_tex);

        bool unsaved_doc = active_doc.location == null;
        string ext = "";
        if (! unsaved_doc)
        {
            string path = active_doc.get_main_file ().get_parse_name ();
            ext = Utils.get_extension (path);
        }

        int tool_num = 0;
        foreach (BuildTool tool in PersonalBuildTools.get_default ())
        {
            if (! tool.enabled)
            {
                tool_num++;
                continue;
            }

            Gtk.Action action = _dynamic_action_group.get_action (@"BuildTool_$tool_num");

            if (unsaved_doc)
                action.set_sensitive (tool.has_jobs ());
            else
            {
                string[] extensions = tool.extensions.split (" ");
                bool sensitive = tool.extensions.length == 0 || ext in extensions;
                action.set_sensitive (sensitive);
            }

            tool_num++;
        }
    }

    public void save_state ()
    {
        GLib.Settings settings =
            new GLib.Settings ("org.gnome.latexila.preferences.ui");

        ToggleAction action =
            _static_action_group.get_action ("BuildShowWarnings") as ToggleAction;
        settings.set_boolean ("show-build-warnings", action.active);

        action = _static_action_group.get_action ("BuildShowBadBoxes") as ToggleAction;
        settings.set_boolean ("show-build-badboxes", action.active);
    }

    private void update_menu ()
    {
        return_if_fail (_dynamic_action_group != null);

        if (_menu_ui_id != 0)
            _ui_manager.remove_ui (_menu_ui_id);

        foreach (Gtk.Action action in _dynamic_action_group.list_actions ())
        {
            action.activate.disconnect (activate_dynamic_action);
            _dynamic_action_group.remove_action (action);
        }

        PersonalBuildTools build_tools = PersonalBuildTools.get_default ();

        if (build_tools.is_empty ())
            _menu_ui_id = 0;
        else
            _menu_ui_id = _ui_manager.new_merge_id ();

        int tool_num = 0;
        int accel_num = 2;
        foreach (BuildTool build_tool in build_tools)
        {
            if (! build_tool.enabled)
            {
                tool_num++;
                continue;
            }

            string action_name = @"BuildTool_$tool_num";
            Gtk.Action action = new Gtk.Action (action_name, build_tool.label,
                build_tool.get_description (), build_tool.icon);

            // F2 -> F11
            // (F1 = help, F12 = show/hide side panel)
            string? accel = null;
            if (accel_num <= 11)
                accel = @"<Release>F$accel_num";

            _dynamic_action_group.add_action_with_accel (action, accel);
            action.activate.connect (activate_dynamic_action);

            _ui_manager.add_ui (_menu_ui_id,
                "/MainMenu/BuildMenu/BuildToolsPlaceholderMenu",
                action_name, action_name, UIManagerItemType.MENUITEM, false);

            _ui_manager.add_ui (_menu_ui_id,
                "/MainToolbar/BuildToolsPlaceholderToolbar",
                action_name, action_name, UIManagerItemType.TOOLITEM, false);

            tool_num++;
            accel_num++;
        }

        update_sensitivity ();
    }

    private void activate_dynamic_action (Gtk.Action action)
    {
        return_if_fail (_main_window.active_tab != null);

        string[] name = action.name.split ("_");
        int tool_num = int.parse (name[1]);

        BuildTool? tool = PersonalBuildTools.get_default ().get_build_tool (tool_num);
        return_if_fail (tool != null);

        if (! tool.has_jobs ())
            return_if_fail (_main_window.active_document.location != null);

        Document active_doc = _main_window.active_document;

        /* Save the document if jobs are executed */
        if (tool.has_jobs ())
        {
            if (active_doc.location == null)
            {
                bool tmp_location_set = active_doc.set_tmp_location ();
                return_if_fail (tmp_location_set);
            }

            int project_id = active_doc.project_id;

            if (project_id == -1)
                active_doc.save ();

            // Save all the documents belonging to the project
            else
            {
                Gee.List<Document> docs = Latexila.get_instance ().get_documents ();
                foreach (Document doc in docs)
                {
                    if (doc.project_id == project_id)
                        doc.save ();
                }
            }

            // Ensure that the files are correctly saved before the execution.
            Utils.flush_queue ();
        }

        _build_view.show ();

        Gtk.Action stop_exec = _static_action_group.get_action ("BuildStopExecution");
        stop_exec.sensitive = true;

        File main_file = active_doc.get_main_file ();
        _build_tool_runner = new BuildToolRunner (tool, main_file, _build_view);

        _build_tool_runner.finished.connect (() =>
        {
            stop_exec.sensitive = false;

            if (tool.has_jobs ())
                _file_browser.refresh_for_document (active_doc);
        });

        _build_tool_runner.run ();
    }

    private void connect_toggle_actions ()
    {
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.preferences.ui");

        /* Show details */

        ToggleAction action_details =
            _static_action_group.get_action ("BuildShowDetails") as ToggleAction;

        action_details.bind_property ("active", _build_view, "show-details",
            BindingFlags.DEFAULT);

        _build_view.bind_property ("has-details", action_details, "sensitive",
            BindingFlags.SYNC_CREATE);

        action_details.active = false;

        /* Show warnings */

        ToggleAction action_warnings =
            _static_action_group.get_action ("BuildShowWarnings") as ToggleAction;

        _build_view.bind_property ("show-warnings", action_warnings, "active",
            BindingFlags.BIDIRECTIONAL);

        action_warnings.active = settings.get_boolean ("show-build-warnings");

        /* Show badboxes */

        ToggleAction action_badboxes =
            _static_action_group.get_action ("BuildShowBadBoxes") as ToggleAction;

        _build_view.bind_property ("show-badboxes", action_badboxes, "active",
            BindingFlags.BIDIRECTIONAL);

        action_badboxes.active = settings.get_boolean ("show-build-badboxes");
    }

    /* Gtk.Action callbacks */

    public void on_build_stop_execution ()
    {
        return_if_fail (_build_tool_runner != null);
        _build_tool_runner.abort ();
    }

    public void on_build_clean ()
    {
        return_if_fail (_main_window.active_tab != null);

        CleanBuildFiles build_files = new CleanBuildFiles (_main_window,
            _main_window.active_document);

        if (build_files.clean ())
            _file_browser.refresh_for_document (_main_window.active_document);
    }

    public void on_build_view_log ()
    {
        return_if_fail (_main_window.active_tab != null);
        return_if_fail (_main_window.active_document.is_main_file_a_tex_file ());

        File mainfile = _main_window.active_document.get_main_file ();
        File directory = mainfile.get_parent ();

        string basename = Utils.get_shortname (mainfile.get_basename ()) + ".log";
        File file = directory.get_child (basename);
        DocumentTab? tab = _main_window.open_document (file);

        if (tab == null)
            warning ("Impossible to view log");
        else
            tab.document.readonly = true;
    }

    public void on_build_tools_preferences ()
    {
        new BuildToolsPreferences (_main_window);
    }
}