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
    public int? start_line;
    public int? end_line;
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
        N_COLUMNS
    }

    public bool show_errors { get; set; }
    public bool show_warnings { get; set; }
    public bool show_badboxes { get; set; }

    private TreeStore store;
    private TreeView view;
    private Action stop_execution;
    private BuildToolRunner? runner = null;

    public BuildView (Toolbar toolbar, Action stop_execution)
    {
        store = new TreeStore (BuildInfo.N_COLUMNS,
            typeof (string),    // icon (stock-id)
            typeof (string),    // message
            typeof (BuildMessageType),
            typeof (string),    // basename
            typeof (string),    // filename
            typeof (string),    // start line (string because must be displayed)
            typeof (int)        // end line
        );

        this.stop_execution = stop_execution;

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
            "text", BuildInfo.START_LINE);

        view.set_tooltip_column (BuildInfo.FILENAME);

        /* TEST store */
        TreeIter root_partition =
            add_partition ("<b>LaTeX → PDF</b>", PartitionState.RUNNING, null);
        TreeIter rubber_partition =
            add_partition ("rubber --inplace --maxerr -1 --short --force --warn all --pdf \"$filename\"",
                PartitionState.SUCCEEDED, root_partition);
        add_partition ("gnome-open \"$shortname.pdf\"", PartitionState.ABORTED,
            root_partition);

        BuildIssue[] issues =
        {
            BuildIssue ()
            {
                message = "Overfull \\hbox",
                message_type = BuildMessageType.BADBOX,
                filename = "/home/seb/test.tex",
                start_line = 42, end_line = 43
            },
            BuildIssue ()
            {
                message = "Warning",
                message_type = BuildMessageType.WARNING
            },
            BuildIssue ()
            {
                message = "Label 'testlabel' multiply defined.",
                message_type = BuildMessageType.ERROR,
                filename = "/home/seb/test.tex"
            }
        };

        append_issues (rubber_partition, issues);

        pack_start (view);
        pack_start (toolbar, false, false);
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
                BuildInfo.START_LINE, issue.start_line != null ?
                    issue.start_line.to_string () : null,
                BuildInfo.END_LINE, issue.end_line,
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
        stop_execution.set_sensitive (can_abort);
        if (runner != null)
            this.runner = runner;
    }

    public void abort ()
    {
        return_if_fail (runner != null);
        runner.abort ();
    }
}
