/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010-2011 Sébastien Wilmet
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

using Gee;

public struct BuildJob
{
    public bool must_succeed;
    public string post_processor;
    public string command;
    public string[] command_args;
}

public struct BuildTool
{
    public string description;
    public string extensions;
    public string label;
    public string icon;
    public bool show;
    public bool compilation;
    public unowned GLib.List<BuildJob?> jobs;
}

public struct Project
{
    public File directory;
    public File main_file;
}

public class AppSettings : GLib.Settings
{
    private static AppSettings instance = null;

    private Settings editor;
    private Settings desktop_interface;
    private uint timeout_id = 0;

    public string system_font { get; private set; }

    /* AppSettings is a singleton */
    private AppSettings ()
    {
        Object (schema: "org.gnome.latexila");
        initialize ();
        load_build_tools ();
        load_projects ();
    }

    public static AppSettings get_default ()
    {
        if (instance == null)
            instance = new AppSettings ();
        return instance;
    }

    private void initialize ()
    {
        Settings prefs = get_child ("preferences");
        editor = prefs.get_child ("editor");

        // the desktop schemas are optional
        if (! Config.DESKTOP_SCHEMAS)
            system_font = "Monospace 10";
        else
        {
            desktop_interface = new Settings ("org.gnome.desktop.interface");
            system_font = desktop_interface.get_string ("monospace-font-name");

            desktop_interface.changed["monospace-font-name"].connect ((setting, key) =>
            {
                system_font = setting.get_string (key);
                if (editor.get_boolean ("use-default-font"))
                    set_font (system_font);
            });
        }

        editor.changed["use-default-font"].connect ((setting, key) =>
        {
            var val = setting.get_boolean (key);
            var font = val ? system_font : editor.get_string ("editor-font");
            set_font (font);
        });

        editor.changed["editor-font"].connect ((setting, key) =>
        {
            if (editor.get_boolean ("use-default-font"))
                return;
            set_font (setting.get_string (key));
        });

        editor.changed["scheme"].connect ((setting, key) =>
        {
            var scheme_id = setting.get_string (key);

            var manager = Gtk.SourceStyleSchemeManager.get_default ();
            var scheme = manager.get_scheme (scheme_id);

            foreach (var doc in Application.get_default ().get_documents ())
                doc.style_scheme = scheme;

            // we don't use doc.set_style_scheme_from_string() for performance reason
        });

        editor.changed["tabs-size"].connect ((setting, key) =>
        {
            uint val;
            setting.get (key, "u", out val);
            val = val.clamp (1, 24);

            foreach (var view in Application.get_default ().get_views ())
                view.tab_width = val;
        });

        editor.changed["insert-spaces"].connect ((setting, key) =>
        {
            var val = setting.get_boolean (key);

            foreach (var view in Application.get_default ().get_views ())
                view.insert_spaces_instead_of_tabs = val;
        });

        editor.changed["display-line-numbers"].connect ((setting, key) =>
        {
            var val = setting.get_boolean (key);

            foreach (var view in Application.get_default ().get_views ())
                view.show_line_numbers = val;
        });

        editor.changed["highlight-current-line"].connect ((setting, key) =>
        {
            var val = setting.get_boolean (key);

            foreach (var view in Application.get_default ().get_views ())
                view.highlight_current_line = val;
        });

        editor.changed["bracket-matching"].connect ((setting, key) =>
        {
            var val = setting.get_boolean (key);

            foreach (var doc in Application.get_default ().get_documents ())
                doc.highlight_matching_brackets = val;
        });

        editor.changed["auto-save"].connect ((setting, key) =>
        {
            var val = setting.get_boolean (key);

            foreach (var doc in Application.get_default ().get_documents ())
                doc.tab.auto_save = val;
        });

        editor.changed["auto-save-interval"].connect ((setting, key) =>
        {
            uint val;
            setting.get (key, "u", out val);

            foreach (var doc in Application.get_default ().get_documents ())
                doc.tab.auto_save_interval = val;
        });

        editor.changed["nb-most-used-symbols"].connect ((setting, key) =>
        {
            if (timeout_id != 0)
                Source.remove (timeout_id);
            timeout_id = Timeout.add_seconds (1, () =>
            {
                timeout_id = 0;
                Symbols.reload_most_used_symbols ();
                return false;
            });
        });
    }

    private void set_font (string font)
    {
        foreach (var view in Application.get_default ().get_views ())
            view.set_font_from_string (font);
    }


    /*********************
     *    BUILD TOOLS    *
     *********************/

    private LinkedList<BuildTool?> build_tools;
    private BuildTool current_build_tool;
    private BuildJob current_build_job;

    public BuildTool build_tool_view_dvi { get; private set; }
    public BuildTool build_tool_view_pdf { get; private set; }
    public BuildTool build_tool_view_ps  { get; private set; }

    private bool current_tool_is_view_dvi = false;
    private bool current_tool_is_view_pdf = false;
    private bool current_tool_is_view_ps  = false;

    private bool build_tools_modified = false;

    public unowned LinkedList<BuildTool?> get_build_tools ()
    {
        return build_tools;
    }

    public void move_build_tool_up (int num)
    {
        return_if_fail (num > 0);
        swap_build_tools (num, num - 1);
    }

    public void move_build_tool_down (int num)
    {
        return_if_fail (num < build_tools.size - 1);
        swap_build_tools (num, num + 1);
    }

    private void swap_build_tools (int num1, int num2)
    {
        return_if_fail (build_tools != null);

        BuildTool tool = build_tools.get (num1);
        build_tools.remove_at (num1);
        build_tools.insert (num2, tool);
        update_all_build_tools_menu ();
    }

    public void delete_build_tool (int num)
    {
        return_if_fail (build_tools != null);

        return_if_fail (num >= 0 && num < build_tools.size);
        build_tools.remove_at (num);
        update_all_build_tools_menu ();
    }

    public void append_build_tool (BuildTool tool)
    {
        return_if_fail (build_tools != null);

        tool.compilation = is_compilation (tool.icon);
        build_tools.add (tool);
        update_all_build_tools_menu ();
    }

    public void update_build_tool (int num, BuildTool tool, bool keep_show = false)
    {
        return_if_fail (build_tools != null);
        return_if_fail (num >= 0 && num < build_tools.size);
        BuildTool current_tool = build_tools.get (num);

        if (keep_show)
            tool.show = current_tool.show;

        if (! is_build_tools_equal (current_tool, tool))
        {
            tool.compilation = is_compilation (tool.icon);
            build_tools.remove_at (num);
            build_tools.insert (num, tool);
            update_all_build_tools_menu ();
        }
    }

    public void reset_all_build_tools ()
    {
        File file = get_user_config_build_tools_file ();
        if (file.query_exists ())
            Utils.delete_file (file);
        load_build_tools ();
        update_all_build_tools_menu ();
    }

    private bool is_build_tools_equal (BuildTool tool1, BuildTool tool2)
    {
        if (tool1.show != tool2.show
            || tool1.label != tool2.label
            || tool1.description != tool2.description
            || tool1.extensions != tool2.extensions
            || tool1.icon != tool2.icon
            || tool1.jobs.length () != tool2.jobs.length ())
            return false;

        for (uint i = 0 ; i < tool1.jobs.length () ; i++)
        {
            BuildJob job1 = tool1.jobs.nth_data (i);
            BuildJob job2 = tool2.jobs.nth_data (i);

            if (job1.command != job2.command
                || job1.must_succeed != job2.must_succeed
                || job1.post_processor != job2.post_processor)
                return false;
        }

        return true;
    }

    /*
    private void print_build_tools_summary ()
    {
        stdout.printf ("\n=== build tools summary ===\n");
        foreach (BuildTool tool in build_tools)
            stdout.printf ("%s\n", tool.label);
    }
    */

    private void update_all_build_tools_menu ()
    {
        build_tools_modified = true;
        foreach (MainWindow window in Application.get_default ().windows)
            window.update_build_tools_menu ();
    }

    private bool is_compilation (string icon)
    {
        // If it's a compilation, the file browser is refreshed after the execution.
        return icon.contains ("compile")
            || icon == Gtk.STOCK_EXECUTE
            || icon == Gtk.STOCK_CONVERT;
    }

    private void load_build_tools ()
    {
        build_tools = new LinkedList<BuildTool?> ();

        // First, try to load the user config file if it exists.
        // Otherwise try to load the default config file translated.
        // If the translated file doesn't exist or there is no translation
        // available, try to load the default file.

        File[] files = {};
        files += get_user_config_build_tools_file ();
        files += File.new_for_path (Path.build_filename (Config.DATA_DIR, "build_tools",
            _("build_tools-en.xml"), null));

        File default_file = File.new_for_path (Path.build_filename (Config.DATA_DIR,
            "build_tools", "build_tools-en.xml", null));

        // if no translation is available, there is only two files to test
        if (! default_file.equal (files[1]))
            files += default_file;

        foreach (File file in files)
        {
            try
            {
                if (! file.query_exists ())
                    continue;

                string contents;
                file.load_contents (null, out contents);

                MarkupParser parser =
                    { parser_start, parser_end, parser_text, null, null };
                MarkupParseContext context =
                    new MarkupParseContext (parser, 0, this, null);
                context.parse (contents, -1);
                break;
            }
            catch (GLib.Error e)
            {
                stderr.printf ("Warning: impossible to load build tools: %s\n",
                    e.message);
            }
        }
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "tools":
            case "label":
            case "description":
                return;

            case "tool":
                current_build_tool = BuildTool ();
                current_build_tool.compilation = false;
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "show":
                            current_build_tool.show = attr_values[i].to_bool ();
                            break;
                        case "extensions":
                            current_build_tool.extensions = attr_values[i];
                            break;
                        case "icon":
                            string icon = attr_values[i];
                            current_build_tool.icon = icon;
                            switch (icon)
                            {
                                case "view_dvi":
                                    current_tool_is_view_dvi = true;
                                    break;
                                case "view_pdf":
                                    current_tool_is_view_pdf = true;
                                    break;
                                case "view_ps":
                                    current_tool_is_view_ps = true;
                                    break;
                            }
                            current_build_tool.compilation = is_compilation (icon);
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "job":
                current_build_job = BuildJob ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "mustSucceed":
                            current_build_job.must_succeed = attr_values[i].to_bool ();
                            break;
                        case "postProcessor":
                            current_build_job.post_processor = attr_values[i];
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private void parser_end (MarkupParseContext context, string name) throws MarkupError
    {
        switch (name)
        {
            case "tools":
            case "label":
            case "description":
                return;

            case "tool":
                // the description is optional
                if (current_build_tool.description == null)
                    current_build_tool.description = current_build_tool.label;

                build_tools.add (current_build_tool);
                if (current_tool_is_view_dvi)
                {
                    build_tool_view_dvi = current_build_tool;
                    current_tool_is_view_dvi = false;
                }
                else if (current_tool_is_view_pdf)
                {
                    build_tool_view_pdf = current_build_tool;
                    current_tool_is_view_pdf = false;
                }
                else if (current_tool_is_view_ps)
                {
                    build_tool_view_ps = current_build_tool;
                    current_tool_is_view_ps = false;
                }
                break;

            case "job":
                current_build_tool.jobs.append (current_build_job);
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private void parser_text (MarkupParseContext context, string text, size_t text_len)
        throws MarkupError
    {
        switch (context.get_element ())
        {
            case "job":
                current_build_job.command = text.strip ();
                break;
            case "label":
                current_build_tool.label = text.strip ();
                break;
            case "description":
                current_build_tool.description = text.strip ();
                break;
        }
    }

    public void save_build_tools ()
    {
        return_if_fail (build_tools != null);

        if (! build_tools_modified)
            return;

        string content = "<tools>";
        foreach (BuildTool tool in build_tools)
        {
            content += "\n  <tool show=\"%s\" extensions=\"%s\" icon=\"%s\">\n".printf (
                tool.show.to_string (), tool.extensions, tool.icon);

            content += Markup.printf_escaped ("    <label>%s</label>\n", tool.label);
            content += Markup.printf_escaped ("    <description>%s</description>\n",
                tool.description);

            foreach (BuildJob job in tool.jobs)
            {
                content += "    <job mustSucceed=\"%s\" postProcessor=\"%s\">".printf (
                    job.must_succeed.to_string (),
                    job.post_processor);

                content += Markup.printf_escaped ("%s</job>\n", job.command);
            }
            content += "  </tool>\n";
        }
        content += "</tools>\n";

        try
        {
            File file = get_user_config_build_tools_file ();

            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            // a backup is made
            file.replace_contents (content, content.size (), null, true,
                FileCreateFlags.NONE, null, null);
        }
        catch (Error e)
        {
            stderr.printf ("Warning: impossible to save build tools: %s\n", e.message);
        }
    }

    private File get_user_config_build_tools_file ()
    {
        string path = Path.build_filename (Environment.get_user_config_dir (),
            "latexila", "build_tools.xml", null);
        return File.new_for_path (path);
    }


    /******************
     *    PROJECTS    *
     ******************/

    private LinkedList<Project?> projects;
    private bool projects_modified = false;

    public Project? get_project (int id)
    {
        return_val_if_fail (id >= 0 && id < projects.size, null);
        return projects[id];
    }

    public unowned LinkedList<Project?> get_projects ()
    {
        return projects;
    }

    private void update_projects_menus ()
    {
        foreach (MainWindow window in Application.get_default ().windows)
            window.update_config_project_sensitivity ();
    }

    // returns true if project successfully added
    public bool add_project (Project new_project, out File conflict)
    {
        foreach (Project project in projects)
        {
            if (projects_conflict (project.directory, new_project.directory))
            {
                conflict = project.directory;
                return false;
            }
        }

        projects.add (new_project);
        projects_modified = true;

        // find if some opened documents are belonging to the new project
        GLib.List<Document> docs = Application.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            if (doc.project_id != -1)
                continue;

            if (doc.location.has_prefix (new_project.directory))
                doc.project_id = projects.size - 1;
        }

        update_projects_menus ();

        return true;
    }

    // returns true if main file changed
    public bool project_change_main_file (int num, File new_main_file)
    {
        return_val_if_fail (num >= 0 && num < projects.size, false);
        Project project = projects[num];

        if (new_main_file.equal (project.main_file))
            return false;

        return_if_fail (new_main_file.has_prefix (project.directory));

        project.main_file = new_main_file;
        projects[num] = project;
        projects_modified = true;

        // refresh docs
        GLib.List<Document> docs = Application.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            if (doc.project_id == num)
                doc.project_id = num;
        }

        return true;
    }

    public void delete_project (int num)
    {
        return_if_fail (num >= 0 && num < projects.size);
        projects.remove_at (num);

        // refresh docs
        GLib.List<Document> docs = Application.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            if (doc.project_id == num)
                doc.project_id = -1;
            else if (doc.project_id > num)
                doc.project_id--;
        }

        update_projects_menus ();
    }

    public void clear_all_projects ()
    {
        projects.clear ();
        update_all_documents ();
        update_projects_menus ();
    }

    private void update_all_documents ()
    {
        GLib.List<Document> docs = Application.get_default ().get_documents ();
        foreach (Document doc in docs)
        {
            doc.project_id = -1;

            for (int i = 0 ; i < projects.size ; i++)
            {
                if (doc.location.has_prefix (projects[i].directory))
                {
                    doc.project_id = i;
                    break;
                }
            }
        }
    }

    private void load_projects ()
    {
        projects = new LinkedList<Project?> ();

        File file = get_file_projects ();
        if (! file.query_exists ())
            return;

        try
        {
            string contents;
            file.load_contents (null, out contents);

            MarkupParser parser = { projects_parser_start, null, null, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);

            update_all_documents ();
            update_projects_menus ();
        }
        catch (GLib.Error e)
        {
            stderr.printf ("Warning: impossible to load projects: %s\n",
                e.message);
        }
    }

    private void projects_parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "projects":
                return;

            case "project":
                Project project = Project ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "directory":
                            project.directory = File.new_for_uri (attr_values[i]);
                            break;
                        case "main_file":
                            project.main_file = File.new_for_uri (attr_values[i]);
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                projects.add (project);
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private File get_file_projects ()
    {
        string path = Path.build_filename (Environment.get_user_data_dir (),
            "latexila", "projects.xml", null);
        return File.new_for_path (path);
    }

    public void save_projects ()
    {
        if (! projects_modified)
            return;

        File file = get_file_projects ();

        // if empty, delete the file
        if (projects.size == 0)
        {
            Utils.delete_file (file);
            return;
        }

        string content = "<projects>\n";
        foreach (Project project in projects)
        {
            content += "  <project directory=\"%s\" main_file=\"%s\" />\n".printf (
                project.directory.get_uri (), project.main_file.get_uri ());
        }
        content += "</projects>\n";

        try
        {
            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            file.replace_contents (content, content.size (), null, false,
                FileCreateFlags.NONE, null, null);
        }
        catch (Error e)
        {
            stderr.printf ("Warning: impossible to save projects: %s\n",
                e.message);
        }
    }

    // returns true if dir1 is a subdirectory of dir2, or inversely
    private bool projects_conflict (File dir1, File dir2)
    {
        return dir1.has_prefix (dir2) || dir2.has_prefix (dir1) || dir1.equal (dir2);
    }

//    private void print_projects ()
//    {
//        stdout.printf ("\n=== PROJECTS ===\n");
//        foreach (Project project in projects)
//        {
//            stdout.printf ("\n= PROJECT =\n");
//            stdout.printf ("directory: %s\n", project.directory.get_parse_name ());
//            stdout.printf ("main file: %s\n", project.main_file.get_parse_name ());
//        }
//    }
}
