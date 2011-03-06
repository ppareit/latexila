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
