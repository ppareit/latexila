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

public enum StructItem
{
    PIXBUF,
    TYPE,
    TEXT,
    TOOLTIP,
    MARK,
    N_COLUMNS
}

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
    TODO,
    FIXME,
    N_TYPES
}

public class Structure : VBox
{
    private unowned MainWindow _main_window;
    private GLib.Settings _settings;
    private TreeStore _tree_store;
    private TreeModelFilter _tree_filter;
    private TreeView _tree_view;
    private bool[] _visible_types;

    public Structure (MainWindow main_window)
    {
        GLib.Object (spacing: 3);
        _main_window = main_window;

        _settings = new GLib.Settings ("org.gnome.latexila.preferences.ui");

        init_visible_types ();
        init_toolbar ();
        init_choose_min_level ();
        init_tree_view ();
        show_all ();

        show.connect (connect_parsing);
        hide.connect (disconnect_parsing);
    }

    private void init_visible_types ()
    {
        _visible_types = new bool[StructType.N_TYPES];

        _visible_types[StructType.LABEL] =
            _settings.get_boolean ("structure-show-label");

        _visible_types[StructType.INCLUDE] =
            _settings.get_boolean ("structure-show-include");

        _visible_types[StructType.TABLE] =
            _settings.get_boolean ("structure-show-table");

        _visible_types[StructType.FIGURE] =
            _settings.get_boolean ("structure-show-figure");

        _visible_types[StructType.TODO] =
            _settings.get_boolean ("structure-show-todo");

        _visible_types[StructType.FIXME] =
            _settings.get_boolean ("structure-show-fixme");
    }

    public void save_state ()
    {
        /* Save visible types */

        _settings.set_boolean ("structure-show-label",
            _visible_types[StructType.LABEL]);

        _settings.set_boolean ("structure-show-include",
            _visible_types[StructType.INCLUDE]);

        _settings.set_boolean ("structure-show-table",
            _visible_types[StructType.TABLE]);

        _settings.set_boolean ("structure-show-figure",
            _visible_types[StructType.FIGURE]);

        _settings.set_boolean ("structure-show-todo",
            _visible_types[StructType.TODO]);

        _settings.set_boolean ("structure-show-fixme",
            _visible_types[StructType.FIXME]);

        /* save min level */

        int min_level = StructType.PART;
        for (int level = 0 ; level <= StructType.SUBPARAGRAPH ; level++)
        {
            if (! _visible_types[level])
                break;
            min_level = level;
        }

        _settings.set_int ("structure-min-level", min_level);
    }

    private void init_toolbar ()
    {
        HBox hbox = new HBox (true, 0);
        pack_start (hbox, false, false);

        // refresh button
        Button refresh_button = Utils.get_toolbar_button (Stock.REFRESH);
        hbox.pack_start (refresh_button);

        refresh_button.clicked.connect (() =>
        {
            parse_document (_main_window.active_document);
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

        // show/hide buttons
        ToggleButton toggle_button = create_show_hide_button ({ StructType.LABEL },
            _("Show labels"));
        hbox.pack_start (toggle_button);

        toggle_button = create_show_hide_button ({ StructType.INCLUDE },
            _("Show files included"));
        hbox.pack_start (toggle_button);

        toggle_button = create_show_hide_button ({ StructType.TABLE },
            _("Show tables"));
        hbox.pack_start (toggle_button);

        toggle_button = create_show_hide_button ({ StructType.FIGURE },
            _("Show figures"));
        hbox.pack_start (toggle_button);

        toggle_button = create_show_hide_button ({ StructType.TODO, StructType.FIXME },
            _("Show TODOs and FIXMEs"));
        hbox.pack_start (toggle_button);
    }

    /* Create a show/hide button for hiding some types.
     * One button can hide several types, that's why it's an array.
     * The button image is the same as for the first type. If needed, we could add a new
     * parameter.
     */
    private ToggleButton? create_show_hide_button (StructType[] types, string tooltip)
    {
        return_val_if_fail (types.length > 0, null);

        ToggleButton button =
            Utils.get_toolbar_toggle_button (get_icon_from_type (types[0]));

        button.tooltip_text = tooltip;
        button.active = _visible_types[types[0]];

        button.toggled.connect (() =>
        {
            foreach (StructType type in types)
                _visible_types[type] = button.active;

            if (_tree_filter != null)
                _tree_filter.refilter ();
        });

        return button;
    }

    private void init_tree_view ()
    {
        _tree_store = new TreeStore (StructItem.N_COLUMNS,
            typeof (string),     // pixbuf (stock-id)
            typeof (StructType), // item type
            typeof (string),     // text
            typeof (string),     // tooltip
            typeof (TextMark)    // mark
            );

        _tree_filter = new TreeModelFilter (_tree_store, null);
        _tree_filter.set_visible_func ((model, iter) =>
        {
            StructType type;
            model.get (iter, StructItem.TYPE, out type, -1);

            return _visible_types[type];
        });

        _tree_view = new TreeView.with_model (_tree_filter);
        _tree_view.headers_visible = false;

        TreeViewColumn column = new TreeViewColumn ();
        _tree_view.append_column (column);

        // icon
        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        column.pack_start (pixbuf_renderer, false);
        column.set_attributes (pixbuf_renderer, "stock-id", StructItem.PIXBUF, null);

        // name
        CellRendererText text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", StructItem.TEXT, null);

        // tooltip
        _tree_view.set_tooltip_column (StructItem.TOOLTIP);

        // selection
        TreeSelection select = _tree_view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);
        select.set_select_function (on_row_selection);

        // with a scrollbar
        var sw = Utils.add_scrollbar (_tree_view);
        pack_start (sw);
    }

    private enum MinLevelColumn
    {
        PIXBUF,
        NAME,
        TYPE,
        N_COLUMNS
    }

    private void init_choose_min_level ()
    {
        ListStore list_store = new ListStore (MinLevelColumn.N_COLUMNS,
            typeof (string),
            typeof (string),
            typeof (StructType));

        ComboBox combo_box = new ComboBox.with_model (list_store);
        combo_box.tooltip_text = _("Minimum level");

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        combo_box.pack_start (pixbuf_renderer, false);
        combo_box.set_attributes (pixbuf_renderer,
            "stock-id", MinLevelColumn.PIXBUF, null);

        CellRendererText text_renderer = new CellRendererText ();
        combo_box.pack_start (text_renderer, true);
        combo_box.set_attributes (text_renderer, "text", MinLevelColumn.NAME, null);

        // populate the combo box
        for (int type = StructType.PART ; type <= StructType.SUBPARAGRAPH ; type++)
        {
            TreeIter iter;
            list_store.append (out iter);
            list_store.set (iter,
                MinLevelColumn.PIXBUF, get_icon_from_type ((StructType) type),
                MinLevelColumn.NAME, get_type_name ((StructType) type),
                MinLevelColumn.TYPE, type,
                -1);
        }

        combo_box.changed.connect (() =>
        {
            TreeIter iter;
            if (! combo_box.get_active_iter (out iter))
                return;

            StructType selected_type;
            TreeModel model = (TreeModel) list_store;
            model.get (iter, MinLevelColumn.TYPE, out selected_type, -1);

            for (int type = 0 ; type <= StructType.SUBPARAGRAPH ; type++)
                _visible_types[type] = type <= selected_type;

            if (_tree_filter != null)
                _tree_filter.refilter ();
            if (_tree_view != null)
                _tree_view.expand_all ();
        });

        // restore state
        int min_level = _settings.get_int ("structure-min-level");
        min_level = min_level.clamp (StructType.PART, StructType.SUBPARAGRAPH);
        combo_box.set_active (min_level);

        pack_start (combo_box, false, false);
    }

    private bool on_row_selection (TreeSelection selection, TreeModel model,
        TreePath path, bool path_currently_selected)
    {
        TreeIter tree_iter;
        if (! model.get_iter (out tree_iter, path))
            // the row is not selected
            return false;

        TextMark mark;
        model.get (tree_iter, StructItem.MARK, out mark, -1);

        TextBuffer doc = mark.get_buffer ();
        return_val_if_fail (doc == _main_window.active_document, false);

        // place the cursor so the line is highlighted (by default)
        TextIter text_iter;
        doc.get_iter_at_mark (out text_iter, mark);
        doc.place_cursor (text_iter);
        // scroll to cursor, line at the top
        _main_window.active_view.scroll_to_mark (doc.get_insert (), 0, true, 0, 0);

        // the row is selected
        return true;
    }

    // TODO: delete this function when the refresh button is removed
    private void parse_document (Document? doc)
    {
        clear ();

        if (doc == null)
            return;

        DocumentStructure doc_struct = doc.get_structure ();
        doc_struct.parse ();
        populate (doc_struct);
    }

    private void populate_active_document ()
    {
        clear ();

        Document? doc = _main_window.active_document;
        if (doc == null)
            return;

        populate (doc.get_structure ());
    }

    private void clear ()
    {
        _tree_store.clear ();
        _tree_view.columns_autosize ();
    }

    private void populate (DocumentStructure doc_struct)
    {
        Idle.add (() =>
        {
            doc_struct.populate_tree_store (_tree_store);
            _tree_view.expand_all ();

            // remove the idle source
            return false;
        });
    }

    public void connect_parsing ()
    {
        _main_window.notify["active-document"].connect (populate_active_document);
        populate_active_document ();
    }

    public void disconnect_parsing ()
    {
        _main_window.notify["active-document"].disconnect (populate_active_document);
    }

    public static string? get_icon_from_type (StructType type)
    {
        switch (type)
        {
            case StructType.PART:
                return "tree_part";

            case StructType.CHAPTER:
                return "tree_chapter";

            case StructType.SECTION:
                return "tree_section";

            case StructType.SUBSECTION:
                return "tree_subsection";

            case StructType.SUBSUBSECTION:
                return "tree_subsubsection";

            case StructType.PARAGRAPH:
            case StructType.SUBPARAGRAPH:
                return "tree_paragraph";

            case StructType.LABEL:
                return "tree_label";

            case StructType.TODO:
            case StructType.FIXME:
                return "tree_todo";

            case StructType.TABLE:
                return "table";

            case StructType.FIGURE:
                return "image";

            case StructType.INCLUDE:
                return "tree_include";

            default:
                return_val_if_reached (null);
        }
    }

    public static string? get_type_name (StructType type)
    {
        switch (type)
        {
            case StructType.PART:
                return _("Part");

            case StructType.CHAPTER:
                return _("Chapter");

            case StructType.SECTION:
                return _("Section");

            case StructType.SUBSECTION:
                return _("Sub-section");

            case StructType.SUBSUBSECTION:
                return _("Sub-sub-section");

            case StructType.PARAGRAPH:
                return _("Paragraph");

            case StructType.SUBPARAGRAPH:
                return _("Sub-paragraph");

            case StructType.LABEL:
                return _("Label");

            case StructType.TODO:
                return "TODO";

            case StructType.FIXME:
                return "FIXME";

            case StructType.TABLE:
                return _("Table");

            case StructType.FIGURE:
                return _("Figure");

            case StructType.INCLUDE:
                return _("File included");

            default:
                return_val_if_reached (null);
        }
    }
}
