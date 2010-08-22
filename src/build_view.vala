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

public enum PartitionState
{
    RUNNING,
    SUCCEEDED,
    FAILED,
    ABORTED
}

public enum BuildMessageType
{
    ERROR, WARNING, BADBOX, OTHER
}

public struct BuildIssue
{
    public string message;
    public BuildMessageType message_type;
    public string? filename;
    public int start_line;
    public int end_line;
}

public class BuildView : HBox
{
    enum BuildInfo
    {
        ICON,
        MESSAGE,
        MESSAGE_TYPE,
        BASENAME,
        FILENAME,
        START_LINE,
        END_LINE,
        LINE,
        N_COLUMNS
    }

    /*
    public bool show_errors { get; set; }
    public bool show_warnings { get; set; }
    public bool show_badboxes { get; set; }
    */

    private unowned MainWindow main_window;
    private TreeStore store;
    private TreeView view;
    private unowned Action action_stop_execution;
    private unowned ToggleAction action_view_bottom_panel;
    private BuildToolRunner? runner = null;

    public BuildView (MainWindow main_window, Toolbar toolbar, Action stop_execution,
        ToggleAction view_bottom_panel)
    {
        this.main_window = main_window;
        this.action_stop_execution = stop_execution;
        stop_execution.set_sensitive (false);
        this.action_view_bottom_panel = view_bottom_panel;

        store = new TreeStore (BuildInfo.N_COLUMNS,
            typeof (string),    // icon (stock-id)
            typeof (string),    // message
            typeof (BuildMessageType),
            typeof (string),    // basename
            typeof (string),    // filename
            typeof (int),       // start line
            typeof (int),       // end line
            typeof (string)     // line (same as start line but for display)
        );

        /* create tree view */
        view = new TreeView.with_model (store);

        TreeViewColumn column_job = new TreeViewColumn ();
        column_job.title = _("Job");

        CellRendererPixbuf renderer_pixbuf = new CellRendererPixbuf ();
        column_job.pack_start (renderer_pixbuf, false);
        column_job.add_attribute (renderer_pixbuf, "stock-id", BuildInfo.ICON);

        CellRendererText renderer_text = new CellRendererText ();
        column_job.pack_start (renderer_text, true);
        column_job.add_attribute (renderer_text, "markup", BuildInfo.MESSAGE);

        view.append_column (column_job);

        view.insert_column_with_attributes (-1, _("File"), new CellRendererText (),
            "text", BuildInfo.BASENAME);
        view.insert_column_with_attributes (-1, _("Line"), new CellRendererText (),
            "text", BuildInfo.LINE);

        view.set_tooltip_column (BuildInfo.FILENAME);

        // selection
        TreeSelection select = view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);
        select.set_select_function (on_row_selection);

        // close button
        Button close_button = new Button ();
        close_button.relief = ReliefStyle.NONE;
        close_button.focus_on_click = false;
        //close_button.name = "my-close-button";
        close_button.tooltip_text = _("Hide panel");
        close_button.add (new Image.from_stock (STOCK_CLOSE, IconSize.MENU));
        close_button.clicked.connect (() =>
        {
            this.hide ();
            action_view_bottom_panel.active = false;
        });

        // with a scrollbar
        var sw = Utils.add_scrollbar (view);
        pack_start (sw);

        VBox vbox = new VBox (false, 0);
        vbox.pack_start (close_button, false, false);
        vbox.pack_start (toolbar);
        pack_start (vbox, false, false);
    }

    private bool on_row_selection (TreeSelection selection, TreeModel model,
        TreePath path, bool path_currently_selected)
    {
        TreeIter iter;
        if (model.get_iter (out iter, path))
        {
            BuildMessageType msg_type;
            string filename;
            int start_line, end_line;

            model.get (iter,
                BuildInfo.MESSAGE_TYPE, out msg_type,
                BuildInfo.FILENAME, out filename,
                BuildInfo.START_LINE, out start_line,
                BuildInfo.END_LINE, out end_line,
                -1);

            if (msg_type != BuildMessageType.OTHER && filename != null
                && filename.length > 0)
            {
                jump_to_file (filename, start_line, end_line);

                // the row is selected
                return true;
            }

            // maybe it's a parent, so we can show or hide its children
            else if (msg_type == BuildMessageType.OTHER)
            {
                if (model.iter_has_child (iter))
                {
                    if (view.is_row_expanded (path))
                        view.collapse_row (path);
                    else
                        view.expand_to_path (path);
                }
            }
        }

        // the row is not selected
        return false;
    }

    private void jump_to_file (string filename, int start_line, int end_line)
    {
        File file = File.new_for_path (filename);
        DocumentTab tab = main_window.open_document (file);
        if (start_line != -1)
        {
            // start_line and end_line begins at 1 (from rubber),
            // but select_lines() begins at 0 (gtksourceview)
            int end = end_line != -1 ? end_line - 1 : start_line;
            tab.document.select_lines (start_line - 1, end);
        }
    }

    public void clear ()
    {
        store.clear ();
    }

    public TreeIter add_partition (string msg, PartitionState state, TreeIter? parent)
    {
        TreeIter iter;
        store.append (out iter, parent);
        store.set (iter,
            BuildInfo.ICON, get_icon_from_state (state),
            BuildInfo.MESSAGE, msg,
            BuildInfo.MESSAGE_TYPE, BuildMessageType.OTHER,
            -1);

        view.expand_all ();

        return iter;
    }

    public void set_partition_state (TreeIter partition_id, PartitionState state)
    {
        store.set (partition_id, BuildInfo.ICON, get_icon_from_state (state), -1);
    }

    public void append_issues (TreeIter partition_id, BuildIssue[] issues)
    {
        foreach (BuildIssue issue in issues)
        {
            TreeIter iter;
            store.append (out iter, partition_id);
            store.set (iter,
                BuildInfo.ICON, get_icon_from_msg_type (issue.message_type),
                BuildInfo.MESSAGE, issue.message,
                BuildInfo.MESSAGE_TYPE, issue.message_type,
                BuildInfo.BASENAME, issue.filename != null ?
                    Path.get_basename (issue.filename) : null,
                BuildInfo.FILENAME, issue.filename,
                BuildInfo.START_LINE, issue.start_line,
                BuildInfo.END_LINE, issue.end_line,
                BuildInfo.LINE,
                    issue.start_line != -1 ? issue.start_line.to_string () : null,
                -1);
        }

        view.expand_all ();
    }

    private string? get_icon_from_state (PartitionState state)
    {
        switch (state)
        {
            case PartitionState.RUNNING:
                return STOCK_EXECUTE;
            case PartitionState.SUCCEEDED:
                return STOCK_APPLY;
            case PartitionState.FAILED:
                return STOCK_DIALOG_ERROR;
            case PartitionState.ABORTED:
                return STOCK_STOP;
            default:
                return_val_if_reached (null);
        }
    }

    private string? get_icon_from_msg_type (BuildMessageType type)
    {
        switch (type)
        {
            case BuildMessageType.ERROR:
                return STOCK_DIALOG_ERROR;
            case BuildMessageType.WARNING:
                return STOCK_DIALOG_WARNING;
            case BuildMessageType.BADBOX:
                return "badbox";
            case BuildMessageType.OTHER:
                return null;
            default:
                return_val_if_reached (null);
        }
    }

    public void set_can_abort (bool can_abort, BuildToolRunner? runner)
    {
        action_stop_execution.set_sensitive (can_abort);
        if (runner != null)
            this.runner = runner;
    }

    public void abort ()
    {
        return_if_fail (runner != null);
        runner.abort ();
    }

    public new void show ()
    {
        base.show ();
        action_view_bottom_panel.active = true;
    }
}
