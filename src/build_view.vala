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
 *
 * Author: Sébastien Wilmet
 */

using Gtk;

public enum PartitionState
{
    RUNNING,
    SUCCEEDED,
    FAILED,
    ABORTED
}

public enum BuildMsgType
{
    TITLE,
    JOB_TITLE,
    JOB_SUB_COMMAND,
    ERROR,
    WARNING,
    BADBOX,
    INFO
}

public struct BuildMsg
{
    public string text;
    public BuildMsgType type;
    public string? filename;

    public bool lines_set;
    public int start_line;

    // if -1, takes the same value as start_line
    public int end_line;

    // if the message have children, show them?
    public bool expand;
}

public class BuildView : Grid
{
    private enum BuildMsgColumn
    {
        ICON,
        MESSAGE,
        MESSAGE_TYPE,
        WEIGHT,
        BASENAME,
        PATH,
        FILE,
        START_LINE,
        END_LINE,
        LINE_STR,
        N_COLUMNS
    }

    public bool show_warnings { get; set; }
    public bool show_badboxes { get; set; }

    private unowned MainWindow _main_window;
    private TreeStore _store;
    private TreeView _view;

    // Used to show/hide warnings and badboxes.
    private TreeModelFilter _filtered_model;

    public BuildView (MainWindow main_window, Toolbar toolbar)
    {
        orientation = Orientation.HORIZONTAL;
        _main_window = main_window;

        init_tree_models ();
        init_tree_view ();
        packing_widgets (toolbar);
    }

    private void init_tree_models ()
    {
        _store = new TreeStore (BuildMsgColumn.N_COLUMNS,
            typeof (string),    // icon (stock-id)
            typeof (string),    // message
            typeof (BuildMsgType),
            typeof (int),       // weight (normal or bold)
            typeof (string),    // basename
            typeof (string),    // path
            typeof (File),      // file
            typeof (int),       // start line
            typeof (int),       // end line
            typeof (string)     // line (same as start line but for display)
        );

        _filtered_model = new TreeModelFilter (_store, null);
        _filtered_model.set_visible_func ((model, iter) =>
        {
            BuildMsgType msg_type;
            model.get (iter, BuildMsgColumn.MESSAGE_TYPE, out msg_type);

            switch (msg_type)
            {
                case BuildMsgType.WARNING:
                    return show_warnings;

                case BuildMsgType.BADBOX:
                    return show_badboxes;

                default:
                    return true;
            }
        });

        this.notify["show-warnings"].connect (() => _filtered_model.refilter ());
        this.notify["show-badboxes"].connect (() => _filtered_model.refilter ());
    }

    private void init_tree_view ()
    {
        _view = new TreeView.with_model (_filtered_model);
        _view.headers_visible = false;

        /* Columns, cell renderers */
        TreeViewColumn column_job = new TreeViewColumn ();

        CellRendererPixbuf renderer_pixbuf = new CellRendererPixbuf ();
        column_job.pack_start (renderer_pixbuf, false);
        column_job.add_attribute (renderer_pixbuf, "stock-id", BuildMsgColumn.ICON);

        CellRendererText renderer_text = new CellRendererText ();
        renderer_text.weight_set = true;
        renderer_text.editable = true;
        renderer_text.editable_set = true;
        column_job.pack_start (renderer_text, true);
        column_job.add_attribute (renderer_text, "text", BuildMsgColumn.MESSAGE);
        column_job.add_attribute (renderer_text, "weight", BuildMsgColumn.WEIGHT);

        _view.append_column (column_job);

        _view.insert_column_with_attributes (-1, null, new CellRendererText (),
            "text", BuildMsgColumn.BASENAME);
        _view.insert_column_with_attributes (-1, null, new CellRendererText (),
            "text", BuildMsgColumn.LINE_STR);

        _view.set_tooltip_column (BuildMsgColumn.PATH);

        /* Selection */
        TreeSelection select = _view.get_selection ();
        select.set_mode (SelectionMode.SINGLE);
        select.set_select_function ((select, model, path, path_currently_selected) =>
        {
            // always allow deselect
            if (path_currently_selected)
                return true;

            return select_row (model, path);
        });

        /* Double-click */
        _view.row_activated.connect ((path) => select_row (_filtered_model, path));
    }

    private Button get_close_button ()
    {
        Button close_button = new Button ();
        close_button.relief = ReliefStyle.NONE;
        close_button.focus_on_click = false;
        close_button.tooltip_text = _("Hide panel");
        close_button.add (new Image.from_stock (Stock.CLOSE, IconSize.MENU));
        close_button.clicked.connect (() => this.hide ());

        return close_button;
    }

    private void packing_widgets (Toolbar toolbar)
    {
        Widget sw = Utils.add_scrollbar (_view);
        sw.expand = true;
        add (sw);
        sw.show_all ();

        Grid grid = new Grid ();
        grid.orientation = Orientation.VERTICAL;
        grid.add (get_close_button ());

        toolbar.set_vexpand (true);
        grid.add (toolbar);

        add (grid);
        grid.show_all ();
    }

    private bool select_row (TreeModel model, TreePath path)
    {
        TreeIter iter;
        if (! model.get_iter (out iter, path))
            // the row is not selected
            return false;

        if (model.iter_has_child (iter))
        {
            if (_view.is_row_expanded (path))
                _view.collapse_row (path);
            else
                _view.expand_to_path (path);

            // the row is not selected
            return false;
        }

        File file;
        int start_line;
        int end_line;

        model.get (iter,
            BuildMsgColumn.FILE, out file,
            BuildMsgColumn.START_LINE, out start_line,
            BuildMsgColumn.END_LINE, out end_line
        );

        if (file != null)
            jump_to_file (file, start_line, end_line);

        // the row is selected, so we can copy/paste its content
        return true;
    }

    private void jump_to_file (File file, int start_line, int end_line)
    {
        DocumentTab tab = _main_window.open_document (file);

        // If the file was not yet opened, it takes some time. If we try to select the
        // lines when the file is not fully charged, the lines are simply not selected.
        Utils.flush_queue ();

        if (start_line != -1)
        {
            // start_line and end_line begins at 1, but select_lines() begins at 0
            int end = end_line != -1 ? end_line - 1 : start_line;
            tab.document.select_lines (start_line - 1, end);
        }
    }

    public void clear ()
    {
        _store.clear ();
        _view.columns_autosize ();
    }

    public TreeIter add_partition (string msg, PartitionState state, TreeIter? parent,
        bool bold = false)
    {
        BuildMsgType type = bold ? BuildMsgType.TITLE : BuildMsgType.JOB_TITLE;

        TreeIter iter;
        _store.append (out iter, parent);
        _store.set (iter,
            BuildMsgColumn.ICON,         get_icon_from_state (state),
            BuildMsgColumn.MESSAGE,      msg,
            BuildMsgColumn.MESSAGE_TYPE, type,
            BuildMsgColumn.WEIGHT,       bold ? 800 : 400
        );

        _view.expand_to_path (_store.get_path (iter));

        return iter;
    }

    public void set_partition_state (TreeIter partition_id, PartitionState state)
    {
        _store.set (partition_id, BuildMsgColumn.ICON, get_icon_from_state (state));
    }

    public void append_messages (TreeIter parent, Node<BuildMsg?> messages,
        bool parent_is_partition = true)
    {
        unowned Node<BuildMsg?> cur_node = messages.first_child ();
        while (cur_node != null)
        {
            TreeIter child = append_single_message (parent, cur_node.data);

            // the node contains children
            if (cur_node.children != null)
            {
                append_messages (child, cur_node, false);

                if (cur_node.data.expand)
                    _view.expand_to_path (_store.get_path (child));
            }

            cur_node = cur_node.next_sibling ();
        }

        // All partitions are expanded, but we must do that when the partition have
        // children.
        if (parent_is_partition)
            _view.expand_row (_store.get_path (parent), false);
    }

    public TreeIter append_single_message (TreeIter parent, BuildMsg message)
    {
        File file = null;
        string path = null;

        if (message.filename != null)
        {
            file = File.new_for_path (message.filename);
            path = Utils.replace_home_dir_with_tilde (message.filename);

            // the path is displayed in a tooltip
            path = Markup.escape_text (path);
        }

        int start_line = -1;
        int end_line = -1;
        string line_str = null;
        if (message.lines_set)
        {
            start_line = message.start_line;
            end_line = message.end_line;
            line_str = start_line.to_string ();
        }

        TreeIter iter;
        _store.append (out iter, parent);
        _store.set (iter,
            BuildMsgColumn.ICON,         get_icon_from_msg_type (message.type),
            BuildMsgColumn.MESSAGE,      message.text,
            BuildMsgColumn.MESSAGE_TYPE, message.type,
            BuildMsgColumn.WEIGHT,       400,
            BuildMsgColumn.BASENAME,     file != null ? file.get_basename () : null,
            BuildMsgColumn.FILE,         file,
            BuildMsgColumn.PATH,         path,
            BuildMsgColumn.START_LINE,   start_line,
            BuildMsgColumn.END_LINE,     end_line,
            BuildMsgColumn.LINE_STR,     line_str
        );

        return iter;
    }

    private string? get_icon_from_state (PartitionState state)
    {
        switch (state)
        {
            case PartitionState.RUNNING:
                return Stock.EXECUTE;

            case PartitionState.SUCCEEDED:
                return Stock.APPLY;

            case PartitionState.FAILED:
                return Stock.DIALOG_ERROR;

            case PartitionState.ABORTED:
                return Stock.STOP;

            default:
                return_val_if_reached (null);
        }
    }

    private string? get_icon_from_msg_type (BuildMsgType type)
    {
        switch (type)
        {
            case BuildMsgType.JOB_SUB_COMMAND:
                // TODO rename the completion_choice stock icon
                return "completion_choice";

            case BuildMsgType.ERROR:
                return Stock.DIALOG_ERROR;

            case BuildMsgType.WARNING:
                return Stock.DIALOG_WARNING;

            case BuildMsgType.BADBOX:
                return "badbox";

            default:
                return null;
        }
    }
}
