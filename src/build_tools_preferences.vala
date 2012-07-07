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

// The preferences of the build tools, which is part of the preferences dialog, in the
// LaTeX tab.
// For the configuration of a single build tool, see build_tool_dialog.vala.

using Gtk;

public class BuildToolsPreferences : Grid
{
    private enum BuildToolColumn
    {
        ENABLE,
        PIXBUF,
        LABEL,
        DESCRIPTION,
        N_COLUMNS
    }

    private ListStore _list_store;
    private TreeView _tree_view;

    public BuildToolsPreferences ()
    {
        set_orientation (Orientation.VERTICAL);

        init_list_store ();
        init_tree_view ();

        _tree_view.expand = true;
        ScrolledWindow scrolled_window =
            Utils.add_scrollbar (_tree_view) as ScrolledWindow;
        scrolled_window.set_shadow_type (ShadowType.IN);
        scrolled_window.set_size_request (350, 200);

        StyleContext context = scrolled_window.get_style_context ();
        context.set_junction_sides (JunctionSides.BOTTOM);

        Toolbar toolbar = new Toolbar ();
        toolbar.insert (get_properties_button (), -1);
        toolbar.insert (get_copy_button (), -1);
        toolbar.insert (get_add_button (), -1);
        toolbar.insert (get_remove_button (), -1);
        toolbar.insert (get_up_button (), -1);
        toolbar.insert (get_down_button (), -1);
        toolbar.insert (get_reset_button (), -1);

        toolbar.set_icon_size (IconSize.MENU);
        toolbar.set_style (ToolbarStyle.ICONS);

        context = toolbar.get_style_context ();
        context.add_class (STYLE_CLASS_INLINE_TOOLBAR);
        context.set_junction_sides (JunctionSides.TOP);

        add (scrolled_window);
        add (toolbar);
        show_all ();
    }

    private void init_list_store ()
    {
        _list_store = new ListStore (BuildToolColumn.N_COLUMNS,
            typeof (bool),   // enable
            typeof (string), // pixbuf (stock-id)
            typeof (string), // label
            typeof (string)  // description
        );

        update_list_store ();
    }

    private void init_tree_view ()
    {
        _tree_view = new TreeView.with_model (_list_store);
        _tree_view.set_rules_hint (true);

        TreeViewColumn enable_column = new TreeViewColumn ();
        enable_column.set_title (_("Enable"));
        _tree_view.append_column (enable_column);

        CellRendererToggle toggle_renderer = new CellRendererToggle ();
        enable_column.pack_start (toggle_renderer, false);
        enable_column.set_attributes (toggle_renderer,
            "active", BuildToolColumn.ENABLE);

        TreeViewColumn label_column = new TreeViewColumn ();
        label_column.set_title (_("Label"));
        _tree_view.append_column (label_column);

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        label_column.pack_start (pixbuf_renderer, false);
        label_column.set_attributes (pixbuf_renderer,
            "stock-id", BuildToolColumn.PIXBUF);

        CellRendererText text_renderer = new CellRendererText ();
        label_column.pack_start (text_renderer, true);
        label_column.set_attributes (text_renderer,
          "text", BuildToolColumn.LABEL);

        _tree_view.set_tooltip_column (BuildToolColumn.DESCRIPTION);

        TreeSelection select = _tree_view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);

        /* Enable and disable a build tool */
        toggle_renderer.toggled.connect ((path_string) =>
        {
            TreeIter iter;
            _list_store.get_iter_from_string (out iter, path_string);

            bool enable;
            TreeModel model = _list_store as TreeModel;
            model.get (iter, BuildToolColumn.ENABLE, out enable);

            enable = ! enable;
            _list_store.set (iter, BuildToolColumn.ENABLE, enable);

            int num = int.parse (path_string);
            BuildTools build_tools = BuildTools.get_default ();
            BuildTool build_tool = build_tools[num];
            build_tool.show = enable;

            build_tools.update (num, build_tool);
        });

        /* Double-click */
        _tree_view.row_activated.connect ((path, column) =>
        {
            if (column == label_column)
            {
                int num = path.get_indices ()[0];
                run_build_tool_dialog (num);
            }
        });
    }

    private ToolButton get_properties_button ()
    {
        ToolButton properties_button = new ToolButton (null, null);
        properties_button.set_icon_name ("document-properties-symbolic");
        properties_button.set_tooltip_text ("Edit the properties");

        set_sensitivity_on_selection (properties_button);

        properties_button.clicked.connect (() =>
        {
            int num = Utils.get_selected_row (_tree_view);
            if (0 <= num)
                run_build_tool_dialog (num);
        });

        return properties_button;
    }

    private ToolButton get_copy_button ()
    {
        ToolButton copy_button = new ToolButton (null, null);
        copy_button.set_icon_name ("edit-copy-symbolic");
        copy_button.set_tooltip_text ("Create a copy");

        set_sensitivity_on_selection (copy_button);

        copy_button.clicked.connect (() =>
        {
            int selected_row = Utils.get_selected_row (_tree_view);
            if (selected_row < 0)
                return;

            BuildTools build_tools = BuildTools.get_default ();
            BuildTool? tool = build_tools[selected_row];
            return_if_fail (tool != null);

            tool.show = false;
            tool.label = _("%s [copy]").printf (tool.label);
            build_tools.insert (selected_row + 1, tool);

            update_list_store ();
        });

        return copy_button;
    }

    private ToolButton get_add_button ()
    {
        ToolButton add_button = new ToolButton (null, null);
        add_button.set_icon_name ("list-add-symbolic");
        add_button.set_tooltip_text (_("Add..."));

        add_button.clicked.connect (() =>
        {
            run_build_tool_dialog (-1);
        });

        return add_button;
    }

    private ToolButton get_remove_button ()
    {
        ToolButton remove_button = new ToolButton (null, null);
        remove_button.set_icon_name ("list-remove-symbolic");
        remove_button.set_tooltip_text (_("Remove"));

        set_sensitivity_on_selection (remove_button);

        remove_button.clicked.connect (() =>
        {
            TreeIter iter;
            int selected_row = Utils.get_selected_row (_tree_view, out iter);
            if (selected_row == -1)
                return;

            string label;
            TreeModel model = _list_store as TreeModel;
            model.get (iter, BuildToolColumn.LABEL, out label);

            unowned Gtk.Window? window = Utils.get_toplevel_window (this);
            return_if_fail (window != null);

            Dialog dialog = new MessageDialog (window, DialogFlags.DESTROY_WITH_PARENT,
                MessageType.QUESTION, ButtonsType.NONE,
                _("Do you really want to delete the build tool \"%s\"?"),
                label);

            dialog.add_buttons (Stock.CANCEL, ResponseType.CANCEL,
                Stock.DELETE, ResponseType.YES);

            if (dialog.run () == ResponseType.YES)
            {
                _list_store.remove (iter);
                BuildTools.get_default ().delete (selected_row);
            }

            dialog.destroy ();
        });

        return remove_button;
    }

    private ToolButton get_up_button ()
    {
        ToolButton up_button = new ToolButton (null, null);
        up_button.set_icon_name ("go-up-symbolic");
        up_button.set_tooltip_text (_("Move up"));

        /* Sensitivity */

        up_button.set_sensitive (false);

        unowned TreeSelection select = _tree_view.get_selection ();
        select.changed.connect (() =>
        {
            List<TreePath> selected_rows = select.get_selected_rows (null);

            if (selected_rows.length () == 0)
            {
                up_button.set_sensitive (false);
                return;
            }

            TreePath path_selected = selected_rows.nth_data (0);
            int row_num = path_selected.get_indices ()[0];

            up_button.set_sensitive (row_num > 0);
        });

        /* Behavior */

        up_button.clicked.connect (() =>
        {
            TreeIter iter_selected;

            int selected_row = Utils.get_selected_row (_tree_view,
                out iter_selected);

            if (selected_row > 0)
            {
                TreeIter iter_up = iter_selected;
                if (Utils.tree_model_iter_prev (_list_store, ref iter_up))
                {
                    _list_store.swap (iter_selected, iter_up);
                    BuildTools.get_default ().move_up (selected_row);

                    // Force the 'changed' signal on the selection to be emitted
                    select.changed ();
                }
            }
        });

        return up_button;
    }

    private ToolButton get_down_button ()
    {
        ToolButton down_button = new ToolButton (null, null);
        down_button.set_icon_name ("go-down-symbolic");
        down_button.set_tooltip_text (_("Move down"));

        /* Sensitivity */

        down_button.set_sensitive (false);

        unowned TreeSelection select = _tree_view.get_selection ();
        select.changed.connect (() =>
        {
            List<TreePath> selected_rows = select.get_selected_rows (null);

            if (selected_rows.length () == 0)
            {
                down_button.set_sensitive (false);
                return;
            }

            TreePath path_selected = selected_rows.nth_data (0);
            int row_num = path_selected.get_indices ()[0];

            TreeModel model = _list_store as TreeModel;
            int nb_rows = model.iter_n_children (null);

            down_button.set_sensitive (row_num < nb_rows - 1);
        });

        /* Behavior */

        down_button.clicked.connect (() =>
        {
            TreeIter iter_selected;

            int selected_row = Utils.get_selected_row (_tree_view,
                out iter_selected);

            if (selected_row >= 0)
            {
                TreeIter iter_down = iter_selected;
                if (_list_store.iter_next (ref iter_down))
                {
                    _list_store.swap (iter_selected, iter_down);
                    BuildTools.get_default ().move_down (selected_row);

                    // Force the 'changed' signal on the selection to be emitted
                    select.changed ();
                }
            }
        });

        return down_button;
    }

    private ToolButton get_reset_button ()
    {
        ToolButton reset_button = new ToolButton (null, null);
        // TODO use the clear symbolic icon when it is available
        reset_button.set_icon_name ("edit-delete-symbolic");
        reset_button.set_tooltip_text (_("Reset all the build tools"));

        reset_button.clicked.connect (() =>
        {
            unowned Gtk.Window? window = Utils.get_toplevel_window (this);
            return_if_fail (window != null);

            Dialog dialog = Utils.get_reset_all_confirm_dialog (window,
                _("Do you really want to reset all build tools?"));

            if (dialog.run () == ResponseType.YES)
            {
                BuildTools.get_default ().reset_all ();
                update_list_store ();
            }

            dialog.destroy ();
        });

        return reset_button;
    }

    private void update_list_store ()
    {
        _list_store.clear ();

        foreach (BuildTool tool in BuildTools.get_default ())
        {
            TreeIter iter;
            _list_store.append (out iter);
            _list_store.set (iter,
                BuildToolColumn.ENABLE, tool.show,
                BuildToolColumn.PIXBUF, tool.icon,
                BuildToolColumn.LABEL, tool.label,
                BuildToolColumn.DESCRIPTION, Markup.escape_text (tool.description)
            );
        }
    }

    private void run_build_tool_dialog (int num)
    {
        unowned Gtk.Window? window = Utils.get_toplevel_window (this);
        return_if_fail (window != null);

        bool accepted = BuildToolDialog.show_me (window.get_transient_for (), num);

        if (accepted)
            update_list_store ();
    }

    // Set 'widget' as sensitive when there is a selection in the TreeView.
    // If no elements are selected (this is the case by default),
    // the widget is insensitive.
    private void set_sensitivity_on_selection (Widget widget)
    {
        widget.set_sensitive (false);

        unowned TreeSelection select = _tree_view.get_selection ();
        select.changed.connect (() =>
        {
            bool row_selected = select.count_selected_rows () > 0;
            widget.set_sensitive (row_selected);
        });
    }
}
