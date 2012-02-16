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

public class GotoLine : Grid
{
    private unowned MainWindow main_window;
    private Entry entry;

    public GotoLine (MainWindow main_window)
    {
        orientation = Orientation.HORIZONTAL;
        set_column_spacing (3);
        this.main_window = main_window;

        Button close_button = new Button ();
        add (close_button);
        close_button.set_relief (ReliefStyle.NONE);
        Image img = new Image.from_stock (Stock.CLOSE, IconSize.MENU);
        close_button.add (img);
        close_button.clicked.connect (() => hide ());

        Label label = new Label (_("Go to Line:"));
        label.margin_left = 2;
        label.margin_right = 2;
        add (label);

        entry = new Entry ();
        add (entry);
        entry.set_icon_from_stock (EntryIconPosition.SECONDARY, Stock.JUMP_TO);
        entry.set_icon_activatable (EntryIconPosition.SECONDARY, true);
        entry.set_tooltip_text (_("Line you want to move the cursor to"));
        entry.set_size_request (100, -1);
        entry.activate.connect (() => hide ());
        entry.icon_press.connect (() => hide ());
        entry.changed.connect (on_changed);
    }

    public new void show ()
    {
        entry.text = "";
        show_all ();
        entry.grab_focus ();
    }

    private void on_changed ()
    {
        if (entry.text_length == 0)
        {
            Utils.set_entry_error (entry, false);
            return;
        }

        string text = entry.get_text ();

        // check if all characters are digits
        for (int i = 0 ; i < text.length ; i++)
        {
            unichar c = text[i];
            if (! c.isdigit ())
            {
                Utils.set_entry_error (entry, true);
                return;
            }
        }

        int line = int.parse (text);
        bool error = ! main_window.active_document.goto_line (--line);
        Utils.set_entry_error (entry, error);
        main_window.active_view.scroll_to_cursor ();
    }
}

public class SearchAndReplace : GLib.Object
{
    private unowned MainWindow _main_window;
    private Document _working_document;

    private Grid _main_grid;
    private Grid _replace_grid;

    private Button _button_arrow;
    private Arrow _arrow;

    private Entry _entry_find;
    private Entry _entry_replace;

    private CheckMenuItem _check_case_sensitive;
    private CheckMenuItem _check_entire_word;

    private int min_nb_chars_for_inc_search = 3;

    private enum Mode
    {
        SEARCH,
        SEARCH_AND_REPLACE
    }

    private Mode get_mode ()
    {
        if (_arrow.arrow_type == ArrowType.UP)
            return Mode.SEARCH_AND_REPLACE;

        return Mode.SEARCH;
    }

    private bool case_sensitive
    {
        get { return _check_case_sensitive.get_active (); }
    }

    private bool entire_word
    {
        get { return _check_entire_word.get_active (); }
    }

    public SearchAndReplace (MainWindow main_window)
    {
        _main_window = main_window;
        _main_grid = new Grid ();
        _main_grid.set_column_spacing (3);

        /* Arrow */
        _button_arrow = new Button ();
        _arrow = new Arrow (ArrowType.DOWN, ShadowType.OUT);
        _button_arrow.add (_arrow);
        _main_grid.attach (_button_arrow, 0, 0, 1, 1);

        /* Find entry */
        Grid find_grid = new Grid ();
        find_grid.set_orientation (Orientation.HORIZONTAL);
        find_grid.set_column_spacing (2);
        _main_grid.attach (find_grid, 1, 0, 1, 1);

        init_find_entry ();
        find_grid.add (_entry_find);

        /* Buttons at the right of the find entry */
        Button button_clear_find = get_button (Stock.CLEAR);
        Button button_previous = get_button (Stock.GO_UP);
        Button button_next = get_button (Stock.GO_DOWN);
        Button button_close = get_button (Stock.CLOSE);

        find_grid.add (button_clear_find);
        find_grid.add (button_previous);
        find_grid.add (button_next);
        find_grid.add (button_close);

        button_clear_find.sensitive = false;
        button_previous.sensitive = false;
        button_next.sensitive = false;

        /* Replace entry */
        _replace_grid = new Grid ();
        _replace_grid.set_orientation (Orientation.HORIZONTAL);
        _replace_grid.set_column_spacing (2);
        _main_grid.attach (_replace_grid, 1, 1, 1, 1);

        _entry_replace = new Entry ();
        _entry_replace.set_tooltip_text (_("Replace with"));
        _entry_replace.can_focus = true;
        _entry_replace.set_width_chars (25);
        _replace_grid.add (_entry_replace);

        /* Buttons at the right of the replace entry */
        Button button_clear_replace = get_button (Stock.CLEAR);
        Button button_replace = get_button (Stock.FIND_AND_REPLACE);

        // replace all: image + label
        Button button_replace_all = new Button ();
        button_replace_all.set_relief (ReliefStyle.NONE);
        Grid replace_all_grid = new Grid ();
        replace_all_grid.set_orientation (Orientation.HORIZONTAL);
        replace_all_grid.set_column_spacing (8);

        Image image = new Image.from_stock (Stock.FIND_AND_REPLACE, IconSize.MENU);
        replace_all_grid.add (image);

        Label label = new Label (_("All"));
        replace_all_grid.add (label);
        button_replace_all.add (replace_all_grid);

        _replace_grid.add (button_clear_replace);
        _replace_grid.add (button_replace);
        _replace_grid.add (button_replace_all);

        button_clear_replace.sensitive = false;
        button_replace.sensitive = false;
        button_replace_all.sensitive = false;

        /* signal handlers */

        _button_arrow.clicked.connect (() =>
        {
            // search and replace -> search
            if (get_mode () == Mode.SEARCH_AND_REPLACE)
            {
                _arrow.arrow_type = ArrowType.DOWN;
                _replace_grid.hide ();
            }

            // search -> search and replace
            else
            {
                _arrow.arrow_type = ArrowType.UP;
                _replace_grid.show ();
            }
        });

        button_close.clicked.connect (hide);

        button_clear_find.clicked.connect (() => _entry_find.text = "");
        button_clear_replace.clicked.connect (() => _entry_replace.text = "");

        button_previous.clicked.connect (() =>
        {
            set_search_text (false);
            return_if_fail (_working_document != null);
            _working_document.search_backward ();
        });

        button_next.clicked.connect (search_forward);
        _entry_find.activate.connect (search_forward);

        _entry_find.changed.connect (() =>
        {
            bool sensitive = _entry_find.text_length > 0;
            button_clear_find.sensitive = sensitive;
            button_previous.sensitive = sensitive;
            button_next.sensitive = sensitive;
            button_replace.sensitive = sensitive;
            button_replace_all.sensitive = sensitive;

            if (_entry_find.text_length == 0)
                clear_search ();
            else if (_entry_find.text_length >= min_nb_chars_for_inc_search)
                set_search_text ();
        });

        _entry_replace.changed.connect (() =>
        {
            button_clear_replace.sensitive = _entry_replace.text_length > 0;
        });

        _check_case_sensitive.toggled.connect (() => set_search_text ());
        _check_entire_word.toggled.connect (() => set_search_text ());

        button_replace.clicked.connect (replace);
        _entry_replace.activate.connect (replace);

        button_replace_all.clicked.connect (() =>
        {
            return_if_fail (_entry_find.text_length != 0);
            set_search_text ();
            _working_document.replace_all (_entry_replace.text);
        });

        _entry_find.key_press_event.connect ((event) =>
        {
            switch (event.keyval)
            {
                case Gdk.Key.Tab:
                    // TAB in find => go to replace
                    show_search_and_replace ();
                    _entry_replace.grab_focus ();
                    return true;

                case Gdk.Key.Escape:
                    // Escape in find => select text and hide search
                    select_current_match ();
                    hide ();
                    return true;

                default:
                    // propagate the event further
                    return false;
            }
        });

        _main_grid.hide ();
    }

    /* Find entry */
    private void init_find_entry ()
    {
        _entry_find = new Entry ();
        _entry_find.primary_icon_stock = Stock.PROPERTIES;
        _entry_find.primary_icon_activatable = true;
        _entry_find.set_tooltip_text (_("Search for"));
        _entry_find.can_focus = true;
        _entry_find.set_width_chars (25);

        /* Options menu */
        Gtk.Menu menu = new Gtk.Menu ();
        _check_case_sensitive = new CheckMenuItem.with_label (_("Case sensitive"));
        _check_entire_word = new CheckMenuItem.with_label (_("Entire words only"));
        menu.append (_check_case_sensitive);
        menu.append (_check_entire_word);
        menu.show_all ();

        _entry_find.icon_press.connect ((icon_pos, event) =>
        {
            if (icon_pos == EntryIconPosition.PRIMARY)
                menu.popup (null, null, null, event.button.button, event.button.time);
        });
    }

    private Button get_button (string stock_id)
    {
        Button button = new Button ();
        Image image = new Image.from_stock (stock_id, IconSize.MENU);
        button.add (image);
        button.set_relief (ReliefStyle.NONE);
        return button;
    }

    public Widget get_widget ()
    {
        return _main_grid;
    }

    public void show_search ()
    {
        _arrow.arrow_type = ArrowType.DOWN;
        show ();
        _replace_grid.hide ();
    }

    public void show_search_and_replace ()
    {
        _arrow.arrow_type = ArrowType.UP;
        show ();
    }

    private void show ()
    {
        return_if_fail (_main_window.active_tab != null);

        _main_grid.show_all ();
        _entry_find.grab_focus ();
        set_replace_sensitivity ();

        // if text is selected in the active document, and if this text contains no \n,
        // search this text
        Document doc = _main_window.active_document;
        if (doc.get_selection_type () == SelectionType.ONE_LINE)
        {
            TextIter start, end;
            doc.get_selection_bounds (out start, out end);
            _entry_find.text = doc.get_text (start, end, false);
        }

        _main_window.notify["active-document"].connect (set_replace_sensitivity);
    }

    public void hide ()
    {
        _main_grid.hide ();
        if (_working_document != null)
            clear_search ();

        if (_main_window.active_view != null)
            _main_window.active_view.grab_focus ();

        _main_window.notify["active-document"].disconnect (set_replace_sensitivity);
    }

    private void set_search_text (bool select = true)
    {
        return_if_fail (_main_window.active_document != null);

        if (_entry_find.text_length == 0)
            return;

        if (_main_window.active_document != _working_document)
        {
            if (_working_document != null)
                clear_search ();

            _working_document = _main_window.active_document;
        }

        uint nb_matches;

        _working_document.set_search_text (_entry_find.text, case_sensitive,
            entire_word, out nb_matches, null, select);

        Utils.set_entry_error (_entry_find, nb_matches == 0);
    }

    private void select_current_match ()
    {
        return_if_fail (_main_window.active_document != null);

        if (_working_document != null);
            _working_document.select_current_match ();
    }

    private void search_forward ()
    {
        set_search_text (false);
        return_if_fail (_working_document != null);
        _working_document.search_forward ();
    }

    private void clear_search ()
    {
        if (_working_document != null)
        {
            _working_document.clear_search ();
            _working_document = null;
        }
    }

    private void set_replace_sensitivity ()
    {
        bool readonly = _main_window.active_document.readonly;
        _replace_grid.set_sensitive (! readonly);
    }

    private void replace ()
    {
        return_if_fail (_entry_find.text_length != 0);
        set_search_text ();
        _working_document.replace (_entry_replace.text);
    }
}
