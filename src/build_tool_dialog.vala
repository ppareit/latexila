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

// The configuration of a single build tool.

using Gtk;

private class BuildToolDialog : Dialog
{
    private enum IconColumn
    {
        STOCK_ID,
        LABEL,
        N_COLUMNS
    }

    private enum JobColumn
    {
        COMMAND,
        POST_PROCESSOR,
        N_COLUMNS
    }

    private static BuildToolDialog _instance = null;

    private ErrorEntry _entry_label;
    private Entry _entry_desc;
    private Entry _entry_extensions;

    private ListStore _icons_store;
    private ComboBox _icons_combobox;

    private ListStore _jobs_store;
    private TreeView _jobs_view;

    private BuildToolDialog ()
    {
        add_button (Stock.CANCEL, ResponseType.CANCEL);
        add_button (Stock.OK, ResponseType.OK);
        title = _("Build Tool");
        destroy_with_parent = true;

        init_text_entries ();
        init_icons_store ();
        init_icons_combobox ();
        init_jobs ();

        Box content_area = get_content_area () as Box;
        content_area.pack_start (get_main_grid ());
        content_area.show_all ();
    }

    public static void show_me (Gtk.Window parent)
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

        _instance.set_transient_for (parent);
        _instance.present ();
    }

    // Returns true if the build tool is edited.
    // Returns false if the user has clicked on cancel.
    public static bool edit_build_tool (int build_tool_num)
    {
        return false;
    }

    // Returns true if the build tool is created.
    // Returns false if the user has clicked on cancel.
    public static bool create_build_tool ()
    {
        return false;
    }

    /*************************************************************************/
    // Init main widgets

    private void init_text_entries ()
    {
        _entry_label = new ErrorEntry ();
        _entry_desc = new Entry ();
        _entry_extensions = new Entry ();
    }

    private void init_icons_store ()
    {
        _icons_store = new ListStore (IconColumn.N_COLUMNS,
            typeof (string), // icon stock-id
            typeof (string)  // label
        );

        add_icon (Stock.EXECUTE, _("Execute"));
        add_icon ("compile_dvi", "LaTeX → DVI");
        add_icon ("compile_pdf", "LaTeX → PDF");
        add_icon ("compile_ps", "LaTeX → PS");
        add_icon (Stock.CONVERT, _("Convert"));
        add_icon (Stock.FILE, _("View File"));
        add_icon ("view_dvi", _("View DVI"));
        add_icon ("view_pdf", _("View PDF"));
        add_icon ("view_ps", _("View PS"));
    }

    private void add_icon (string stock_id, string label)
    {
        TreeIter iter;
        _icons_store.append (out iter);
        _icons_store.set (iter,
            IconColumn.STOCK_ID, stock_id,
            IconColumn.LABEL, label
        );
    }

    private void init_icons_combobox ()
    {
        _icons_combobox = new ComboBox.with_model (_icons_store);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        _icons_combobox.pack_start (pixbuf_renderer, false);
        _icons_combobox.set_attributes (pixbuf_renderer,
            "stock-id", IconColumn.STOCK_ID);

        CellRendererText text_renderer = new CellRendererText ();
        _icons_combobox.pack_start (text_renderer, true);
        _icons_combobox.set_attributes (text_renderer,
            "text", IconColumn.LABEL);
    }

    private void init_jobs ()
    {
        _jobs_store = new ListStore (JobColumn.N_COLUMNS,
            typeof (string), // command
            typeof (string)  // post processor
        );

        _jobs_view = new TreeView.with_model (_jobs_store);

        /* Post processors list store */

        ListStore post_processor_store = new ListStore (1,
            typeof (string) // the name of the post processor
        );

        for (int type = 0 ; type < PostProcessorType.N_POST_PROCESSORS ; type++)
        {
            string name = BuildTools.get_post_processor_name_from_type (
                (PostProcessorType) type);

            TreeIter iter;
            post_processor_store.append (out iter);
            post_processor_store.set (iter, 0, name);
        }

        /* Cell renderers */

        CellRendererText text_renderer = new CellRendererText ();
        text_renderer.editable = true;

        TreeViewColumn column = new TreeViewColumn.with_attributes (_("Commands"),
            text_renderer, "text", JobColumn.COMMAND);
        column.set_resizable (true);
        _jobs_view.append_column (column);

        CellRendererCombo combo_renderer = new CellRendererCombo ();
        combo_renderer.editable = true;
        combo_renderer.model = post_processor_store;
        combo_renderer.text_column = 0;
        combo_renderer.has_entry = false;
        _jobs_view.insert_column_with_attributes (-1, _("Post Processor"),
            combo_renderer, "text", JobColumn.POST_PROCESSOR);

        /* Behavior */

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

    /*************************************************************************/
    // Jobs: mini-toolbar buttons (add, remove, up, down)

    private ToolButton get_add_button ()
    {
        ToolButton add_button = new ToolButton (null, null);
        add_button.set_icon_name ("list-add-symbolic");
        add_button.set_tooltip_text (_("Add..."));

        return add_button;
    }

    private ToolButton get_remove_button ()
    {
        ToolButton remove_button = new ToolButton (null, null);
        remove_button.set_icon_name ("list-remove-symbolic");
        remove_button.set_tooltip_text (_("Remove"));

        return remove_button;
    }

    private ToolButton get_up_button ()
    {
        ToolButton up_button = new ToolButton (null, null);
        up_button.set_icon_name ("go-up-symbolic");
        up_button.set_tooltip_text (_("Move up"));

        return up_button;
    }

    private ToolButton get_down_button ()
    {
        ToolButton down_button = new ToolButton (null, null);
        down_button.set_icon_name ("go-down-symbolic");
        down_button.set_tooltip_text (_("Move down"));

        return down_button;
    }

    /*************************************************************************/
    // Packing widgets, add section titles, tooltips, etc.

    private Grid get_main_grid ()
    {
        Grid main_grid = new Grid ();
        main_grid.set_row_spacing (5);
        main_grid.set_column_spacing (5);

        main_grid.attach (get_label_grid (), 0, 0, 1, 1);
        main_grid.attach (get_desc_grid (), 1, 0, 1, 1);
        main_grid.attach (get_extensions_grid (), 0, 1, 1, 1);
        main_grid.attach (get_icons_grid (), 1, 1, 1, 1);
        main_grid.attach (get_jobs_grid (), 0, 2, 2, 1);

        return main_grid;
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

        _entry_label.set_margin_left (12);
        grid.attach (_entry_label, 0, 1, 2, 1);

        return grid;
    }

    private Grid get_desc_grid ()
    {
        _entry_desc.hexpand = true;
        return Utils.get_dialog_component (_("Description"), _entry_desc);
    }

    private Grid get_extensions_grid ()
    {
        _entry_extensions.set_tooltip_text (
            _("File extensions for which the build tool can be executed.") + "\n" +
            _("The extensions are separated by spaces."));

        return Utils.get_dialog_component (_("Extensions"), _entry_extensions);
    }

    private Grid get_icons_grid ()
    {
        return Utils.get_dialog_component (_("Icon"), _icons_combobox);
    }

    private Grid get_jobs_grid ()
    {
        /* Placeholders */

        Label placeholders = new Label (_("Placeholders:"));

        Label placeholder_filename = new Label ("$filename");
        placeholder_filename.set_tooltip_text (_("The active document filename"));

        Label placeholder_shortname = new Label ("$shortname");
        placeholder_shortname.set_tooltip_text (
            _("The active document filename without its extension"));

        Label placeholder_view = new Label ("$view");
        placeholder_view.set_tooltip_text (
            _("The program for viewing documents.") + "\n" +
            _("Its value can be changed in the preferences dialog."));

        Grid placeholders_grid = new Grid ();
        placeholders_grid.set_orientation (Orientation.HORIZONTAL);
        placeholders_grid.set_column_spacing (10);
        placeholders_grid.add (placeholders);
        placeholders_grid.add (placeholder_filename);
        placeholders_grid.add (placeholder_shortname);
        placeholders_grid.add (placeholder_view);

        /* Jobs tree view */

        _jobs_view.expand = true;

        ScrolledWindow scrolled_window =
            Utils.add_scrollbar (_jobs_view) as ScrolledWindow;
        scrolled_window.set_size_request (600, 110);
        scrolled_window.set_shadow_type (ShadowType.IN);

        StyleContext context = scrolled_window.get_style_context ();
        context.set_junction_sides (JunctionSides.BOTTOM);

        /* Toolbar */

        Toolbar toolbar = new Toolbar ();
        toolbar.insert (get_add_button (), -1);
        toolbar.insert (get_remove_button (), -1);
        toolbar.insert (get_up_button (), -1);
        toolbar.insert (get_down_button (), -1);

        toolbar.set_icon_size (IconSize.MENU);
        toolbar.set_style (ToolbarStyle.ICONS);

        context = toolbar.get_style_context ();
        context.add_class (STYLE_CLASS_INLINE_TOOLBAR);
        context.set_junction_sides (JunctionSides.TOP);

        /* Pack */

        Grid jobs_grid = new Grid ();
        jobs_grid.set_orientation (Orientation.VERTICAL);
        placeholders_grid.set_margin_bottom (8);
        jobs_grid.add (placeholders_grid);
        jobs_grid.add (scrolled_window);
        jobs_grid.add (toolbar);

        return Utils.get_dialog_component (_("Jobs"), jobs_grid);
    }
}
