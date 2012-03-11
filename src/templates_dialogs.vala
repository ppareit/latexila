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

// Create a new document from a template.
public class OpenTemplateDialog
{
    private unowned MainWindow _main_window;
    private Dialog _dialog;
    private IconView _icon_view_default_templates;
    private IconView _icon_view_personal_templates;
    private VPaned _vpaned;
    private GLib.Settings _settings;

    public OpenTemplateDialog (MainWindow main_window)
    {
        _main_window = main_window;

        _dialog = new Dialog.with_buttons (_("New File..."), main_window, 0,
            Stock.OK, ResponseType.ACCEPT,
            Stock.CANCEL, ResponseType.REJECT,
            null);

        // Get and set previous size.
        _settings = new GLib.Settings ("org.gnome.latexila.state.window");
        int width;
        int height;
        _settings.get ("new-file-dialog-size", "(ii)", out width, out height);
        _dialog.set_default_size (width, height);

        // Be able to shrink the dialog completely.
        _dialog.set_size_request (0, 0);

        Box content_area = _dialog.get_content_area () as Box;
        _vpaned = new VPaned ();
        content_area.pack_start (_vpaned);
        _vpaned.position = _settings.get_int ("new-file-dialog-paned-position");

        // Icon view for the default templates.
        Templates templates = Templates.get_default ();

        _icon_view_default_templates = templates.create_icon_view_default_templates ();

        Widget scrollbar = Utils.add_scrollbar (_icon_view_default_templates);
        scrollbar.hexpand = true;
        Widget component = Utils.get_dialog_component (_("Default templates"), scrollbar);
        _vpaned.pack1 (component, true, true);

        // Icon view for the personal templates.
        _icon_view_personal_templates = templates.create_icon_view_personal_templates ();

        scrollbar = Utils.add_scrollbar (_icon_view_personal_templates);
        scrollbar.hexpand = true;
        component = Utils.get_dialog_component (_("Your personal templates"), scrollbar);
        _vpaned.pack2 (component, false, true);

        content_area.show_all ();

        connect_to_signals ();
        run_me ();
        close_dialog ();
    }

    private void connect_to_signals ()
    {
        _icon_view_default_templates.selection_changed.connect (() =>
        {
            on_icon_view_selection_changed (_icon_view_default_templates,
                _icon_view_personal_templates);
        });

        _icon_view_personal_templates.selection_changed.connect (() =>
        {
            on_icon_view_selection_changed (_icon_view_personal_templates,
                _icon_view_default_templates);
        });

        _icon_view_default_templates.item_activated.connect ((path) =>
        {
            open_default_template (path);
            close_dialog ();
        });

        _icon_view_personal_templates.item_activated.connect ((path) =>
        {
            open_personal_template (path);
            close_dialog ();
        });
    }

    private void on_icon_view_selection_changed (IconView icon_view,
        IconView other_icon_view)
    {
        // Only one item of the two icon views can be selected at once.

        // We unselect all the items of the other icon view only if the current icon
        // view have an item selected, because when we unselect all the items the
        // "selection-changed" signal is emitted for the other icon view, so for the
        // other icon view this function is also called but no item is selected so
        // nothing is done and the item selected by the user keeps selected.

        List<TreePath> selected_items = icon_view.get_selected_items ();
        if (selected_items.length () > 0)
            other_icon_view.unselect_all ();
    }

    private void run_me ()
    {
        if (_dialog.run () != ResponseType.ACCEPT)
            return;

        // Default template selected?
        List<TreePath> selected_items =
            _icon_view_default_templates.get_selected_items ();

        if (selected_items.length () > 0)
        {
            TreePath path = selected_items.nth_data (0);
            open_default_template (path);
            return;
        }

        // Personal template selected?
        selected_items = _icon_view_personal_templates.get_selected_items ();
        if (selected_items.length () > 0)
        {
            TreePath path = selected_items.nth_data (0);
            open_personal_template (path);
            return;
        }

        // No template selected
        create_document ("");
    }

    private void open_default_template (TreePath path)
    {
        Templates templates = Templates.get_default ();
        create_document (templates.get_default_template_contents (path));
    }

    private void open_personal_template (TreePath path)
    {
        Templates templates = Templates.get_default ();
        create_document (templates.get_personal_template_contents (path));
    }

    private void create_document (string contents)
    {
        DocumentTab tab = _main_window.create_tab (true);
        tab.document.set_contents (contents);
    }

    private void close_dialog ()
    {
        // Save dialog size and paned position.
        int width;
        int height;
        _dialog.get_size (out width, out height);
        _settings.set ("new-file-dialog-size", "(ii)", width, height);

        _settings.set_int ("new-file-dialog-paned-position", _vpaned.position);

        _dialog.destroy ();
    }
}

public class CreateTemplateDialog : Dialog
{
    public CreateTemplateDialog (MainWindow parent)
    {
        return_if_fail (parent.active_tab != null);

        title = _("New Template...");
        set_transient_for (parent);
        add_button (Stock.OK, ResponseType.ACCEPT);
        add_button (Stock.CANCEL, ResponseType.REJECT);

        Box content_area = get_content_area () as Box;
        content_area.homogeneous = false;

        /* name */
        Entry entry = new Entry ();
        entry.hexpand = true;
        Widget component = Utils.get_dialog_component (_("Name of the new template"),
            entry);
        content_area.pack_start (component, false);

        /* icon */
        Templates templates = Templates.get_default ();

        // Take the default store because it contains all the icons.
        TreeView templates_list = templates.get_default_templates_list ();

        Widget scrollbar = Utils.add_scrollbar (templates_list);
        scrollbar.set_size_request (250, 200);
        component = Utils.get_dialog_component (_("Choose an icon"), scrollbar);
        content_area.pack_start (component);

        content_area.show_all ();

        run_me (parent, entry, templates_list);
    }

    private void run_me (MainWindow parent, Entry entry, TreeView templates_list)
    {
        Templates templates = Templates.get_default ();

        while (run () == ResponseType.ACCEPT)
        {
            // if no name specified
            if (entry.text_length == 0)
                continue;

            TreeSelection select = templates_list.get_selection ();
            List<TreePath> selected_items = select.get_selected_rows (null);

            // if no icon selected
            if (selected_items.length () == 0)
                continue;

            // get the contents
            TextIter start, end;
            parent.active_document.get_bounds (out start, out end);
            string contents = parent.active_document.get_text (start, end, false);

            // get the icon id
            TreePath path = selected_items.nth_data (0);
            string icon_id = templates.get_icon_id (path);

            templates.create_personal_template (entry.text, icon_id, contents);
            break;
        }
    }
}

public class DeleteTemplateDialog : Dialog
{
    public DeleteTemplateDialog (MainWindow parent)
    {
        title = _("Delete Template(s)...");
        add_button (Stock.DELETE, ResponseType.ACCEPT);
        add_button (Stock.CLOSE, ResponseType.REJECT);
        set_transient_for (parent);

        /* List of the personal templates */

        Templates templates = Templates.get_default ();
        TreeView templates_list = templates.get_personal_templates_list ();

        Widget scrollbar = Utils.add_scrollbar (templates_list);
        scrollbar.set_size_request (250, 150);
        Widget component = Utils.get_dialog_component (_("Personal templates"),
            scrollbar);

        Box content_area = get_content_area () as Box;
        content_area.pack_start (component);
        content_area.show_all ();

        run_me (templates_list);
    }

    private void run_me (TreeView templates_list)
    {
        Templates templates = Templates.get_default ();
        bool template_deleted = false;

        while (run () == ResponseType.ACCEPT)
        {
            TreeSelection select = templates_list.get_selection ();
            List<TreePath> selected_items = select.get_selected_rows (null);
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
