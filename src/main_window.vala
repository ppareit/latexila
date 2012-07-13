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

public class MainWindow : Window
{
    // for the menu and the toolbar
    // name, stock_id, label, accelerator, tooltip, callback
    private const Gtk.ActionEntry[] action_entries =
    {
        // File
        { "File", null, N_("_File") },
        { "FileNew", Stock.NEW, null, null,
            N_("New file"), on_file_new },
        { "FileNewWindow", null, N_("New _Window"), null,
            N_("Create a new window"), on_new_window },
        { "FileOpen", Stock.OPEN, null, null,
            N_("Open a file"), on_file_open },
        { "FileSave", Stock.SAVE, null, null,
            N_("Save the current file"), on_file_save },
        { "FileSaveAs", Stock.SAVE_AS, null, null,
            N_("Save the current file with a different name"), on_file_save_as },
        { "FileCreateTemplate", null, N_("Create _Template From Document..."), null,
            N_("Create a new template from the current document"), on_create_template },
        { "FileDeleteTemplate", null, N_("_Delete Template..."), null,
            N_("Delete personal template(s)"), on_delete_template },
        { "FileClose", Stock.CLOSE, null, null,
            N_("Close the current file"), on_file_close },
        { "FileQuit", Stock.QUIT, null, null,
            N_("Quit the program"), on_quit },

        // Edit
        { "Edit", null, N_("_Edit") },
        { "EditUndo", Stock.UNDO, null, "<Control>Z",
            N_("Undo the last action"), on_edit_undo },
        { "EditRedo", Stock.REDO, null, "<Shift><Control>Z",
            N_("Redo the last undone action"), on_edit_redo },
        { "EditCut", Stock.CUT, null, null,
            N_("Cut the selection"), on_edit_cut },
        { "EditCopy", Stock.COPY, null, null,
            N_("Copy the selection"), on_edit_copy },

        // No shortcut here because if the shortcut is null, Ctrl+V is used for the _all_
        // the window. In this case Ctrl+V in the search text entry would be broken (the
        // text is pasted in the document instead of the entry).
        // Anyway if we press Ctrl+V when the cursor is in the document, no problem.
        { "EditPaste", Stock.PASTE, null, "",
            N_("Paste the clipboard"), on_edit_paste },

        { "EditDelete", Stock.DELETE, null, null,
            N_("Delete the selected text"), on_edit_delete },
        { "EditSelectAll", Stock.SELECT_ALL, null, "<Control>A",
            N_("Select the entire document"), on_edit_select_all },
        { "EditComment", null, N_("_Comment"), "<Control>M",
            N_("Comment the selected lines (add the character \"%\")"),
            on_edit_comment },
        { "EditUncomment", null, N_("_Uncomment"), "<Shift><Control>M",
            N_("Uncomment the selected lines (remove the character \"%\")"),
            on_edit_uncomment },
        { "EditPreferences", Stock.PREFERENCES, null, null,
            N_("Configure the application"), on_open_preferences },

        // View
        { "View", null, N_("_View") },
        { "ViewZoomIn", Stock.ZOOM_IN, N_("Zoom _In"), "<Control>plus",
            N_("Enlarge the font"), on_view_zoom_in },
        { "ViewZoomOut", Stock.ZOOM_OUT, N_("Zoom _Out"), "<Control>minus",
            N_("Shrink the font"), on_view_zoom_out },
        { "ViewZoomReset", Stock.ZOOM_100, N_("_Reset Zoom"), "<Control>0",
            N_("Reset the size of the font"), on_view_zoom_reset },

        // Search
        { "Search", null, N_("_Search") },
        { "SearchFind", Stock.FIND, null, null,
            N_("Search for text"), on_search_find },
        { "SearchReplace", Stock.FIND_AND_REPLACE, null, null,
            N_("Search for and replace text"), on_search_replace },
        { "SearchGoToLine", Stock.JUMP_TO, N_("_Go to Line..."), "<Control>G",
            N_("Go to a specific line"), on_search_goto_line },

        // Build
        { "Build", null, N_("_Build") },
        { "BuildClean", Stock.CLEAR, N_("Cleanup Build _Files"), null,
            N_("Clean-up build files (*.aux, *.log, *.out, *.toc, etc)"),
            on_build_clean },
        { "BuildStopExecution", Stock.STOP, N_("_Stop Execution"), null,
            N_("Stop Execution"), on_build_stop_execution },
        { "BuildViewLog", "view_log", N_("View _Log"), null,
            N_("View Log"), on_build_view_log },

        // Documents
        { "Documents", null, N_("_Documents") },
        { "DocumentsSaveAll", Stock.SAVE, N_("_Save All"), "<Shift><Control>L",
            N_("Save all open files"), on_documents_save_all },
        { "DocumentsCloseAll", Stock.CLOSE, N_("_Close All"), "<Shift><Control>W",
            N_("Close all open files"), on_documents_close_all },
        { "DocumentsPrevious", Stock.GO_BACK, N_("_Previous Document"),
            "<Control><Alt>Page_Up", N_("Activate previous document"),
            on_documents_previous },
        { "DocumentsNext", Stock.GO_FORWARD, N_("_Next Document"),
            "<Control><Alt>Page_Down", N_("Activate next document"),
            on_documents_next },
        { "DocumentsMoveToNewWindow", null, N_("_Move to New Window"), null,
            N_("Move the current document to a new window"),
            on_documents_move_to_new_window },

        // Projects
        { "Projects", null, N_("_Projects") },
        { "ProjectsNew", Stock.NEW, N_("_New Project"), null,
            N_("Create a new project"), on_projects_new },
        { "ProjectsConfigCurrent", Stock.PROPERTIES, N_("_Configure Current Project"),
            null, N_("Change the main file of the current project"),
            on_projects_config_current },
        { "ProjectsManage", Stock.PREFERENCES, N_("_Manage Projects"), null,
            N_("Manage Projects"), on_projects_manage },

        // Structure
        { "Structure", null, N_("S_tructure") },
        { "StructureCut", Stock.CUT, null, "",
            N_("Cut the selected structure item"), on_structure_cut },
        { "StructureCopy", Stock.COPY, null, "",
            N_("Copy the selected structure item"), on_structure_copy },
        { "StructureDelete", Stock.DELETE, null, "",
            N_("Delete the selected structure item"), on_structure_delete },
        { "StructureSelect", Stock.SELECT_ALL, N_("_Select"), "",
            N_("Select the contents of the selected structure item"),
            on_structure_select },
        { "StructureComment", null, N_("_Comment"), null,
            N_("Comment the selected structure item"), on_structure_comment },
        { "StructureShiftLeft", Stock.GO_BACK, N_("Shift _Left"), "",
            N_("Shift the selected structure item to the left (e.g. section → chapter)"),
            on_structure_shift_left },
        { "StructureShiftRight", Stock.GO_FORWARD, N_("Shift _Right"), "",
            N_("Shift the selected structure item to the right (e.g. chapter → section)"),
            on_structure_shift_right },

        // Help
        { "Help", null, N_("_Help") },
        { "HelpContents", Stock.HELP, N_("_Contents"), "<Release>F1",
            N_("Open the LaTeXila documentation"), on_help_contents },
        { "HelpLatexReference", null, N_("_LaTeX Reference"), null,
            N_("The Kile LaTeX Reference"), on_help_latex_reference },
        { "HelpAbout", Stock.ABOUT, null, null,
            N_("About LaTeXila"), on_about_dialog }
    };

    private const ToggleActionEntry[] toggle_action_entries =
    {
        { "EditSpellChecking", Stock.SPELL_CHECK, null, "",
            N_("Activate or disable the spell checking"), on_spell_checking },
        { "ViewMainToolbar", null, N_("_Main Toolbar"), null,
            N_("Show or hide the main toolbar"), null },
        // Translators: "Edit" here is an adjective.
        { "ViewEditToolbar", null, N_("_Edit Toolbar"), null,
            N_("Show or hide the edit toolbar"), null },
        { "ViewSidePanel", null, N_("_Side panel"), "<Release>F12",
            N_("Show or hide the side panel"), null },
        { "ViewBottomPanel", null, N_("_Bottom panel"), null,
            N_("Show or hide the bottom panel"), null },
        { "BuildShowWarnings", Stock.DIALOG_WARNING, N_("Show _Warnings"), null,
            N_("Show Warnings"), null },
        { "BuildShowBadBoxes", "badbox", N_("Show _Bad Boxes"), null,
            N_("Show Bad Boxes"), null }
    };

    private string file_chooser_current_folder = Environment.get_home_dir ();
    private DocumentsPanel documents_panel;
    private CustomStatusbar statusbar;
    private GotoLine goto_line;
    private SearchAndReplace search_and_replace;
    private BuildView _build_view;
    private Toolbar _main_toolbar;
    private Toolbar _edit_toolbar;
    private SidePanel _side_panel;
    private SymbolsView _symbols;
    private FileBrowser file_browser;
    private Structure _structure;
    private Paned main_hpaned;
    private Paned vpaned;

    private UIManager ui_manager;
    private Gtk.ActionGroup action_group;
    private Gtk.ActionGroup latex_action_group;
    private Gtk.ActionGroup documents_list_action_group;
    private Gtk.ActionGroup build_tools_action_group;
    private uint documents_list_menu_ui_id;
    private uint build_tools_menu_ui_id;
    private BuildToolRunner build_tool_runner;

    // context id for the statusbar
    private uint tip_message_cid;

    public DocumentTab? active_tab
    {
        get
        {
            if (documents_panel == null || documents_panel.get_n_pages () == 0)
                return null;
            return documents_panel.active_tab;
        }

        set
        {
            int n = documents_panel.page_num (value);
            if (n != -1)
                documents_panel.set_current_page (n);
        }
    }

    public DocumentView? active_view
    {
        get
        {
            if (active_tab == null)
                return null;
            return active_tab.view;
        }
    }

    public Document? active_document
    {
        get
        {
            if (active_tab == null)
                return null;
            return active_tab.document;
        }
    }

    public MainWindow ()
    {
        this.title = "LaTeXila";

        /* restore window state */
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");

        int w, h;
        settings.get ("size", "(ii)", out w, out h);
        set_default_size (w, h);

        Gdk.WindowState state = (Gdk.WindowState) settings.get_int ("state");
        if (Gdk.WindowState.MAXIMIZED in state)
            maximize ();
        else
            unmaximize ();

        if (Gdk.WindowState.STICKY in state)
            stick ();
        else
            unstick ();

        /* components */
        initialize_menubar_and_toolbar ();
        Widget menu = ui_manager.get_widget ("/MainMenu");

        _main_toolbar = ui_manager.get_widget ("/MainToolbar") as Toolbar;
        _main_toolbar.set_style (ToolbarStyle.ICONS);
        StyleContext main_toolbar_context = _main_toolbar.get_style_context ();
        main_toolbar_context.add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        setup_toolbar_open_button (_main_toolbar);

        _edit_toolbar = ui_manager.get_widget ("/EditToolbar") as Toolbar;
        _edit_toolbar.set_style (ToolbarStyle.ICONS);

        Toolbar build_toolbar = (Toolbar) ui_manager.get_widget ("/BuildToolbar");
        build_toolbar.set_style (ToolbarStyle.ICONS);
        build_toolbar.set_icon_size (IconSize.MENU);
        build_toolbar.set_orientation (Orientation.VERTICAL);

        documents_panel = new DocumentsPanel (this);
        documents_panel.right_click.connect ((event) =>
        {
            Gtk.Menu popup_menu = ui_manager.get_widget ("/NotebookPopup") as Gtk.Menu;
            popup_menu.popup (null, null, null, event.button, event.time);
        });

        statusbar = new CustomStatusbar ();
        tip_message_cid = statusbar.get_context_id ("tip_message");
        goto_line = new GotoLine (this);
        search_and_replace = new SearchAndReplace (this);

        // bottom panel
        Gtk.Action action_stop_exec = action_group.get_action ("BuildStopExecution");
        action_stop_exec.set_sensitive (false);

        _build_view = new BuildView (this);

        BottomPanel bottom_panel = new BottomPanel (_build_view, build_toolbar);

        ToggleAction action_bottom_panel =
            action_group.get_action ("ViewBottomPanel") as ToggleAction;

        bottom_panel.bind_property ("visible", action_bottom_panel, "active",
            BindingFlags.BIDIRECTIONAL);

        // side panel
        _side_panel = new SidePanel ();

        _symbols = new SymbolsView (this);
        _side_panel.add_component (_("Symbols"), "symbol_greek", _symbols);

        file_browser = new FileBrowser (this);
        _side_panel.add_component (_("File Browser"), Stock.OPEN, file_browser);

        _structure = new Structure (this, ui_manager);
        _side_panel.add_component (_("Structure"), Stock.INDEX, _structure);

        _side_panel.restore_state ();

        /* signal handlers */

        delete_event.connect (() =>
        {
            on_quit ();

            // the destroy signal is not emitted
            return true;
        });

        documents_panel.page_added.connect (() =>
        {
            int nb_pages = documents_panel.get_n_pages ();

            // actions for which there must be 1 document minimum
            if (nb_pages == 1)
                set_file_actions_sensitivity (true);

            // actions for which there must be 2 documents minimum
            else if (nb_pages == 2)
                set_documents_move_to_new_window_sensitivity (true);

            update_documents_list_menu ();
        });

        documents_panel.page_removed.connect (() =>
        {
            int nb_pages = documents_panel.get_n_pages ();

            // actions for which there must be 1 document minimum
            if (nb_pages == 0)
            {
                statusbar.set_cursor_position (-1, -1);
                set_file_actions_sensitivity (false);
                goto_line.hide ();
                search_and_replace.hide ();

                notify_property ("active-tab");
                notify_property ("active-document");
                notify_property ("active-view");
            }

            // actions for which there must be 2 documents minimum
            else if (nb_pages == 1)
                set_documents_move_to_new_window_sensitivity (false);

            my_set_title ();
            update_documents_list_menu ();
        });

        documents_panel.switch_page.connect ((pg, page_num) =>
        {
            set_undo_sensitivity ();
            set_redo_sensitivity ();
            update_next_prev_doc_sensitivity ();
            update_build_tools_sensitivity ();
            update_config_project_sensitivity ();
            my_set_title ();
            update_cursor_position_statusbar ();

            /* activate the right item in the documents menu */
            string action_name = @"Tab_$page_num";
            RadioAction? action =
                (RadioAction) documents_list_action_group.get_action (action_name);

            // sometimes the action doesn't exist yet, and the proper action is set
            // active during the documents list menu creation
            if (action != null)
            {
                // If we don't disconnect the signal, the switch_page signal is called
                // 2 times.
                action.activate.disconnect (documents_list_menu_activate);
                action.set_active (true);
                action.activate.connect (documents_list_menu_activate);
            }

            notify_property ("active-tab");
            notify_property ("active-document");
            notify_property ("active-view");
        });

        documents_panel.page_reordered.connect (() =>
        {
            update_next_prev_doc_sensitivity ();
            update_documents_list_menu ();
        });

        // hide completion calltip
        notify["active-tab"].connect (() =>
        {
            CompletionProvider provider = CompletionProvider.get_default ();
            provider.hide_calltip_window ();
        });

        // hide completion calltip
        focus_out_event.connect (() =>
        {
            CompletionProvider provider = CompletionProvider.get_default ();
            provider.hide_calltip_window ();

            // propagate the event further
            return false;
        });

        set_file_actions_sensitivity (false);
        set_documents_move_to_new_window_sensitivity (false);

        // drag-n-drop support of files
        Gtk.drag_dest_set (this, DestDefaults.ALL, {}, Gdk.DragAction.COPY);
        Gtk.drag_dest_add_uri_targets (this);
        drag_data_received.connect ((dc, x, y, selection_data, info, time) =>
        {
            Latexila app = Latexila.get_instance ();

            File[] files = {};
            foreach (string uri in selection_data.get_uris ())
            {
                if (0 < uri.length)
                    files += File.new_for_uri (uri);
            }

            app.open_documents (files);
            Gtk.drag_finish (dc, true, true, time);
        });

        // spell checking
        ToggleAction spell_checking_action =
            action_group.get_action ("EditSpellChecking") as ToggleAction;

        GLib.Settings editor_settings =
            new GLib.Settings ("org.gnome.latexila.preferences.editor");

        editor_settings.bind ("spell-checking", spell_checking_action, "active",
            SettingsBindFlags.DEFAULT);

        /* packing widgets */
        Grid main_vgrid = new Grid ();
        main_vgrid.orientation = Orientation.VERTICAL;

        main_vgrid.add (menu);
        main_vgrid.add (_main_toolbar);
        main_vgrid.add (_edit_toolbar);

        main_vgrid.show ();
        menu.show_all ();
        _main_toolbar.show_all ();

        // main horizontal pane
        // left: side panel (symbols, file browser, ...)
        // right: documents panel, search and replace, log zone, ...
        main_hpaned = new Paned (Orientation.HORIZONTAL);
        main_hpaned.set_position (settings.get_int ("side-panel-size"));
        main_vgrid.add (main_hpaned);
        main_hpaned.show ();

        // vgrid source view: documents panel, goto line, search and replace
        Grid vgrid_source_view = new Grid ();
        vgrid_source_view.orientation = Orientation.VERTICAL;
        vgrid_source_view.set_row_spacing (2);
        vgrid_source_view.add (documents_panel);
        vgrid_source_view.add (goto_line);
        vgrid_source_view.add (search_and_replace.get_widget ());

        vgrid_source_view.show ();
        documents_panel.show_all ();

        // vertical pane
        // top: vbox source view
        // bottom: log zone
        vpaned = new Paned (Orientation.VERTICAL);
        vpaned.set_position (settings.get_int ("vertical-paned-position"));

        // when we resize the window, the bottom panel keeps the same height
        vpaned.pack1 (vgrid_source_view, true, true);
        vpaned.pack2 (bottom_panel, false, true);

        main_hpaned.add1 (_side_panel);
        main_hpaned.add2 (vpaned);

        _side_panel.show ();
        vpaned.show ();

        main_vgrid.add (statusbar);
        statusbar.show_all ();

        add (main_vgrid);
        show ();
        show_or_hide_widgets ();
        show_or_hide_build_messages ();

        /* Force to show icons in the menu.
         * In the LaTeX and Math menu, icons are needed.
         */
        unowned Gtk.Settings gtk_settings = menu.get_settings ();
        gtk_settings.gtk_menu_images = true;
    }

    public Gee.List<Document> get_documents ()
    {
        Gee.List<Document> all_documents = new Gee.LinkedList<Document> ();
        int nb_documents = documents_panel.get_n_pages ();
        for (int i = 0 ; i < nb_documents ; i++)
        {
            DocumentTab tab = documents_panel.get_nth_page (i) as DocumentTab;
            all_documents.add (tab.document);
        }

        return all_documents;
    }

    public Gee.List<Document> get_unsaved_documents ()
    {
        Gee.List<Document> unsaved_documents = new Gee.LinkedList<Document> ();
        foreach (Document doc in get_documents ())
        {
            if (doc.get_modified ())
                unsaved_documents.add (doc);
        }

        return unsaved_documents;
    }

    public Gee.List<DocumentView> get_views ()
    {
        Gee.List<DocumentView> all_views = new Gee.LinkedList<Document> ();
        int nb_documents = documents_panel.get_n_pages ();
        for (int i = 0 ; i < nb_documents ; i++)
        {
            DocumentTab tab = documents_panel.get_nth_page (i) as DocumentTab;
            all_views.add (tab.view);
        }

        return all_views;
    }

    private void initialize_menubar_and_toolbar ()
    {
        // recent documents
        Gtk.Action recent_action = new RecentAction ("FileOpenRecent", _("Open _Recent"),
            _("Open recently used files"), "");
        configure_recent_chooser ((RecentChooser) recent_action);

        action_group = new Gtk.ActionGroup ("ActionGroup");
        action_group.set_translation_domain (Config.GETTEXT_PACKAGE);
        action_group.add_actions (action_entries, this);
        action_group.add_action (recent_action);
        action_group.add_toggle_actions (toggle_action_entries, this);

        latex_action_group = new LatexMenu (this);

        ui_manager = new UIManager ();
        ui_manager.insert_action_group (action_group, 0);
        ui_manager.insert_action_group (latex_action_group, 0);

        try
        {
            string path = Path.build_filename (Config.DATA_DIR, "ui", "ui.xml");
            ui_manager.add_ui_from_file (path);
        }
        catch (GLib.Error err)
        {
            error ("%s", err.message);
        }

        add_accel_group (ui_manager.get_accel_group ());

        // show tooltips in the statusbar
        ui_manager.connect_proxy.connect ((action, p) =>
        {
            if (p is Gtk.MenuItem)
            {
                Gtk.MenuItem proxy = p as Gtk.MenuItem;
                proxy.select.connect (on_menu_item_select);
                proxy.deselect.connect (on_menu_item_deselect);
            }
        });

        ui_manager.disconnect_proxy.connect ((action, p) =>
        {
            if (p is Gtk.MenuItem)
            {
                Gtk.MenuItem proxy = p as Gtk.MenuItem;
                proxy.select.disconnect (on_menu_item_select);
                proxy.deselect.disconnect (on_menu_item_deselect);
            }
        });

        // list of open documents menu
        documents_list_action_group = new Gtk.ActionGroup ("DocumentsListActions");
        ui_manager.insert_action_group (documents_list_action_group, 0);

        // build tools
        build_tools_action_group = new Gtk.ActionGroup ("BuildToolsActions");
        ui_manager.insert_action_group (build_tools_action_group, 0);
        update_build_tools_menu ();

        BuildTools build_tools = BuildTools.get_default ();
        build_tools.modified.connect (() => update_build_tools_menu ());
    }

    private void on_menu_item_select (Gtk.MenuItem proxy)
    {
        Gtk.Action action = proxy.get_related_action ();
        return_if_fail (action != null);
        if (action.tooltip != null)
            statusbar.push (tip_message_cid, action.tooltip);
    }

    private void on_menu_item_deselect (Gtk.MenuItem proxy)
    {
        statusbar.pop (tip_message_cid);
    }

    private void show_or_hide_widgets ()
    {
        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.preferences.ui");

        /* main toolbar */
        ToggleAction action = action_group.get_action ("ViewMainToolbar") as ToggleAction;

        _main_toolbar.bind_property ("visible", action, "active",
            BindingFlags.BIDIRECTIONAL);

        action.active = settings.get_boolean ("main-toolbar-visible");

        /* edit toolbar */
        action = action_group.get_action ("ViewEditToolbar") as ToggleAction;

        _edit_toolbar.bind_property ("visible", action, "active",
            BindingFlags.BIDIRECTIONAL);

        action.active = settings.get_boolean ("edit-toolbar-visible");

        /* side panel */
        action = action_group.get_action ("ViewSidePanel") as ToggleAction;

        _side_panel.bind_property ("visible", action, "active",
            BindingFlags.BIDIRECTIONAL);

        action.active = settings.get_boolean ("side-panel-visible");

        /* bottom panel */
        action = action_group.get_action ("ViewBottomPanel") as ToggleAction;
        action.active = settings.get_boolean ("bottom-panel-visible");
    }

    private void show_or_hide_build_messages ()
    {
        ToggleAction action_warnings =
            action_group.get_action ("BuildShowWarnings") as ToggleAction;

        ToggleAction action_badboxes =
            action_group.get_action ("BuildShowBadBoxes") as ToggleAction;

        _build_view.bind_property ("show-warnings", action_warnings, "active",
            BindingFlags.BIDIRECTIONAL);

        _build_view.bind_property ("show-badboxes", action_badboxes, "active",
            BindingFlags.BIDIRECTIONAL);

        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.preferences.ui");

        action_warnings.active = settings.get_boolean ("show-build-warnings");
        action_badboxes.active = settings.get_boolean ("show-build-badboxes");
    }

    public DocumentTab? open_document (File location, bool jump_to = true)
    {
        /* check if the document is already opened */
        foreach (Window window in Latexila.get_instance ().get_windows ())
        {
            MainWindow w = window as MainWindow;

            foreach (Document doc in w.get_documents ())
            {
                if (doc.location == null || ! location.equal (doc.location))
                    continue;

                /* the document is already opened in this window */
                if (this == w)
                {
                    if (jump_to)
                        active_tab = doc.tab;
                    return doc.tab;
                }

                /* the document is already opened in another window */
                DocumentTab tab = create_tab_from_location (location, jump_to);
                tab.document.readonly = true;
                string primary_msg =
                    _("This file (%s) is already opened in another LaTeXila window.")
                    .printf (location.get_parse_name ());
                string secondary_msg = _("LaTeXila opened this instance of the file in a non-editable way. Do you want to edit it anyway?");
                InfoBar infobar = tab.add_message (primary_msg, secondary_msg,
                    MessageType.WARNING);
                infobar.add_button (_("Edit Anyway"), ResponseType.YES);
                infobar.add_button (_("Don't Edit"), ResponseType.NO);
                infobar.response.connect ((response_id) =>
                {
                    if (response_id == ResponseType.YES)
                        tab.document.readonly = false;
                    infobar.destroy ();
                    tab.view.grab_focus ();
                });
                return tab;
            }
        }

        return create_tab_from_location (location, jump_to);
    }

    public DocumentTab? create_tab (bool jump_to)
    {
        DocumentTab tab = new DocumentTab ();
        return process_create_tab (tab, jump_to);
    }

    public DocumentTab? create_tab_from_location (File location, bool jump_to)
    {
        DocumentTab tab = new DocumentTab.from_location (location);
        return process_create_tab (tab, jump_to);
    }

    public void create_tab_with_view (DocumentView view)
    {
        DocumentTab tab = new DocumentTab.with_view (view);
        process_create_tab (tab, true);
    }

    private DocumentTab? process_create_tab (DocumentTab? tab, bool jump_to)
    {
        if (tab == null)
            return null;

        tab.close_document.connect (() => { close_tab (tab); });

        /* sensitivity of undo and redo */
        tab.document.notify["can-undo"].connect (() =>
        {
            if (tab != active_tab)
                return;
            set_undo_sensitivity ();
        });

        tab.document.notify["can-redo"].connect (() =>
        {
            if (tab != active_tab)
                return;
            set_redo_sensitivity ();
        });

        /* sensitivity of cut/copy/delete */
        tab.document.notify["has-selection"].connect (() =>
        {
            if (tab != active_tab)
                return;
            selection_changed ();
        });

        tab.document.notify["location"].connect (() =>
        {
            sync_name (tab);
            update_build_tools_sensitivity ();
        });

        tab.document.notify["project-id"].connect (() =>
        {
            update_build_tools_sensitivity ();
        });

        tab.document.modified_changed.connect (() => sync_name (tab));
        tab.document.notify["readonly"].connect (() => sync_name (tab));
        tab.document.cursor_moved.connect (update_cursor_position_statusbar);

        tab.show ();

        // add the tab at the end of the notebook
        documents_panel.add_tab (tab, -1, jump_to);

        set_undo_sensitivity ();
        set_redo_sensitivity ();
        selection_changed ();

        if (! this.get_visible ())
            this.present ();

        return tab;
    }

    // return true if the tab was closed
    public bool close_tab (DocumentTab tab, bool force_close = false)
    {
        /* If document not saved
         * Ask the user if he wants to save the file, or close without saving, or cancel
         */
        if (! force_close && tab.document.get_modified ())
        {
            Dialog dialog = new MessageDialog (this,
                DialogFlags.DESTROY_WITH_PARENT,
                MessageType.QUESTION,
                ButtonsType.NONE,
                _("Save changes to document \"%s\" before closing?"),
                tab.label_text);

            dialog.add_buttons (_("Close without Saving"), ResponseType.CLOSE,
                Stock.CANCEL, ResponseType.CANCEL);

            if (tab.document.location == null)
                dialog.add_button (Stock.SAVE_AS, ResponseType.ACCEPT);
            else
                dialog.add_button (Stock.SAVE, ResponseType.ACCEPT);

            while (true)
            {
                int res = dialog.run ();
                // Close without Saving
                if (res == ResponseType.CLOSE)
                    break;

                // Save or Save As
                else if (res == ResponseType.ACCEPT)
                {
                    if (save_document (tab.document, false))
                        break;
                    continue;
                }

                // Cancel
                else
                {
                    dialog.destroy ();
                    return false;
                }
            }

            dialog.destroy ();
        }

        documents_panel.remove_tab (tab);
        return true;
    }

    public DocumentTab? get_tab_from_location (File location)
    {
        foreach (Document doc in get_documents ())
        {
            if (location.equal (doc.location))
                return doc.tab;
        }

        // not found
        return null;
    }

    private void sync_name (DocumentTab tab)
    {
        if (tab == active_tab)
            my_set_title ();

        // sync the item in the documents list menu
        int page_num = documents_panel.page_num (tab);
        string action_name = @"Tab_$page_num";
        Gtk.Action action = documents_list_action_group.get_action (action_name);
        return_if_fail (action != null);
        action.label = tab.get_name ().replace ("_", "__");
        action.tooltip = tab.get_menu_tip ();
    }

    private void my_set_title ()
    {
        if (active_tab == null)
        {
            this.title = "LaTeXila";
            return;
        }

        uint max_title_length = 100;
        string title = null;
        string dirname = null;

        File loc = active_document.location;
        if (loc == null)
            title = active_document.get_short_name_for_display ();
        else
        {
            string basename = loc.get_basename ();
            if (basename.length > max_title_length)
                title = Utils.str_middle_truncate (basename, max_title_length);
            else
            {
                title = basename;
                dirname = Utils.str_middle_truncate (
                    Utils.get_dirname_for_display (loc),
                    (uint) long.max (20, max_title_length - basename.length));
            }
        }

        this.title = (active_document.get_modified () ? "*" : "") +
                     title +
                     (active_document.readonly ? " [" + _("Read-Only") + "]" : "") +
                     (dirname != null ? " (" + dirname + ")" : "") +
                     " - LaTeXila";
    }

    // return true if the document has been saved
    public bool save_document (Document doc, bool force_save_as)
    {
        if (! force_save_as && doc.location != null)
        {
            doc.save ();
            return true;
        }

        FileChooserDialog file_chooser = new FileChooserDialog (_("Save File"), this,
            FileChooserAction.SAVE,
            Stock.CANCEL, ResponseType.CANCEL,
            Stock.SAVE, ResponseType.ACCEPT,
            null);

        if (doc.location == null)
            file_chooser.set_current_name (doc.tab.label_text + ".tex");
        else
            file_chooser.set_current_name (doc.tab.label_text);

        if (this.file_chooser_current_folder != null)
            file_chooser.set_current_folder (this.file_chooser_current_folder);

        if (doc.location != null)
        {
            try
            {
                // override the current name and current folder
                file_chooser.set_file (doc.location);
            }
            catch (Error e) {}
        }

        while (file_chooser.run () == ResponseType.ACCEPT)
        {
            File file = file_chooser.get_file ();

            /* if the file exists, ask the user if the file can be replaced */
            if (file.query_exists ())
            {
                MessageDialog confirmation = new MessageDialog (this,
                    DialogFlags.DESTROY_WITH_PARENT,
                    MessageType.QUESTION,
                    ButtonsType.NONE,
                    _("A file named \"%s\" already exists. Do you want to replace it?"),
                    file.get_basename ());

                confirmation.add_button (Stock.CANCEL, ResponseType.CANCEL);

                Button button_replace = new Button.with_label (_("Replace"));
                Image icon = new Image.from_stock (Stock.SAVE_AS, IconSize.BUTTON);
                button_replace.set_image (icon);
                confirmation.add_action_widget (button_replace, ResponseType.YES);
                button_replace.show ();

                int response = confirmation.run ();
                confirmation.destroy ();

                if (response != ResponseType.YES)
                    continue;
            }

            doc.location = file;
            break;
        }

        this.file_chooser_current_folder = file_chooser.get_current_folder ();
        file_chooser.destroy ();

        if (doc.location != null)
        {
            // force saving
            doc.save (false, true);
            return true;
        }
        return false;
    }

    // return true if all the documents are closed
    private bool close_all_documents ()
    {
        Gee.List<Document> unsaved_documents = get_unsaved_documents ();

        /* no unsaved document */
        if (unsaved_documents.size == 0)
        {
            documents_panel.remove_all_tabs ();
            return true;
        }

        /* only one unsaved document */
        else if (unsaved_documents.size == 1)
        {
            Document doc = unsaved_documents.first ();
            active_tab = doc.tab;
            if (close_tab (doc.tab))
            {
                documents_panel.remove_all_tabs ();
                return true;
            }
        }

        /* more than one unsaved document */
        else
        {
            Dialogs.close_several_unsaved_documents (this, unsaved_documents);
            if (documents_panel.get_n_pages () == 0)
                return true;
        }

        return false;
    }

    public void remove_all_tabs ()
    {
        documents_panel.remove_all_tabs ();
    }

    private void update_cursor_position_statusbar ()
    {
        TextIter iter;
        active_document.get_iter_at_mark (out iter, active_document.get_insert ());
        int row = (int) iter.get_line ();
        int col = (int) active_view.get_visual_column (iter);
        statusbar.set_cursor_position (row + 1, col + 1);
    }

    private void setup_toolbar_open_button (Toolbar toolbar)
    {
        RecentManager recent_manager = RecentManager.get_default ();
        Widget toolbar_recent_menu = new RecentChooserMenu.for_manager (recent_manager);
        configure_recent_chooser ((RecentChooser) toolbar_recent_menu);

        MenuToolButton open_button = new MenuToolButton.from_stock (Stock.OPEN);
        open_button.set_menu (toolbar_recent_menu);
        open_button.set_tooltip_text (_("Open a file"));
        open_button.set_arrow_tooltip_text (_("Open a recently used file"));

        Gtk.Action action = action_group.get_action ("FileOpen");
        open_button.set_related_action (action);

        toolbar.insert (open_button, 1);
    }

    private void configure_recent_chooser (RecentChooser recent_chooser)
    {
        recent_chooser.set_local_only (false);
        recent_chooser.set_sort_type (RecentSortType.MRU);

        RecentFilter filter = new RecentFilter ();
        filter.add_application (Config.APP_NAME);
        recent_chooser.set_filter (filter);

        recent_chooser.item_activated.connect ((chooser) =>
        {
            string uri = chooser.get_current_uri ();
            open_document (File.new_for_uri (uri));
        });
    }

    public void save_state ()
    {
        /* state of the window */
        GLib.Settings settings_window =
            new GLib.Settings ("org.gnome.latexila.state.window");
        Gdk.WindowState state = get_window ().get_state ();
        settings_window.set_int ("state", state);

        // get width and height of the window
        int w, h;
        get_size (out w, out h);

        // If window is maximized, store sizes that are a bit smaller than full screen,
        // else making window non-maximized the next time will have no effect.
        if (Gdk.WindowState.MAXIMIZED in state)
        {
            w -= 100;
            h -= 100;
        }

        settings_window.set ("size", "(ii)", w, h);

        settings_window.set_int ("side-panel-size", main_hpaned.get_position ());
        settings_window.set_int ("vertical-paned-position", vpaned.get_position ());

        _structure.save_state ();

        /* ui preferences */
        GLib.Settings settings_ui =
            new GLib.Settings ("org.gnome.latexila.preferences.ui");

        // We don't bind this settings to the toggle action because when we change the
        // setting it must be applied only on the current window and not all windows.

        ToggleAction action = (ToggleAction) action_group.get_action ("ViewMainToolbar");
        settings_ui.set_boolean ("main-toolbar-visible", action.active);

        action = (ToggleAction) action_group.get_action ("ViewEditToolbar");
        settings_ui.set_boolean ("edit-toolbar-visible", action.active);

        action = (ToggleAction) action_group.get_action ("ViewSidePanel");
        settings_ui.set_boolean ("side-panel-visible", action.active);

        action = (ToggleAction) action_group.get_action ("ViewBottomPanel");
        settings_ui.set_boolean ("bottom-panel-visible", action.active);

        action = (ToggleAction) action_group.get_action ("BuildShowWarnings");
        settings_ui.set_boolean ("show-build-warnings", action.active);

        action = (ToggleAction) action_group.get_action ("BuildShowBadBoxes");
        settings_ui.set_boolean ("show-build-badboxes", action.active);
    }

    private void move_tab_to_new_window (DocumentTab tab)
    {
        MainWindow new_window = Latexila.get_instance ().create_window ();
        DocumentView view = tab.view;
        documents_panel.remove_tab (tab);

        // we create a new tab with the same view, so we avoid headache with signals
        // the user see nothing, muahahaha
        new_window.create_tab_with_view (view);
    }

    public void update_build_tools_menu ()
    {
        return_if_fail (build_tools_action_group != null);

        if (build_tools_menu_ui_id != 0)
            ui_manager.remove_ui (build_tools_menu_ui_id);

        foreach (Gtk.Action action in build_tools_action_group.list_actions ())
        {
            action.activate.disconnect (build_tools_menu_activate);
            build_tools_action_group.remove_action (action);
        }

        BuildTools build_tools = BuildTools.get_default ();

        uint id = build_tools.is_empty () ? 0 : ui_manager.new_merge_id ();

        int i = 0;
        int j = 0;
        foreach (BuildTool build_tool in build_tools)
        {
            if (! build_tool.enabled)
            {
                i++;
                continue;
            }

            string action_name = @"BuildTool_$i";
            Gtk.Action action = new Gtk.Action (action_name, build_tool.label,
                build_tool.description, build_tool.icon);

            // F2 -> F11
            // (F1 = help, F12 = stop execution)
            string accel = j < 10 ? "<Release>F%d".printf (j + 2) : null;

            build_tools_action_group.add_action_with_accel (action, accel);
            action.activate.connect (build_tools_menu_activate);

            ui_manager.add_ui (id, "/MainMenu/BuildMenu/BuildToolsPlaceholder",
                action_name, action_name, UIManagerItemType.MENUITEM, false);
            ui_manager.add_ui (id, "/MainToolbar/BuildToolsPlaceholder2",
                action_name, action_name, UIManagerItemType.TOOLITEM, false);

            i++;
            j++;
        }

        build_tools_menu_ui_id = id;
        update_build_tools_sensitivity ();
    }

    private void build_tools_menu_activate (Gtk.Action action)
    {
        return_if_fail (active_tab != null);

        string[] _name = action.name.split ("_");
        int tool_index = int.parse (_name[1]);

        BuildTool? tool = BuildTools.get_default ().get_by_id (tool_index);
        return_if_fail (tool != null);

        if (! tool.has_jobs ())
            return_if_fail (active_document.location != null);

        _build_view.show ();

        // save the document if commands are executed
        if (tool.has_jobs ())
        {
            if (active_document.location == null)
            {
                bool tmp_location_set = active_document.set_tmp_location ();
                return_if_fail (tmp_location_set);
            }

            int project_id = active_document.project_id;

            if (project_id == -1)
                active_document.save ();

            // save all the documents belonging to the project
            else
            {
                Gee.List<Document> docs = Latexila.get_instance ().get_documents ();
                foreach (Document doc in docs)
                {
                    if (doc.project_id == project_id)
                        doc.save ();
                }
            }

            // Ensure that the files are correctly saved before the execution.
            Utils.flush_queue ();
        }

        Gtk.Action action_stop_exec = action_group.get_action ("BuildStopExecution");
        action_stop_exec.sensitive = true;

        File main_file = active_document.get_main_file ();
        build_tool_runner = new BuildToolRunner (tool, main_file, _build_view);

        build_tool_runner.finished.connect (() =>
        {
            action_stop_exec.sensitive = false;

            // Refresh the file browser when the execution is finished.
            // TODO It would be better if the file browser could detect file updates.
            if (tool.has_jobs ())
                file_browser.refresh_for_document (active_document);
        });
    }

    private void update_documents_list_menu ()
    {
        return_if_fail (documents_list_action_group != null);

        if (documents_list_menu_ui_id != 0)
            ui_manager.remove_ui (documents_list_menu_ui_id);

        foreach (Gtk.Action action in documents_list_action_group.list_actions ())
        {
            action.activate.disconnect (documents_list_menu_activate);
            documents_list_action_group.remove_action (action);
        }

        int n = documents_panel.get_n_pages ();
        uint id = n > 0 ? ui_manager.new_merge_id () : 0;

        unowned SList<RadioAction> group = null;

        for (int i = 0 ; i < n ; i++)
        {
            DocumentTab tab = (DocumentTab) documents_panel.get_nth_page (i);
            string action_name = @"Tab_$i";
            string name = tab.get_name ().replace ("_", "__");
            string tip = tab.get_menu_tip ();
            string accel = i < 10 ? "<alt>%d".printf ((i + 1) % 10) : null;

            RadioAction action = new RadioAction (action_name, name, tip, null, i);
            if (group != null)
                action.set_group (group);

            /* group changes each time we add an action, so it must be updated */
            group = action.get_group ();

            documents_list_action_group.add_action_with_accel (action, accel);

            action.activate.connect (documents_list_menu_activate);

            ui_manager.add_ui (id, "/MainMenu/DocumentsMenu/DocumentsListPlaceholder",
                action_name, action_name, UIManagerItemType.MENUITEM, false);

            if (tab == active_tab)
                action.set_active (true);
        }

        documents_list_menu_ui_id = id;
    }

    private void documents_list_menu_activate (Gtk.Action action)
    {
        RadioAction radio_action = (RadioAction) action;
        if (! radio_action.get_active ())
            return;

        documents_panel.set_current_page (radio_action.get_current_value ());
    }


    /*****************************
     *    ACTIONS SENSITIVITY    *
     *****************************/

    private void set_file_actions_sensitivity (bool sensitive)
    {
        // actions that must be insensitive if the notebook is empty
        string[] file_actions =
        {
            "FileSave", "FileSaveAs", "FileClose", "EditUndo", "EditRedo", "EditCut",
            "EditCopy", "EditPaste", "EditDelete", "EditSelectAll", "EditComment",
            "EditUncomment", "ViewZoomIn", "ViewZoomOut", "ViewZoomReset",
            "DocumentsSaveAll", "DocumentsCloseAll", "DocumentsPrevious", "DocumentsNext",
            "SearchFind", "SearchReplace", "SearchGoToLine", "BuildClean", "BuildViewLog",
            "ProjectsConfigCurrent", "FileCreateTemplate"
        };

        foreach (string file_action in file_actions)
        {
            Gtk.Action action = action_group.get_action (file_action);
            action.set_sensitive (sensitive);
        }

        latex_action_group.set_sensitive (sensitive);
        build_tools_action_group.set_sensitive (sensitive);
    }

    private void set_undo_sensitivity ()
    {
        if (active_tab != null)
        {
            Gtk.Action action = action_group.get_action ("EditUndo");
            action.set_sensitive (active_document.can_undo);
        }
    }

    private void set_redo_sensitivity ()
    {
        if (active_tab == null)
            return;

        Gtk.Action action = action_group.get_action ("EditRedo");
        action.set_sensitive (active_document.can_redo);
    }

    private void set_documents_move_to_new_window_sensitivity (bool sensitive)
    {
        Gtk.Action action = action_group.get_action ("DocumentsMoveToNewWindow");
        action.set_sensitive (sensitive);
    }

    private void update_next_prev_doc_sensitivity ()
    {
        if (active_tab == null)
            return;

        Gtk.Action action_previous = action_group.get_action ("DocumentsPrevious");
        Gtk.Action action_next = action_group.get_action ("DocumentsNext");

        int current_page = documents_panel.page_num (active_tab);
        action_previous.set_sensitive (current_page > 0);

        int nb_pages = documents_panel.get_n_pages ();
        action_next.set_sensitive (current_page < nb_pages - 1);
    }

    private void update_build_tools_sensitivity ()
    {
        Gtk.Action clean_action = action_group.get_action ("BuildClean");
        Gtk.Action view_log_action = action_group.get_action ("BuildViewLog");

        if (active_tab == null)
        {
            build_tools_action_group.set_sensitive (false);
            clean_action.set_sensitive (false);
            view_log_action.set_sensitive (false);
            return;
        }

        // we must set the _action group_ sensitive and then set the sensitivity for each
        // action of the action group
        build_tools_action_group.set_sensitive (true);

        bool is_tex = active_document.is_main_file_a_tex_file ();
        clean_action.set_sensitive (is_tex);
        view_log_action.set_sensitive (is_tex);

        bool unsaved_doc = active_document.location == null;
        string ext = "";
        if (! unsaved_doc)
        {
            string path = active_document.get_main_file ().get_parse_name ();
            ext = Utils.get_extension (path);
        }

        int tool_num = 0;
        foreach (BuildTool tool in BuildTools.get_default ())
        {
            if (! tool.enabled)
            {
                tool_num++;
                continue;
            }

            Gtk.Action action =
                build_tools_action_group.get_action (@"BuildTool_$tool_num");

            if (unsaved_doc)
                action.set_sensitive (tool.has_jobs ());
            else
            {
                string[] extensions = tool.extensions.split (" ");
                bool sensitive = tool.extensions.length == 0 || ext in extensions;
                action.set_sensitive (sensitive);
            }

            tool_num++;
        }
    }

    public void update_config_project_sensitivity ()
    {
        Gtk.Action action = action_group.get_action ("ProjectsConfigCurrent");
        action.set_sensitive (active_tab != null && active_document.project_id != -1);
    }

    private void selection_changed ()
    {
        if (active_tab != null)
        {
            bool has_selection = active_document.has_selection;

            // actions that must be insensitive if there is no selection
            string[] selection_actions = { "EditCut", "EditCopy", "EditDelete" };

            foreach (string selection_action in selection_actions)
            {
                Gtk.Action action = action_group.get_action (selection_action);
                action.set_sensitive (has_selection);
            }
        }
    }


    /*******************
     *    CALLBACKS
     ******************/

    /* File menu */

    public void on_file_new ()
    {
        new OpenTemplateDialog (this);
    }

    public void on_new_window ()
    {
        Latexila.get_instance ().create_window ();
    }

    public void on_file_open ()
    {
        FileChooserDialog file_chooser = new FileChooserDialog (_("Open Files"), this,
            FileChooserAction.OPEN,
            Stock.CANCEL, ResponseType.CANCEL,
            Stock.OPEN, ResponseType.ACCEPT,
            null);

        if (this.file_chooser_current_folder != null)
            file_chooser.set_current_folder (this.file_chooser_current_folder);

        file_chooser.select_multiple = true;

        // Filter: by default show only .tex and .bib files
        FileFilter latex_filter = new FileFilter ();
        latex_filter.set_filter_name (_("All LaTeX Files"));
        latex_filter.add_pattern ("*.tex");
        latex_filter.add_pattern ("*.bib");
        file_chooser.add_filter (latex_filter);

        // All files filter
        FileFilter all_files_filter = new FileFilter ();
        all_files_filter.set_filter_name (_("All Files"));
        all_files_filter.add_pattern ("*");
        file_chooser.add_filter (all_files_filter);

        SList<File> files_to_open = null;
        if (file_chooser.run () == ResponseType.ACCEPT)
            files_to_open = file_chooser.get_files ();

        this.file_chooser_current_folder = file_chooser.get_current_folder ();
        file_chooser.destroy ();

        // We open the files after closing the dialog, because open a lot of documents can
        // take some time (this is not async).
        bool jump_to = true;
        foreach (File file in files_to_open)
        {
            open_document (file, jump_to);
            jump_to = false;
        }
    }

    public void on_file_save ()
    {
        return_if_fail (active_tab != null);
        save_document (active_document, false);
    }

    public void on_file_save_as ()
    {
        return_if_fail (active_tab != null);
        save_document (active_document, true);
    }

    public void on_create_template ()
    {
        return_if_fail (active_tab != null);

        CreateTemplateDialog dialog = new CreateTemplateDialog (this);
        dialog.destroy ();
    }

    public void on_delete_template ()
    {
        DeleteTemplateDialog dialog = new DeleteTemplateDialog (this);
        dialog.destroy ();
    }

    public void on_file_close ()
    {
        return_if_fail (active_tab != null);
        close_tab (active_tab);
    }

    public void on_quit ()
    {
        // save documents list
        string[] list_uris = {};
        foreach (Document doc in get_documents ())
        {
            if (doc.location != null)
                list_uris += doc.location.get_uri ();
        }

        GLib.Settings settings = new GLib.Settings ("org.gnome.latexila.state.window");
        settings.set_strv ("documents", list_uris);

        if (close_all_documents ())
        {
            save_state ();
            destroy ();
        }
    }

    /* Edit menu */

    public void on_edit_undo ()
    {
        return_if_fail (active_tab != null);
        if (active_document.can_undo)
        {
            active_document.undo ();
            active_view.scroll_to_cursor ();
            active_view.grab_focus ();
        }
    }

    public void on_edit_redo ()
    {
        return_if_fail (active_tab != null);
        if (active_document.can_redo)
        {
            active_document.redo ();
            active_view.scroll_to_cursor ();
            active_view.grab_focus ();
        }
    }

    public void on_edit_cut ()
    {
        return_if_fail (active_tab != null);
        active_view.cut_selection ();
    }

    public void on_edit_copy ()
    {
        return_if_fail (active_tab != null);
        active_view.copy_selection ();
    }

    public void on_edit_paste ()
    {
        return_if_fail (active_tab != null);
        active_view.my_paste_clipboard ();
    }

    public void on_edit_delete ()
    {
        return_if_fail (active_tab != null);
        active_view.delete_selection ();
    }

    public void on_edit_select_all ()
    {
        return_if_fail (active_tab != null);
        active_view.my_select_all ();
    }

    public void on_edit_comment ()
    {
        return_if_fail (active_tab != null);
        active_document.comment_selected_lines ();
    }

    public void on_edit_uncomment ()
    {
        return_if_fail (active_tab != null);
        active_document.uncomment_selected_lines ();
    }

    public void on_spell_checking (Gtk.Action action)
    {
        bool activate = (action as ToggleAction).active;

        foreach (DocumentView view in get_views ())
        {
            if (activate)
                view.activate_spell_checking ();
            else
                view.disable_spell_checking ();
        }
    }

    public void on_open_preferences ()
    {
        PreferencesDialog.show_me (this);
    }

    /* View */

    public void on_view_zoom_in ()
    {
        return_if_fail (active_tab != null);
        active_view.enlarge_font ();
    }

    public void on_view_zoom_out ()
    {
        return_if_fail (active_tab != null);
        active_view.shrink_font ();
    }

    public void on_view_zoom_reset ()
    {
        return_if_fail (active_tab != null);
        active_view.set_font_from_settings ();
    }

    /* Search */

    public void on_search_find ()
    {
        return_if_fail (active_tab != null);
        search_and_replace.show_search ();
    }

    public void on_search_replace ()
    {
        return_if_fail (active_tab != null);
        search_and_replace.show_search_and_replace ();
    }

    public void on_search_goto_line ()
    {
        return_if_fail (active_tab != null);
        goto_line.show ();
    }

    /* Build */

    public void on_build_stop_execution ()
    {
        return_if_fail (build_tool_runner != null);
        build_tool_runner.abort ();
        _build_view.show ();
    }

    public void on_build_clean ()
    {
        return_if_fail (active_tab != null);

        CleanBuildFiles build_files = new CleanBuildFiles (this, active_document);

        if (build_files.clean ())
            file_browser.refresh_for_document (active_document);
    }

    public void on_build_view_log ()
    {
        return_if_fail (active_tab != null);
        return_if_fail (active_document.is_main_file_a_tex_file ());

        File mainfile = active_document.get_main_file ();
        File directory = mainfile.get_parent ();

        string basename = Utils.get_shortname (mainfile.get_basename ()) + ".log";
        File file = directory.get_child (basename);
        DocumentTab? tab = open_document (file);

        if (tab == null)
            warning ("Impossible to view log");
        else
            tab.document.readonly = true;
    }

    /* Documents */

    public void on_documents_save_all ()
    {
        return_if_fail (active_tab != null);
        foreach (Document doc in get_unsaved_documents ())
            doc.save ();
    }

    public void on_documents_close_all ()
    {
        return_if_fail (active_tab != null);
        close_all_documents ();
    }

    public void on_documents_previous ()
    {
        return_if_fail (active_tab != null);
        documents_panel.prev_page ();
    }

    public void on_documents_next ()
    {
        return_if_fail (active_tab != null);
        documents_panel.next_page ();
    }

    public void on_documents_move_to_new_window ()
    {
        return_if_fail (active_tab != null);
        move_tab_to_new_window (active_tab);
    }

    /* Projects */

    public void on_projects_new ()
    {
        ProjectDialogs.new_project (this);
    }

    public void on_projects_config_current ()
    {
        return_if_fail (active_tab != null);
        return_if_fail (active_document.project_id != -1);
        ProjectDialogs.configure_project (this, active_document.project_id);
    }

    public void on_projects_manage ()
    {
        ProjectDialogs.manage_projects (this);
    }

    /* Structure */

    public void on_structure_cut ()
    {
        return_if_fail (_structure != null);
        _structure.do_action (StructAction.CUT);
    }

    public void on_structure_copy ()
    {
        return_if_fail (_structure != null);
        _structure.do_action (StructAction.COPY);
    }

    public void on_structure_delete ()
    {
        return_if_fail (_structure != null);
        _structure.do_action (StructAction.DELETE);
    }

    public void on_structure_select ()
    {
        return_if_fail (_structure != null);
        _structure.do_action (StructAction.SELECT);
    }

    public void on_structure_comment ()
    {
        return_if_fail (_structure != null);
        _structure.do_action (StructAction.COMMENT);
    }

    public void on_structure_shift_left ()
    {
        return_if_fail (_structure != null);
        _structure.do_action (StructAction.SHIFT_LEFT);
    }

    public void on_structure_shift_right ()
    {
        return_if_fail (_structure != null);
        _structure.do_action (StructAction.SHIFT_RIGHT);
    }

    /* Help */

    public void on_help_contents ()
    {
        try
        {
            show_uri (this.get_screen (), "ghelp:latexila", Gdk.CURRENT_TIME);
        }
        catch (Error e)
        {
            warning ("Impossible to open the documentation: %s", e.message);
        }
    }

    public void on_help_latex_reference ()
    {
        try
        {
            string uri = Filename.to_uri (Path.build_filename (Config.DATA_DIR,
                "latexhelp.html", null));
            show_uri (this.get_screen (), uri, Gdk.CURRENT_TIME);
        }
        catch (Error e)
        {
            warning ("Impossible to open the LaTeX reference: %s", e.message);
        }
    }

    public void on_about_dialog ()
    {
        string comments =
            _("LaTeXila is an Integrated LaTeX Environment for the GNOME Desktop");
        string copyright = "Copyright (C) 2009-2012 Sébastien Wilmet";

        string website = "http://projects.gnome.org/latexila/";

        string[] authors =
        {
            "Sébastien Wilmet <sebastien.wilmet@gmail.com>",
            null
        };

        string[] artists =
        {
            "Ann Melnichuk <melnichu@qtp.ufl.edu>",
            "Eric Forgeot <e.forgeot@laposte.net>",
            "Sébastien Wilmet <sebastien.wilmet@gmail.com>",
            "The Kile Team http://kile.sourceforge.net/",
            "Gedit LaTeX Plugin http://live.gnome.org/Gedit/LaTeXPlugin",
            null
        };

        Gdk.Pixbuf logo = null;
        try
        {
            logo = new Gdk.Pixbuf.from_file (Config.DATA_DIR + "/images/app/logo.png");
        }
        catch (Error e)
        {
            warning ("Logo: %s", e.message);
        }

        show_about_dialog (this,
            "program-name", "LaTeXila",
            "version", Config.APP_VERSION,
            "authors", authors,
            "artists", artists,
            "comments", comments,
            "copyright", copyright,
            "license-type", License.GPL_3_0,
            "title", _("About LaTeXila"),
            "translator-credits", _("translator-credits"),
            "website", website,
            "logo", logo,
            null);
    }
}
