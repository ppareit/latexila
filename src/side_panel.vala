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

using Gtk;

public class SidePanel : VBox
{
    private unowned MainWindow main_window;
    private unowned ToggleAction action_view_side_panel;

    private static const int NB_COMPONENTS = 2;
    private VBox[] components;
    private ComboBox combo_box;

    public SidePanel (MainWindow main_window, ToggleAction action_view_side_panel)
    {
        this.main_window = main_window;
        this.action_view_side_panel = action_view_side_panel;

        components = new VBox[NB_COMPONENTS];
        for (int i = 0 ; i < NB_COMPONENTS ; i++)
            components[i] = null;

        HBox hbox = new HBox (false, 3);
        hbox.border_width = 3;
        pack_start (hbox, false, false, 3);

        combo_box = get_combo_box ();
        hbox.pack_start (combo_box);
        hbox.pack_start (get_close_button (), false, false);

        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.preferences.ui");
        int num = settings.get_int ("side-panel-component");
        num = num.clamp (0, NB_COMPONENTS - 1);
        combo_box.set_active (num);
    }

    private Button get_close_button ()
    {
        Button close_button = new Button ();
        close_button.relief = ReliefStyle.NONE;
        close_button.focus_on_click = false;
        //close_button.name = "my-close-button";
        close_button.tooltip_text = _("Hide panel");
        close_button.add (new Image.from_stock (STOCK_CLOSE, IconSize.MENU));
        close_button.clicked.connect (() =>
        {
            this.hide ();
            action_view_side_panel.active = false;
        });

        return close_button;
    }

    private enum SidePanelColumn
    {
        PIXBUF,
        NAME,
        N_COLUMNS
    }

    private ComboBox get_combo_box ()
    {
        ListStore list_store = new ListStore (SidePanelColumn.N_COLUMNS, typeof (string),
            typeof (string));

        TreeIter iter;
        list_store.append (out iter);
        list_store.set (iter,
            SidePanelColumn.PIXBUF, "symbol_alpha",
            SidePanelColumn.NAME, _("Symbols"),
            -1);

        list_store.append (out iter);
        list_store.set (iter,
            SidePanelColumn.PIXBUF, STOCK_OPEN,
            SidePanelColumn.NAME, _("File Browser"),
            -1);

        ComboBox combo_box = new ComboBox.with_model (list_store);
        //combo_box.has_frame = false;

        CellRendererPixbuf pixbuf_renderer = new CellRendererPixbuf ();
        combo_box.pack_start (pixbuf_renderer, false);
        combo_box.set_attributes (pixbuf_renderer,
            "stock-id", SidePanelColumn.PIXBUF, null);

        CellRendererText text_renderer = new CellRendererText ();
        combo_box.pack_start (text_renderer, true);
        combo_box.set_attributes (text_renderer, "text", SidePanelColumn.NAME, null);

        combo_box.changed.connect (() =>
        {
            foreach (VBox? component in components)
            {
                if (component != null)
                    component.hide ();
            }

            int i = combo_box.get_active ();
            if (components[i] == null)
                init_component (i);
            components[i].show_all ();
        });

        return combo_box;
    }

    private void init_component (int i)
    {
        if (components[i] == null)
        {
            switch (i)
            {
                case 0:
                    components[0] = new Symbols (main_window);
                    break;
                case 1:
                    components[1] = new FileBrowser ();
                    break;
            }

            pack_start (components[i]);
        }
    }

    public int get_active_component ()
    {
        return combo_box.get_active ();
    }
}
