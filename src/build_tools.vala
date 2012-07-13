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

public enum PostProcessorType
{
    ALL_OUTPUT = 0,
    LATEX,
    LATEXMK,
    NO_OUTPUT,
    RUBBER,
    N_POST_PROCESSORS
}

public struct BuildJob
{
    PostProcessorType post_processor;
    string command;
}

public struct BuildTool
{
    string description;
    string extensions;
    string label;
    string icon;
    string files_to_open;
    bool enabled;
    bool compilation;
    Gee.ArrayList<BuildJob?> jobs;
}

public class BuildTools : GLib.Object
{
    private static BuildTools _instance = null;

    private static string[] _post_processor_names =
    {
        // Same order as the PostProcessorType enum.
        "all-output",
        "latex",
        "latexmk",
        "no-output",
        "rubber"
    };

    private Gee.LinkedList<BuildTool?> _build_tools;
    private bool _modified = false;

    // Used during the XML file parsing to load the build tools.
    private BuildTool _cur_tool;
    private BuildJob _cur_job;

    public signal void modified ();

    // Singleton
    private BuildTools ()
    {
        int nb_post_processors = PostProcessorType.N_POST_PROCESSORS;
        return_if_fail (_post_processor_names.length == nb_post_processors);

        modified.connect (() => _modified = true);

        load ();
    }

    public static BuildTools get_default ()
    {
        if (_instance == null)
            _instance = new BuildTools ();

        return _instance;
    }

    public BuildTool? get_by_id (int id)
    {
        return_val_if_fail (0 <= id && id < _build_tools.size, null);

        return _build_tools[id];
    }

    public Gee.Iterator<BuildTool?> iterator ()
    {
        return _build_tools.iterator ();
    }

    public bool is_empty ()
    {
        return _build_tools.size == 0;
    }

    public void move_up (int num)
    {
        return_if_fail (num > 0);
        swap (num, num - 1);
    }

    public void move_down (int num)
    {
        return_if_fail (num < _build_tools.size - 1);
        swap (num, num + 1);
    }

    private void swap (int num1, int num2)
    {
        BuildTool tool = _build_tools[num1];
        _build_tools.remove_at (num1);
        _build_tools.insert (num2, tool);
        modified ();
    }

    public void delete (int num)
    {
        return_if_fail (0 <= num && num < _build_tools.size);

        _build_tools.remove_at (num);
        modified ();
    }

    public void add (BuildTool tool)
    {
        insert (_build_tools.size, tool);
    }

    public void insert (int pos, BuildTool tool)
    {
        return_if_fail (0 <= pos && pos <= _build_tools.size);

        tool.compilation = is_compilation (tool);
        _build_tools.insert (pos, tool);
        modified ();
    }

    public void update (int num, BuildTool tool)
    {
        return_if_fail (0 <= num && num < _build_tools.size);

        BuildTool current_tool = _build_tools[num];

        if (! is_equal (current_tool, tool))
        {
            tool.compilation = is_compilation (tool);
            _build_tools.remove_at (num);
            _build_tools.insert (num, tool);
            modified ();
        }
    }

    public void reset_all ()
    {
        File file = get_user_config_file ();
        if (file.query_exists ())
            Utils.delete_file (file);

        load ();
        modified ();
    }

    private bool is_equal (BuildTool tool1, BuildTool tool2)
    {
        if (tool1.enabled != tool2.enabled
            || tool1.label != tool2.label
            || tool1.description != tool2.description
            || tool1.extensions != tool2.extensions
            || tool1.icon != tool2.icon
            || tool1.files_to_open != tool2.files_to_open
            || tool1.jobs.size != tool2.jobs.size)
        {
            return false;
        }

        for (int job_num = 0 ; job_num < tool1.jobs.size ; job_num++)
        {
            BuildJob job1 = tool1.jobs[job_num];
            BuildJob job2 = tool2.jobs[job_num];

            if (job1.command != job2.command
                || job1.post_processor != job2.post_processor)
            {
                return false;
            }
        }

        return true;
    }

    // If it's a compilation, the files are first saved before running the
    // build tool, and the file browser is refreshed after the execution.
    private bool is_compilation (BuildTool build_tool)
    {
        return build_tool.jobs.size > 0;
    }

    private void load ()
    {
        _build_tools = new Gee.LinkedList<BuildTool?> ();

        // First, try to load the user config file if it exists.
        // Otherwise try to load the default file (from most desirable to least desirable,
        // depending of the current locale).

        File[] files = {};
        files += get_user_config_file ();

        unowned string[] language_names = Intl.get_language_names ();
        foreach (string language_name in language_names)
        {
            files += File.new_for_path (Path.build_filename (Config.DATA_DIR,
                "build_tools", language_name, "build_tools.xml"));
        }

        foreach (File file in files)
        {
            if (! file.query_exists ())
                continue;

            string? contents = Utils.load_file (file);
            if (contents == null)
                continue;

            try
            {
                MarkupParser parser =
                    { parser_start, parser_end, parser_text, null, null };
                MarkupParseContext context =
                    new MarkupParseContext (parser, 0, this, null);
                context.parse (contents, -1);
                break;
            }
            catch (GLib.Error e)
            {
                warning ("Impossible to load build tools: %s", e.message);
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
            case "open":
                return;

            case "tool":
                _cur_tool = BuildTool ();
                _cur_tool.compilation = false;
                _cur_tool.jobs = new Gee.ArrayList<BuildJob?> ();

                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        // 'show' was the previous name of 'enabled'
                        case "show":
                        case "enabled":
                            _cur_tool.enabled = bool.parse (attr_values[i]);
                            break;

                        case "extensions":
                            _cur_tool.extensions = attr_values[i];
                            break;

                        case "icon":
                            _cur_tool.icon = attr_values[i];
                            break;

                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "job":
                _cur_job = BuildJob ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "postProcessor":
                            _cur_job.post_processor = get_post_processor_type_from_name (
                                attr_values[i]);
                            break;

                        // for compatibility
                        case "mustSucceed":
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
            case "open":
                return;

            case "tool":
                // the description is optional
                if (_cur_tool.description == null)
                    _cur_tool.description = _cur_tool.label;

                _cur_tool.compilation = is_compilation (_cur_tool);

                _build_tools.add (_cur_tool);
                break;

            case "job":
                _cur_tool.jobs.add (_cur_job);
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
                _cur_job.command = text.strip ();
                break;

            case "label":
                _cur_tool.label = text.strip ();
                break;

            case "description":
                _cur_tool.description = text.strip ();
                break;

            case "open":
                _cur_tool.files_to_open = text.strip ();
                break;
        }
    }

    public void save ()
    {
        if (! _modified)
            return;

        string content = "<tools>";

        foreach (BuildTool tool in _build_tools)
        {
            content += "\n  <tool enabled=\"%s\"".printf (tool.enabled.to_string ());
            content += " extensions=\"%s\"".printf (tool.extensions);
            content += " icon=\"%s\">\n".printf (tool.icon);

            content += Markup.printf_escaped ("    <label>%s</label>\n", tool.label);
            content += Markup.printf_escaped ("    <description>%s</description>\n",
                tool.description);

            foreach (BuildJob job in tool.jobs)
            {
                content += "    <job postProcessor=\"%s\">".printf (
                    get_post_processor_name_from_type (job.post_processor));

                content += Markup.printf_escaped ("%s</job>\n", job.command);
            }

            content += Markup.printf_escaped ("    <open>%s</open>\n",
                tool.files_to_open);

            content += "  </tool>\n";
        }

        content += "</tools>\n";

        // save the file
        File file = get_user_config_file ();
        Utils.save_file (file, content, true);
    }

    private File get_user_config_file ()
    {
        string path = Path.build_filename (Environment.get_user_config_dir (),
            "latexila", "build_tools.xml");

        return File.new_for_path (path);
    }

    public static PostProcessorType? get_post_processor_type_from_name (string name)
    {
        for (int type = 0 ; type < PostProcessorType.N_POST_PROCESSORS ; type++)
        {
            if (_post_processor_names[type] == name)
                return (PostProcessorType) type;
        }

        return_val_if_reached (null);
    }

    public static string? get_post_processor_name_from_type (PostProcessorType type)
    {
        return_val_if_fail (type != PostProcessorType.N_POST_PROCESSORS, null);

        return _post_processor_names[type];
    }
}
