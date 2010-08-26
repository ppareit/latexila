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

public struct BuildJob
{
    public bool must_succeed;
    public string post_processor;
    public string command;
}

public struct BuildTool
{
    public string description;
    public string extensions;
    public string label;
    public string icon;
    public bool compilation;
    public unowned List<BuildJob?> jobs;
}

public class AppSettings : GLib.Settings
{
    private static AppSettings instance = null;

    private Settings editor;
    private Settings desktop_interface;

    public string system_font { get; private set; }

    /* AppSettings is a singleton */
    private AppSettings ()
    {
        Object (schema: "org.gnome.latexila");
        initialize ();
        load_build_tools ();
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
        desktop_interface = new Settings ("org.gnome.desktop.interface");

        system_font = desktop_interface.get_string ("monospace-font-name");

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

        desktop_interface.changed["monospace-font-name"].connect ((setting, key) =>
        {
            system_font = setting.get_string (key);
            if (editor.get_boolean ("use-default-font"))
                set_font (system_font);
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
    }

    private void set_font (string font)
    {
        foreach (var view in Application.get_default ().get_views ())
            view.set_font_from_string (font);
    }


    /*********************
     *    BUILD TOOLS    *
     *********************/

    private List<BuildTool?> build_tools = null;
    private BuildTool current_build_tool;
    private BuildJob current_build_job;

    public BuildTool build_tool_view_dvi { get; private set; }
    public BuildTool build_tool_view_pdf { get; private set; }
    public BuildTool build_tool_view_ps  { get; private set; }

    private bool current_tool_is_view_dvi = false;
    private bool current_tool_is_view_pdf = false;
    private bool current_tool_is_view_ps  = false;

    public unowned List<BuildTool?> get_build_tools ()
    {
        return build_tools;
    }

    private void load_build_tools ()
    {
        try
        {
            File file = File.new_for_path (Config.DATA_DIR + "/build_tools/"
                + _("build_tools-en.xml"));
            string contents;
            file.load_contents (null, out contents);

            MarkupParser parser = { parser_start, parser_end, parser_text, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);
        }
        catch (GLib.Error e)
        {
            stderr.printf ("Warning: impossible to load build tools: %s\n", e.message);
        }
    }

    public void print_build_tools ()
    {
        foreach (BuildTool build_tool in build_tools)
            Utils.print_build_tool (build_tool);
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "tools":
                return;

            case "tool":
                current_build_tool = BuildTool ();
                current_build_tool.compilation = false;
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "description":
                            current_build_tool.description = attr_values[i];
                            break;
                        case "extensions":
                            current_build_tool.extensions = attr_values[i];
                            break;
                        case "label":
                            current_build_tool.label = attr_values[i];
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
                            current_build_tool.compilation = icon.contains ("compile");
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
                return;

            case "tool":
                build_tools.append (current_build_tool);
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
        if (context.get_element () == "job")
            current_build_job.command = text;
    }
}
