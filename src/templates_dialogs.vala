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
 */

using Gtk;

public class DeleteTemplateDialog : Dialog
{
    public DeleteTemplateDialog (MainWindow parent)
    {
        title = _("Delete Template(s)...");
        add_button (Stock.DELETE, ResponseType.ACCEPT);
        add_button (Stock.CLOSE, ResponseType.REJECT);
        has_separator = false;
        set_transient_for (parent);
        set_default_size (400, 200);

        /* icon view for the personal templates */

        Templates templates = Templates.get_default ();
        IconView icon_view = templates.create_icon_view_personal_templates ();
        icon_view.set_selection_mode (SelectionMode.MULTIPLE);

        Widget scrollbar = Utils.add_scrollbar (icon_view);
        Widget component = Utils.get_dialog_component (_("Personal templates"),
            scrollbar);

        Box content_area = get_content_area () as Box;
        content_area.pack_start (component);
        content_area.show_all ();

        run_me (icon_view);
    }

    private void run_me (IconView icon_view)
    {
        Templates templates = Templates.get_default ();
        bool template_deleted = false;

        while (run () == ResponseType.ACCEPT)
        {
            List<TreePath> selected_items = icon_view.get_selected_items ();
            uint nb_selected_items = selected_items.length ();

            for (int item_num = 0 ; item_num < nb_selected_items ; item_num++)
            {
                TreePath path = selected_items.nth_data (item_num);
                templates.delete_personal_template (path);
                template_deleted = true;
            }
        }

        if (template_deleted)
            templates.save_rc_file ();
    }
}
