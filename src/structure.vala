/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2011 Sébastien Wilmet
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

public enum StructType
{
    PART = 0,
    CHAPTER,
    SECTION,
    SUBSECTION,
    SUBSUBSECTION,
    PARAGRAPH,
    SUBPARAGRAPH,
    LABEL,
    INCLUDE,
    TABLE,
    FIGURE,
    IMAGE,
    TODO,
    FIXME,
    N_TYPES
}

public class Structure : VBox
{
    private unowned MainWindow _main_window;
    private Menu _popup_menu;
    private Gtk.Action _action_all_menu;
    private Gtk.Action _action_cut;
    private Gtk.Action _action_copy;
    private Gtk.Action _action_delete;
    private Gtk.Action _action_select;
    private Gtk.Action _action_comment;
    private Gtk.Action _action_shift_left;
    private Gtk.Action _action_shift_right;

    private ToggleButton[] _simple_list_buttons = {};
    private VPaned _vpaned;

    private TreeView _tree_view;
    private StructureModel? _model = null;

    private TreeView _list_view;
    private Widget _list_view_sw;
    private ListStore _list_store;
    // FIXME a simple list can contain several types
    private StructType _current_list_type;
    private bool _list_is_hidden = true;

    private bool _first_select = true;

    private static string[] _icons = null;
    private static string[] _names = null;

    public Structure (MainWindow main_window, UIManager ui_manager)
    {
        GLib.Object (spacing: 3);
        _main_window = main_window;

        _popup_menu = (Menu) ui_manager.get_widget ("/StructurePopup");
        _action_all_menu = ui_manager.get_action ("/MainMenu/Structure");
        _action_cut = ui_manager.get_action ("/StructurePopup/StructureCut");
        _action_copy = ui_manager.get_action ("/StructurePopup/StructureCopy");
        _action_delete = ui_manager.get_action ("/StructurePopup/StructureDelete");
        _action_select = ui_manager.get_action ("/StructurePopup/StructureSelect");
        _action_comment = ui_manager.get_action ("/StructurePopup/StructureComment");
        _action_shift_left = ui_manager.get_action ("/StructurePopup/StructureShiftLeft");
        _action_shift_right =
            ui_manager.get_action ("/StructurePopup/StructureShiftRight");

        init_toolbar ();
        init_vpaned ();
        init_list_view ();
        init_tree_view ();
        show_all ();
        _list_view_sw.hide ();

        show.connect (connect_parsing);
        hide.connect (() =>
        {
            disconnect_parsing ();
            _action_all_menu.set_sensitive (false);
        });
    }

    private void init_toolbar ()
    {
        HBox hbox = new HBox (true, 0);
        pack_start (hbox, false, false);

        // refresh button
        Button refresh_button = Utils.get_toolbar_button (Stock.REFRESH);
        refresh_button.tooltip_text = _("Refresh");
        hbox.pack_start (refresh_button);

        refresh_button.clicked.connect (() =>
        {
            show_document (_main_window.active_document, true);
        });

        // expand all button
        Button expand_button = Utils.get_toolbar_button (Stock.ZOOM_IN);
        expand_button.tooltip_text = _("Expand All");
        hbox.pack_start (expand_button);

        expand_button.clicked.connect (() => _tree_view.expand_all ());

        // collapse all button
        Button collapse_button = Utils.get_toolbar_button (Stock.ZOOM_OUT);
        collapse_button.tooltip_text = _("Collapse All");
        hbox.pack_start (collapse_button);

        collapse_button.clicked.connect (() => _tree_view.collapse_all ());

        // simple list buttons
        ToggleButton toggle_button = create_simple_list_button ({ StructType.LABEL },
            _("Show labels"));
        hbox.pack_start (toggle_button);

        toggle_button = create_simple_list_button ({ StructType.INCLUDE },
            _("Show files included"));
        hbox.pack_start (toggle_button);

        toggle_button = create_simple_list_button ({ StructType.TABLE },
            _("Show tables"));
        hbox.pack_start (toggle_button);

        toggle_button = create_simple_list_button (
            { StructType.FIGURE, StructType.IMAGE }, _("Show figures and images"));
        hbox.pack_start (toggle_button);

        toggle_button = create_simple_list_button ({ StructType.TODO, StructType.FIXME },
            _("Show TODOs and FIXMEs"));
        hbox.pack_start (toggle_button);
    }

    // Only one button can be activated at the same time.
    // If no button is selected, the simple list is hidden.
    // If a button is selected, the simple list contains only items specified by 'types'.
    private ToggleButton? create_simple_list_button (StructType[] types, string tooltip)
    {
        return_val_if_fail (types.length > 0, null);

        StructType cur_type = types[0];
        ToggleButton button =
            Utils.get_toolbar_toggle_button (get_icon_from_type (cur_type));

        button.tooltip_text = tooltip;

        _simple_list_buttons += button;

        button.clicked.connect (() =>
        {
            if (! button.get_active ())
            {
                if (! _list_is_hidden && _current_list_type == cur_type)
                {
                    _list_is_hidden = true;
                    _list_view_sw.hide ();
                }
                return;
            }

            _current_list_type = cur_type;
            _list_is_hidden = false;
            _list_view_sw.show_all ();
            populate_simple_list ();

            // deselect the other buttons
            foreach (ToggleButton simple_list_button in _simple_list_buttons)
            {
                if (simple_list_button == button)
                    continue;

                simple_list_button.set_active (false);
            }
        });

        return button;
    }

    private void populate_simple_list ()
    {
        _list_store.clear ();

        if (_model == null || _list_is_hidden)
            return;

        _model.populate_list (_list_store, _current_list_type);

        /* select an item if needed */

        TreeSelection tree_select = _tree_view.get_selection ();
        List<TreePath> selected_rows = tree_select.get_selected_rows (null);

        if (selected_rows.length () != 1)
        {
            //stdout.printf ("length: %u\n", selected_rows.length ());
            return;
        }

        TreePath tree_path = selected_rows.nth_data (0);
        TreeIter tree_iter;
        if (! _model.get_iter (out tree_iter, tree_path))
            return_if_reached ();

        select_simple_list_item (tree_iter);
    }

    private void init_vpaned ()
    {
        _vpaned = new VPaned ();
        pack_start (_vpaned);

        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");
        _vpaned.set_position (settings.get_int ("structure-paned-position"));
    }

    public void save_state ()
    {
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");
        settings.set_int ("structure-paned-position", _vpaned.get_position ());
    }

    private void init_list_view ()
    {
        _list_view = get_new_tree_view (StructListColumn.PIXBUF, StructListColumn.TEXT,
            StructListColumn.TOOLTIP);

        _list_store = new ListStore (StructListColumn.N_COLUMNS,
            typeof (string),    // pixbuf
            typeof (string),    // text
            typeof (string)     // tooltip
        );

        _list_view.set_model (_list_store);

        // selection
        TreeSelection list_select = _list_view.get_selection ();
        list_select.set_select_function ((select, model, path, path_currently_selected) =>
        {
            // always allow deselect
            if (path_currently_selected)
                return true;

            return select_list_row (path);
        });

        // double-click
        _list_view.row_activated.connect ((path) => select_list_row (path));

        // with a scrollbar
        _list_view_sw = Utils.add_scrollbar (_list_view);
        _vpaned.add1 (_list_view_sw);
    }

    private void init_tree_view ()
    {
        _tree_view = get_new_tree_view (StructColumn.PIXBUF, StructColumn.TEXT,
            StructColumn.TOOLTIP);

        // selection
        TreeSelection tree_select = _tree_view.get_selection ();
        tree_select.set_select_function ((select, model, path, path_currently_selected) =>
        {
            // always allow deselect
            if (path_currently_selected)
                return true;

            return select_tree_row (path);
        });

        // double-click
        _tree_view.row_activated.connect ((path) => select_tree_row (path));

        // right click
        _popup_menu.attach_to_widget (_tree_view, null);

        _tree_view.button_press_event.connect ((event) =>
        {
            // right click
            if (event.button == 3 && event.type == Gdk.EventType.BUTTON_PRESS)
                show_popup_menu (event);

            // propagate the event further so the row is also selected
            return false;
        });

        _tree_view.popup_menu.connect (() =>
        {
            show_popup_menu (null);
            return true;
        });

        // with a scrollbar
        Widget sw = Utils.add_scrollbar (_tree_view);
        _vpaned.add2 (sw);
    }

    private TreeView get_new_tree_view (int pixbuf_col, int text_col, int tooltip_col)
    {
        TreeView tree_view = new TreeView ();
        tree_view.headers_visible = false;

        TreeViewColumn column = new TreeViewColumn ();
        tree_view.append_column (column);

        // icon
        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        column.pack_start (pixbuf_renderer, false);
        column.set_attributes (pixbuf_renderer, "stock-id", pixbuf_col, null);

        // name
        CellRendererText text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", text_col, null);

        // tooltip
        tree_view.set_tooltip_column (tooltip_col);

        // selection
        TreeSelection select = tree_view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);

        return tree_view;
    }

    private bool select_list_row (TreePath list_path)
    {
        if (! _first_select)
        {
            _first_select = true;
            return true;
        }

        return_val_if_fail (_model != null, false);

        /* select the corresponding item in the tree */
        TreeSelection tree_select = _tree_view.get_selection ();
        tree_select.unselect_all ();

        int row_num = list_path.get_indices ()[0];

        TreePath? tree_path =
            _model.get_tree_path_from_list_num (_current_list_type, row_num);

        return_val_if_fail (tree_path != null, false);

        _tree_view.expand_to_path (tree_path);

        _first_select = false;
        tree_select.select_path (tree_path);

        _tree_view.scroll_to_cell (tree_path, null, true, (float) 0.5, 0);

        // the row is selected
        return true;
    }

    private bool select_tree_row (TreePath tree_path)
    {
        // Reset _first_select and keep a copy, so if an error occurs, it's ok for the
        // next select.
        bool first_select = _first_select;
        _first_select = true;

        TreeIter tree_iter;
        if (! _model.get_iter (out tree_iter, tree_path))
            return_val_if_reached (false);

        TextMark mark;
        StructType type;
        _model.get (tree_iter,
            StructColumn.MARK, out mark,
            StructColumn.TYPE, out type,
            -1);

        /* go to the location in the document */
        TextBuffer doc = mark.get_buffer ();
        return_val_if_fail (doc == _main_window.active_document, false);

        // place the cursor so the line is highlighted (by default)
        TextIter text_iter;
        doc.get_iter_at_mark (out text_iter, mark);
        doc.place_cursor (text_iter);

        // scroll to cursor, line at the top
        _main_window.active_view.scroll_to_mark (doc.get_insert (), 0, true, 0, 0);

        /* select the corresponding item in the simple list */
        set_actions_sensitivity (type);

        if (! first_select)
            return true;

        select_simple_list_item (tree_iter);

        // the row is selected
        return true;
    }

    // tree_iter is a TreeIter from the tree (not the simple list) and points to the
    // corresponding item.
    private void select_simple_list_item (TreeIter tree_iter)
    {
        if (_list_is_hidden)
            return;

        TreeSelection list_select = _list_view.get_selection ();
        list_select.unselect_all ();

        StructType type;
        _model.get (tree_iter, StructColumn.TYPE, out type, -1);

        if (type != _current_list_type)
            return;

        int row_num = _model.get_list_num_from_tree_iter (tree_iter);

        if (row_num == -1)
            return;

        TreePath list_path = new TreePath.from_indices (row_num, -1);

        _first_select = false;
        list_select.select_path (list_path);

        _list_view.scroll_to_cell (list_path, null, false, 0, 0);
    }

    private void show_active_document ()
    {
        show_document (_main_window.active_document);
    }

    private void show_document (Document? doc, bool force_parse = false)
    {
        set_model (null);
        _tree_view.columns_autosize ();

        if (doc == null)
            return;

        DocumentStructure doc_struct = doc.get_structure ();

        if (force_parse)
            doc_struct.parse ();

        if (doc_struct.parsing_done)
            set_model (doc_struct.get_model ());

        doc_struct.notify["parsing-done"].connect (() =>
        {
            if (doc_struct.parsing_done)
                set_model (doc_struct.get_model ());
        });
    }

    private void set_model (StructureModel? model)
    {
        _model = model;
        _tree_view.set_model (model);
        _tree_view.expand_all ();

        populate_simple_list ();
    }

    public void connect_parsing ()
    {
        _main_window.notify["active-document"].connect (show_active_document);
        show_active_document ();
    }

    public void disconnect_parsing ()
    {
        _main_window.notify["active-document"].disconnect (show_active_document);
    }

    // Here it's the general meaning of "section" (part -> subparagraph).
    // A label for example is not a section.
    public static bool is_section (StructType type)
    {
        return type <= StructType.SUBPARAGRAPH;
    }


    /*************************************************************************/
    // Right-click: actions callbacks

    private void show_popup_menu (Gdk.EventButton? event)
    {
        if (event != null)
            _popup_menu.popup (null, null, null, event.button, event.time);
        else
            _popup_menu.popup (null, null, null, 0, get_current_event_time ());
    }

    private void set_actions_sensitivity (StructType type)
    {
        _action_all_menu.sensitive = true;

        _action_cut.sensitive = true;
        _action_copy.sensitive = true;
        _action_delete.sensitive = true;
        _action_select.sensitive = true;
        _action_comment.sensitive = type != StructType.TODO && type != StructType.FIXME;

        _action_shift_left.sensitive =
            StructType.PART < type && type <= StructType.SUBPARAGRAPH;

        _action_shift_right.sensitive = type < StructType.SUBPARAGRAPH;
    }

    public static void on_cut ()
    {
    }

    public static void on_copy ()
    {
    }

    public static void on_delete ()
    {
    }

    public static void on_select ()
    {
    }

    public static void on_comment ()
    {
    }

    public static void on_shift_left ()
    {
    }

    public static void on_shift_right ()
    {
    }

    public static string get_icon_from_type (StructType type)
    {
        if (_icons == null)
        {
            _icons = new string[StructType.N_TYPES];
            _icons[StructType.PART]         = "tree_part";
            _icons[StructType.CHAPTER]      = "tree_chapter";
            _icons[StructType.SECTION]      = "tree_section";
            _icons[StructType.SUBSECTION]   = "tree_subsection";
            _icons[StructType.SUBSUBSECTION] = "tree_subsubsection";
            _icons[StructType.PARAGRAPH]    = "tree_paragraph";
            _icons[StructType.SUBPARAGRAPH] = "tree_paragraph";
            _icons[StructType.LABEL]        = "tree_label";
            _icons[StructType.TODO]         = "tree_todo";
            _icons[StructType.FIXME]        = "tree_todo";
            _icons[StructType.TABLE]        = "table";
            _icons[StructType.FIGURE]       = "image";
            _icons[StructType.IMAGE]        = "image";
            _icons[StructType.INCLUDE]      = "tree_include";
        }

        return _icons[type];
    }

    public static string get_type_name (StructType type)
    {
        if (_names == null)
        {
            _names = new string[StructType.N_TYPES];
            _names[StructType.PART]         = _("Part");
            _names[StructType.CHAPTER]      = _("Chapter");
            _names[StructType.SECTION]      = _("Section");
            _names[StructType.SUBSECTION]   = _("Sub-section");
            _names[StructType.SUBSUBSECTION] = _("Sub-sub-section");
            _names[StructType.PARAGRAPH]    = _("Paragraph");
            _names[StructType.SUBPARAGRAPH] = _("Sub-paragraph");
            _names[StructType.LABEL]        = _("Label");
            _names[StructType.TODO]         = "TODO";
            _names[StructType.FIXME]        = "FIXME";
            _names[StructType.TABLE]        = _("Table");
            _names[StructType.FIGURE]       = _("Figure");
            _names[StructType.IMAGE]        = _("Image");
            _names[StructType.INCLUDE]      = _("File included");
        }

        return _names[type];
    }
}
