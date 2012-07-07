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
 */

using Gtk;
using Gee;

private class BuildToolDialog : Dialog
{
    private static BuildToolDialog _instance = null;

    private ErrorEntry _entry_label;
    private Entry _entry_desc;
    private Entry _entry_extensions;
    private ComboBox _combobox_icon;
    private ErrorEntry _entry_command;
    private Button _button_add;
    private TreeView _treeview_jobs;
    private Button _button_delete;
    private Button _button_up;
    private Button _button_down;

    private ListStore _jobs_store;

    private struct IconColumn
    {
        public string stock_id;
        public string label;
    }

    private const IconColumn[] _icons =
    {
        { Stock.EXECUTE, N_("Execute") },
        { "compile_dvi", "LaTeX → DVI" },
        { "compile_pdf", "LaTeX → PDF" },
        { "compile_ps", "LaTeX → PS" },
        { Stock.CONVERT, N_("Convert") },
        { Stock.FILE, N_("View File") },
        { "view_dvi", N_("View DVI") },
        { "view_pdf", N_("View PDF") },
        { "view_ps", N_("View PS") }
    };

    private enum JobColumn
    {
        COMMAND,
        POST_PROCESSOR,
        N_COLUMNS
    }

    private BuildToolDialog ()
    {
        add_button (Stock.CANCEL, ResponseType.CANCEL);
        add_button (Stock.OK, ResponseType.OK);
        title = _("Build Tool");
        destroy_with_parent = true;

        Grid label_grid = get_label_grid ();
        Grid desc_grid = get_desc_grid ();
        Grid extensions_grid = get_extensions_grid ();
        Grid icon_grid = get_icon_grid ();
        Grid jobs_grid = get_jobs_grid ();

        Grid main_grid = new Grid ();
        main_grid.set_row_spacing (5);
        main_grid.set_column_spacing (5);
        main_grid.attach (label_grid, 0, 0, 1, 1);
        main_grid.attach (desc_grid, 1, 0, 1, 1);
        main_grid.attach (extensions_grid, 0, 1, 1, 1);
        main_grid.attach (icon_grid, 1, 1, 1, 1);
        main_grid.attach (jobs_grid, 0, 2, 2, 1);

        Box content_area = get_content_area () as Box;
        content_area.pack_start (main_grid);
        content_area.show_all ();

        init_icon_treeview ();
        init_jobs_treeview ();
        init_actions ();
    }

    public static bool show_me (Window parent, int build_tool_num)
    {
        if (_instance == null)
        {
            _instance = new BuildToolDialog ();

            _instance.destroy.connect (() =>
            {
                if (_instance != null)
                    _instance = null;
            });
        }

        if (parent != _instance.get_transient_for ())
            _instance.set_transient_for (parent);

        _instance.present ();
        _instance.init (build_tool_num);
        return _instance.run_me (build_tool_num);
    }

    private Grid get_label_grid ()
    {
        Grid grid = new Grid ();
        grid.set_row_spacing (6);
        grid.border_width = 6;

        Label title = new Label (null);
        title.set_markup ("<b>" + _("Label") + "</b>");
        title.set_halign (Align.START);
        grid.attach (title, 0, 0, 1, 1);

        Label arrow = new Label ("→");
        arrow.set_tooltip_text (_("You can select this arrow and copy/paste it!"));
        arrow.set_halign (Align.CENTER);
        arrow.set_hexpand (true);
        arrow.set_selectable (true);
        grid.attach (arrow, 1, 0, 1, 1);
        grid.set_hexpand (false);

        _entry_label = new ErrorEntry ();
        _entry_label.set_margin_left (12);
        grid.attach (_entry_label, 0, 1, 2, 1);

        return grid;
    }

    private Grid get_desc_grid ()
    {
        _entry_desc = new Entry ();
        _entry_desc.hexpand = true;
        return Utils.get_dialog_component (_("Description"), _entry_desc);
    }

    private Grid get_extensions_grid ()
    {
        _entry_extensions = new Entry ();
        _entry_extensions.set_tooltip_text (
            _("File extensions for which the build tool can be executed.\nThe extensions are separated by spaces."));

        return Utils.get_dialog_component (_("Extensions"), _entry_extensions);
    }

    private Grid get_icon_grid ()
    {
        _combobox_icon = new ComboBox ();
        return Utils.get_dialog_component (_("Icon"), _combobox_icon);
    }

    private Grid get_jobs_grid ()
    {
        Label placeholders = new Label (_("Placeholders:"));

        Label placeholder_filename = new Label ("$filename");
        placeholder_filename.set_tooltip_text (_("The active document filename"));

        Label placeholder_shortname = new Label ("$shortname");
        placeholder_shortname.set_tooltip_text (
            _("The active document filename without its extension"));

        Label placeholder_view = new Label ("$view");
        placeholder_view.set_tooltip_text (
            _("The program for viewing documents.\nIts value can be changed in the preferences dialog."));

        _entry_command = new ErrorEntry ();
        _entry_command.hexpand = true;

        _button_add = new Button.from_stock (Stock.ADD);
        _button_add.set_tooltip_text (_("New command"));

        _treeview_jobs = new TreeView ();
        _treeview_jobs.hexpand = true;
        _treeview_jobs.vexpand = true;

        Widget scrolled_treeview = Utils.add_scrollbar (_treeview_jobs);
        scrolled_treeview.set_size_request (600, 110);

        _button_delete = new Button.from_stock (Stock.REMOVE);
        _button_up = new Button.from_stock (Stock.GO_UP);
        _button_down = new Button.from_stock (Stock.GO_DOWN);

        Grid placeholders_grid = new Grid ();
        placeholders_grid.set_orientation (Orientation.HORIZONTAL);
        placeholders_grid.set_column_spacing (10);
        placeholders_grid.add (placeholders);
        placeholders_grid.add (placeholder_filename);
        placeholders_grid.add (placeholder_shortname);
        placeholders_grid.add (placeholder_view);

        Grid cmd_grid = new Grid ();
        cmd_grid.set_orientation (Orientation.HORIZONTAL);
        cmd_grid.set_column_spacing (5);
        cmd_grid.add (_entry_command);
        cmd_grid.add (_button_add);

        Grid buttons_grid = new Grid ();
        buttons_grid.set_orientation (Orientation.HORIZONTAL);
        buttons_grid.set_column_spacing (5);
        buttons_grid.add (_button_delete);
        buttons_grid.add (_button_up);
        buttons_grid.add (_button_down);

        Grid jobs_grid = new Grid ();
        jobs_grid.set_orientation (Orientation.VERTICAL);
        jobs_grid.set_row_spacing (5);
        jobs_grid.add (placeholders_grid);
        jobs_grid.add (cmd_grid);
        jobs_grid.add (scrolled_treeview);
        jobs_grid.add (buttons_grid);

        return Utils.get_dialog_component (_("Jobs"), jobs_grid);
    }

    private void init_icon_treeview ()
    {
        ListStore icon_store = new ListStore (2, typeof (string), typeof (string));

        // fill icon store
        foreach (IconColumn icon in _icons)
        {
            TreeIter iter;
            icon_store.append (out iter);
            icon_store.set (iter, 0, icon.stock_id, 1, _(icon.label), -1);
        }

        // init combobox
        _combobox_icon.set_model (icon_store);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        _combobox_icon.pack_start (pixbuf_renderer, false);
        _combobox_icon.set_attributes (pixbuf_renderer, "stock-id", 0, null);

        CellRendererText text_renderer = new CellRendererText ();
        _combobox_icon.pack_start (text_renderer, true);
        _combobox_icon.set_attributes (text_renderer, "text", 1, null);
    }

    private void init_jobs_treeview ()
    {
        _jobs_store = new ListStore (JobColumn.N_COLUMNS,
            typeof (string),    // command
            typeof (string)     // post processor
        );

        _treeview_jobs.set_model (_jobs_store);

        /* post processor list store */

        ListStore post_processor_store = new ListStore (1, typeof (string));

        for (int type = 0 ; type < PostProcessorType.N_POST_PROCESSORS ; type++)
        {
            TreeIter iterpp;
            post_processor_store.append (out iterpp);
            post_processor_store.set (iterpp,
                0, BuildTools.get_post_processor_name_from_type (
                    (PostProcessorType) type),
                -1);
        }

        /* cell renderers */

        CellRendererText text_renderer = new CellRendererText ();
        text_renderer.editable = true;

        TreeViewColumn column = new TreeViewColumn.with_attributes (_("Commands"),
            text_renderer, "text", JobColumn.COMMAND);
        column.set_resizable (true);
        _treeview_jobs.append_column (column);

        CellRendererCombo combo_renderer = new CellRendererCombo ();
        combo_renderer.editable = true;
        combo_renderer.model = post_processor_store;
        combo_renderer.text_column = 0;
        combo_renderer.has_entry = false;
        _treeview_jobs.insert_column_with_attributes (-1, _("Post Processor"),
            combo_renderer, "text", JobColumn.POST_PROCESSOR);

        /* callbacks */

        text_renderer.edited.connect ((path_string, new_text) =>
        {
            TreeIter iter;
            _jobs_store.get_iter_from_string (out iter, path_string);
            _jobs_store.set (iter, JobColumn.COMMAND, new_text);
        });

        combo_renderer.edited.connect ((path_string, new_text) =>
        {
            TreeIter iter;
            _jobs_store.get_iter_from_string (out iter, path_string);
            _jobs_store.set (iter, JobColumn.POST_PROCESSOR, new_text);
        });
    }

    private void init_actions ()
    {
        _button_add.clicked.connect (on_command_add);
        _entry_command.activate.connect (on_command_add);

        _button_delete.clicked.connect (() =>
        {
            TreeIter iter;
            int i = Utils.get_selected_row (_treeview_jobs, out iter);
            if (i != -1)
                _jobs_store.remove (iter);
        });

        _button_up.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (_treeview_jobs, out iter1);
            if (i != -1 && i > 0)
            {
                iter2 = iter1;
                if (Utils.tree_model_iter_prev (_jobs_store, ref iter2))
                    _jobs_store.swap (iter1, iter2);
            }
        });

        _button_down.clicked.connect (() =>
        {
            TreeIter iter1, iter2;
            int i = Utils.get_selected_row (_treeview_jobs, out iter1);
            if (i != -1)
            {
                iter2 = iter1;
                if (_jobs_store.iter_next (ref iter2))
                    _jobs_store.swap (iter1, iter2);
            }
        });
    }

    private void on_command_add ()
    {
        if (_entry_command.text.strip () == "")
            return;

        TreeIter iter;
        _jobs_store.append (out iter);
        _jobs_store.set (iter,
            JobColumn.COMMAND, _entry_command.text,
            JobColumn.POST_PROCESSOR, BuildTools.get_post_processor_name_from_type (
                PostProcessorType.NO_OUTPUT)
        );
        _entry_command.text = "";
    }

    private void init (int build_tool_num)
    {
        _entry_command.text = "";
        _jobs_store.clear ();
        _entry_label.error = false;
        _entry_command.error = false;

        if (build_tool_num == -1)
            _instance.init_new_build_tool ();
        else
            _instance.init_with_build_tool (BuildTools.get_default ()[build_tool_num]);

        _treeview_jobs.columns_autosize ();
    }

    private void init_new_build_tool ()
    {
        _entry_label.text = "";
        _entry_desc.text = "";
        _entry_extensions.text = ".tex";
        _combobox_icon.set_active (0);
    }

    private void init_with_build_tool (BuildTool tool)
    {
        _entry_label.text = tool.label;
        _entry_desc.text = tool.description;
        _entry_extensions.text = tool.extensions;

        // set icon
        _combobox_icon.set_active (0);
        for (int i = 0 ; i < _icons.length ; i++)
        {
            if (_icons[i].stock_id == tool.icon)
            {
                _combobox_icon.set_active (i);
                break;
            }
        }

        // jobs
        _jobs_store.clear ();
        foreach (BuildJob job in tool.jobs)
        {
            TreeIter iter;
            _jobs_store.append (out iter);
            _jobs_store.set (iter,
                JobColumn.COMMAND, job.command,
                JobColumn.POST_PROCESSOR, BuildTools.get_post_processor_name_from_type (
                    job.post_processor)
            );
        }
    }

    // Returns true if the build tool is correctly updated or created.
    private bool run_me (int build_tool_num)
    {
        while (run () == ResponseType.OK)
        {
            /* check if the form is correctly filled */

            // no label
            _entry_label.error = _entry_label.text.strip () == "";

            // no job
            TreeIter iter;
            _entry_command.error = ! _jobs_store.get_iter_first (out iter);

            if (_entry_label.error || _entry_command.error)
                continue;

            /* generate a new build tool */

            BuildTool tool = BuildTool ();
            tool.label = _entry_label.text.strip ();
            tool.description =
                _entry_desc.text.strip () == "" ? tool.label : _entry_desc.text.strip ();
            tool.extensions = _entry_extensions.text.strip ();
            tool.jobs = new Gee.ArrayList<BuildJob?> ();

            _combobox_icon.get_active_iter (out iter);
            TreeModel model = _combobox_icon.get_model ();
            model.get (iter, 0, out tool.icon, -1);

            model = _treeview_jobs.get_model ();
            bool valid = _jobs_store.get_iter_first (out iter);
            while (valid)
            {
                BuildJob job = BuildJob ();

                string command;
                string post_processor_name;
                model.get (iter,
                    JobColumn.COMMAND, out command,
                    JobColumn.POST_PROCESSOR, out post_processor_name
                );

                job.command = command.strip ();
                job.post_processor = BuildTools.get_post_processor_type_from_name (
                    post_processor_name);
                tool.jobs.add (job);

                valid = _jobs_store.iter_next (ref iter);
            }

            /* update build tools settings */
            if (build_tool_num == -1)
            {
                tool.show = true;
                BuildTools.get_default ().add (tool);
            }
            else
                BuildTools.get_default ().update (build_tool_num, tool, true);

            hide ();
            return true;
        }

        hide ();
        return false;
    }
}
