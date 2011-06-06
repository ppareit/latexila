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
    TODO,
    FIXME,
    N_TYPES
}

public class Structure : VBox
{
    private unowned MainWindow _main_window;
    private GLib.Settings _settings;
    private TreeModelFilter _tree_filter;
    private TreeView _tree_view;
    private bool[] _visible_types;

    private static string[] _icons = null;
    private static string[] _names = null;

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

        // the other types are initialized in init_choose_min_level()
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
        for (int level = min_level ; is_section ((StructType) level) ; level++)
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
        _tree_view = new TreeView ();
        _tree_view.headers_visible = false;

        TreeViewColumn column = new TreeViewColumn ();
        _tree_view.append_column (column);

        // icon
        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        column.pack_start (pixbuf_renderer, false);
        column.set_attributes (pixbuf_renderer, "stock-id", StructColumn.PIXBUF, null);

        // name
        CellRendererText text_renderer = new CellRendererText ();
        column.pack_start (text_renderer, true);
        column.set_attributes (text_renderer, "text", StructColumn.TEXT, null);

        // tooltip
        _tree_view.set_tooltip_column (StructColumn.TOOLTIP);

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

            for (int type = 0 ; is_section ((StructType) type) ; type++)
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
        model.get (tree_iter, StructColumn.MARK, out mark, -1);

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

    private void show_active_document ()
    {
        show_document (_main_window.active_document);
    }

    private void show_document (Document? doc, bool force_parse = false)
    {
        if (doc == null)
            return;

        _tree_view.set_model (null);

        DocumentStructure doc_struct = doc.get_structure ();

        if (force_parse)
            doc_struct.parse ();

        doc_struct.parsing_done.connect (() =>
        {
            set_model (doc_struct.get_model ());
        });
    }

    private void set_model (StructureModel model)
    {
        _tree_filter = new TreeModelFilter (model, null);
        _tree_filter.set_visible_func ((mod, iter) =>
        {
            StructType type;
            mod.get (iter, StructColumn.TYPE, out type, -1);

            return _visible_types[type];
        });

        _tree_view.set_model (_tree_filter);
        _tree_view.expand_all ();
        _tree_view.columns_autosize ();
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
            _names[StructType.INCLUDE]      = _("File included");
        }

        return _names[type];
    }
}
