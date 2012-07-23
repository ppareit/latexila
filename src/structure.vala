/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2011-2012 Sébastien Wilmet
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

// Model: structure_model.vala
// View: structure.vala
// Controller: document_structure.vala

// Little overview:
//
// The complete structure of a file is displayed in a tree.
// There are also "simple lists" that displays only one or several types of items.
// When an element in the simple list is selected, the corresponding element in the tree
// is also selected, and inversely.
// When an item is selected, the cursor in the file is moved to the item.
// Some actions are possible on the items. These actions are located in the Structure
// menu, or simply by a right click on the item.
// There is a mini-toolbar, with buttons to choose the simple list, and some other
// actions like refresh the data.

public enum StructType
{
    // Common types: items that can be fetched at once (only one LaTeX markup or comment)
    BEGIN_COMMON_TYPES,
    PART,
    CHAPTER,
    SECTION,
    SUBSECTION,
    SUBSUBSECTION,
    PARAGRAPH,
    SUBPARAGRAPH,
    LABEL,
    INCLUDE,
    IMAGE,
    TODO,
    FIXME,
    END_COMMON_TYPES,

    // Low-level types: does not correspond to an item that can be directly displayed
    // in the structure.
    BEGIN_LOW_LEVEL_TYPES,
    BEGIN_FIGURE,
    END_FIGURE,
    BEGIN_TABLE,
    END_TABLE,
    BEGIN_VERBATIM,
    END_VERBATIM,
    END_DOCUMENT,
    CAPTION,
    END_LOW_LEVEL_TYPES,

    // High-level types: items that contain a number of low level types, and that are
    // displayed in the structure.
    BEGIN_HIGH_LEVEL_TYPES,
    TABLE,
    FIGURE,
    END_HIGH_LEVEL_TYPES,

    NB_TYPES
}

public enum StructAction
{
    CUT,
    COPY,
    DELETE,
    SELECT,
    COMMENT,
    SHIFT_LEFT,
    SHIFT_RIGHT,
    NB_ACTIONS
}

public class Structure : Grid
{
    private unowned MainWindow _main_window;

    private ToggleButton[] _simple_list_buttons = {};
    private Paned _vpaned;

    private TreeView _tree_view;
    private DocumentStructure _document_structure = null;
    private StructureModel? _model = null;

    private TreeView _list_view;
    private Widget _list_view_sw;
    private ListStore _list_store;
    // A simple list can contain several types (e.g. TODOs and FIXMEs), but it's easier
    // to store only one type. See get_simple_list_types().
    private StructType _current_list_type;
    private bool _list_is_hidden = true;

    private bool _first_select = true;

    private static string[] _icons = null;
    private static string[] _names = null;
    private static string[] _action_names = null;

    public signal void item_selected (StructType type);
    public signal void show_popup_menu (Gdk.EventButton? event);

    public Structure (MainWindow main_window)
    {
        orientation = Orientation.VERTICAL;
        row_spacing = 3;
        _main_window = main_window;

        init_toolbar ();
        init_vpaned ();
        init_list_view ();
        init_tree_view ();
        show_all ();
        _list_view_sw.hide ();

        show.connect (connect_parsing);
        hide.connect (disconnect_parsing);
    }

    private void init_toolbar ()
    {
        Grid grid = new Grid ();
        grid.set_orientation (Orientation.HORIZONTAL);
        add (grid);

        // refresh button
        Button refresh_button = Utils.get_toolbar_button (Stock.REFRESH);
        refresh_button.tooltip_text = _("Refresh");
        grid.add (refresh_button);

        refresh_button.clicked.connect (() =>
        {
            show_document (_main_window.active_document, true);
        });

        // collapse all button
        Button collapse_button = Utils.get_toolbar_button (Stock.ZOOM_OUT);
        collapse_button.tooltip_text = _("Collapse All");
        grid.add (collapse_button);

        collapse_button.clicked.connect (() => _tree_view.collapse_all ());

        // separator
        SeparatorToolItem sep = new SeparatorToolItem ();
        grid.add (sep);

        // simple list buttons
        ToggleButton toggle_button = create_simple_list_button (StructType.LABEL,
            _("Show labels"));
        grid.add (toggle_button);

        toggle_button = create_simple_list_button (StructType.INCLUDE,
            _("Show files included"));
        grid.add (toggle_button);

        toggle_button = create_simple_list_button (StructType.TABLE,
            _("Show tables"));
        grid.add (toggle_button);

        toggle_button = create_simple_list_button (StructType.FIGURE,
            _("Show figures and images"));
        grid.add (toggle_button);

        toggle_button = create_simple_list_button (StructType.TODO,
            _("Show TODOs and FIXMEs"));
        grid.add (toggle_button);
    }

    // Only one button can be activated at the same time.
    // If no button is selected, the simple list is hidden.
    // If a button is selected, the simple list contains only items specified by 'types'.
    private ToggleButton? create_simple_list_button (StructType type, string tooltip)
    {
        ToggleButton button = Utils.get_toolbar_toggle_button (get_icon_from_type (type));
        button.tooltip_text = tooltip;

        _simple_list_buttons += button;

        button.clicked.connect (() =>
        {
            if (! button.get_active ())
            {
                if (! _list_is_hidden && type == _current_list_type)
                {
                    _list_is_hidden = true;
                    _list_view_sw.hide ();
                }
                return;
            }

            _current_list_type = type;
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
            return;

        TreePath tree_path = selected_rows.nth_data (0);
        TreeIter tree_iter;
        if (! _model.get_iter (out tree_iter, tree_path))
            return_if_reached ();

        select_simple_list_item (tree_iter);
    }

    private void init_vpaned ()
    {
        _vpaned = new Paned (Orientation.VERTICAL);
        _vpaned.expand = true;
        add (_vpaned);

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

        _tree_view.enable_tree_lines = true;

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
            StructColumn.START_MARK, out mark,
            StructColumn.TYPE, out type
        );

        /* go to the location in the document */
        TextBuffer doc = mark.get_buffer ();
        return_val_if_fail (doc == _main_window.active_document, false);

        // place the cursor so the line is highlighted (by default)
        TextIter text_iter;
        doc.get_iter_at_mark (out text_iter, mark);
        doc.place_cursor (text_iter);

        // scroll to cursor, line at the top (no horizontal scroll)
        _main_window.active_view.scroll_to_mark (doc.get_insert (), 0, true, 1, 0);

        /* select the corresponding item in the simple list */
        if (! first_select)
            return true;

        select_simple_list_item (tree_iter);

        // the row is selected
        item_selected (type);
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

        Gee.ArrayList<StructType> current_list_types =
            get_simple_list_types (_current_list_type);

        if (! current_list_types.contains (type))
            return;

        int row_num = _model.get_list_num_from_tree_iter (tree_iter);

        if (row_num == -1)
            return;

        TreePath list_path = new TreePath.from_indices (row_num, -1);

        _first_select = false;
        list_select.select_path (list_path);

        _list_view.scroll_to_cell (list_path, null, false, 0, 0);
    }

    // A simple list can contain several different item types.
    // For example, the list of TODOs and FIXMEs.
    private Gee.ArrayList<StructType> get_simple_list_types (StructType type)
    {
        return_val_if_fail (! is_section (type), null);

        Gee.ArrayList<StructType> types = new Gee.ArrayList<StructType> ();

        switch (type)
        {
            case StructType.FIGURE:
            case StructType.IMAGE:
                types.add (StructType.FIGURE);
                types.add (StructType.IMAGE);
                break;

            case StructType.TODO:
            case StructType.FIXME:
                types.add (StructType.TODO);
                types.add (StructType.FIXME);
                break;

            default:
                types.add (type);
                break;
        }

        return types;
    }

    private void show_active_document ()
    {
        show_document (_main_window.active_document);
    }

    private void show_document (Document? doc, bool force_parse = false)
    {
        set_model (null);
        _tree_view.columns_autosize ();

        if (_document_structure != null)
            _document_structure.notify["parsing-done"].disconnect (on_parsing_done);

        if (doc == null)
        {
            _document_structure = null;
            return;
        }

        _document_structure = doc.get_structure ();

        if (force_parse)
            _document_structure.parse ();

        if (_document_structure.parsing_done)
            on_parsing_done ();
        else
            _document_structure.notify["parsing-done"].connect (on_parsing_done);
    }

    private void on_parsing_done ()
    {
        return_if_fail (_document_structure != null);

        if (_document_structure.parsing_done)
            set_model (_document_structure.get_model ());
    }

    private void set_model (StructureModel? model)
    {
        if (model != null)
            model.emit_signals = true;

        _model = model;
        _tree_view.set_model (model);

        // expand all can be slow with big documents
        if (model != null && model.get_nb_items () <= 2000)
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
        return StructType.PART <= type && type <= StructType.SUBPARAGRAPH;
    }

    public static bool is_common_type (StructType type)
    {
        return StructType.BEGIN_COMMON_TYPES < type
            && type < StructType.END_COMMON_TYPES;
    }


    /*************************************************************************/
    // Right-click: actions

    public void do_action (StructAction action_type)
    {
        TreeIter selected_iter;
        int selected_row = Utils.get_selected_row (_tree_view, out selected_iter);

        return_if_fail (selected_row != -1);

        bool refresh_simple_list = false;

        try
        {
            _document_structure.do_action (action_type, selected_iter,
                out refresh_simple_list);
        }
        catch (StructError e)
        {
            MessageDialog dialog = new MessageDialog (_main_window,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.ERROR,
                ButtonsType.OK,
                _("Structure action error: %s"),
                get_action_name (action_type));

            if (e is StructError.DATA_OUTDATED)
                dialog.secondary_text =
                    _("The structure data seems outdated. Please refresh the structure.");
            else
                dialog.secondary_text = e.message;

            dialog.run ();
            dialog.destroy ();
            return;
        }

        // refresh the simple list if needed
        if (refresh_simple_list)
            populate_simple_list ();
    }

    private static string get_action_name (StructAction action_type)
    {
        if (_action_names == null)
        {
            _action_names = new string[StructAction.NB_ACTIONS];
            // Translators: it's a verb
            _action_names[StructAction.CUT]         = _("cut");
            // Translators: it's a verb
            _action_names[StructAction.COPY]        = _("copy");
            _action_names[StructAction.DELETE]      = _("delete");
            _action_names[StructAction.SELECT]      = _("select");
            // Translators: it's a verb
            _action_names[StructAction.COMMENT]     = _("comment");
            // Translators: it's a verb
            _action_names[StructAction.SHIFT_LEFT]  = _("shift left");
            // Translators: it's a verb
            _action_names[StructAction.SHIFT_RIGHT] = _("shift right");
        }

        return _action_names[action_type];
    }

    public static string get_icon_from_type (StructType type)
    {
        if (_icons == null)
        {
            _icons = new string[StructType.NB_TYPES];
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
            _icons[StructType.INCLUDE]      = Stock.FILE;
        }

        return _icons[type];
    }

    public static string get_type_name (StructType type)
    {
        if (_names == null)
        {
            _names = new string[StructType.NB_TYPES];
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
            // Translators: "Figure" here means a diagram (\begin{figure}...\end{figure})
            _names[StructType.FIGURE]       = _("Figure");
            _names[StructType.IMAGE]        = _("Image");
            _names[StructType.INCLUDE]      = _("File included");
        }

        return _names[type];
    }
}
