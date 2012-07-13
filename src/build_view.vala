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

public enum BuildState
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
    BuildMsgType type;
    string? text;

    // Reference to a certain file.
    string? filename;

    // Reference to lines in the file. -1 to unset.
    int start_line;
    int end_line;

    // If the message have children, whether to show them.
    bool expand;

    public BuildMsg ()
    {
        type = BuildMsgType.INFO;
        text = null;
        filename = null;
        start_line = -1;
        end_line = -1;
        expand = true;
    }
}

public class BuildView : TreeView
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
    public bool show_details { get; set; default = false; }
    public bool has_details { get; set; default = false; }

    private unowned MainWindow _main_window;
    private TreeStore _store;

    // Used to show/hide warnings and badboxes.
    private TreeModelFilter _filtered_model;

    public BuildView (MainWindow main_window)
    {
        _main_window = main_window;

        init_tree_models ();
        init_tree_view ();
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
        this.set_model (_filtered_model);
        this.headers_visible = false;

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

        this.append_column (column_job);

        this.insert_column_with_attributes (-1, null, new CellRendererText (),
            "text", BuildMsgColumn.BASENAME);
        this.insert_column_with_attributes (-1, null, new CellRendererText (),
            "text", BuildMsgColumn.LINE_STR);

        this.set_tooltip_column (BuildMsgColumn.PATH);

        /* Selection */
        TreeSelection select = this.get_selection ();
        select.set_mode (SelectionMode.SINGLE);
        select.set_select_function ((select, model, path, path_currently_selected) =>
        {
            // always allow deselect
            if (path_currently_selected)
                return true;

            return select_row (model, path);
        });

        /* Double-click */
        this.row_activated.connect ((path) => select_row (_filtered_model, path));
    }

    private bool select_row (TreeModel model, TreePath path)
    {
        TreeIter iter;
        if (! model.get_iter (out iter, path))
            // the row is not selected
            return false;

        if (model.iter_has_child (iter))
        {
            if (this.is_row_expanded (path))
                this.collapse_row (path);
            else
                this.expand_to_path (path);

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
        {
            if (start_line == -1)
                _main_window.open_document (file);
            else
                jump_to_file_lines (file, start_line, end_line);
        }

        // the row is selected, so we can copy/paste its content
        return true;
    }

    private void jump_to_file_lines (File file, int start_line, int end_line)
    {
        return_if_fail (start_line >= 0 && end_line >= 0);

        DocumentTab tab = _main_window.open_document (file);

        // Ensure that the file is fully loaded before selecting the lines.
        Utils.flush_queue ();

        // start_line and end_line begins at 1, but select_lines() begins at 0
        tab.document.select_lines (start_line - 1, end_line - 1);
    }

    public void clear ()
    {
        _store.clear ();
        this.columns_autosize ();
    }

    public TreeIter add_main_title (string main_title, BuildState state)
    {
        return add_title (main_title, state, BuildMsgType.TITLE);
    }

    public TreeIter add_job_title (string job_title, BuildState state)
    {
        return add_title (job_title, state, BuildMsgType.JOB_TITLE);
    }

    private TreeIter add_title (string msg, BuildState state, BuildMsgType type)
    {
        bool bold = type == BuildMsgType.TITLE;

        TreeIter iter;
        _store.append (out iter, null);
        _store.set (iter,
            BuildMsgColumn.ICON,         get_icon_from_state (state),
            BuildMsgColumn.MESSAGE,      msg,
            BuildMsgColumn.MESSAGE_TYPE, type,
            BuildMsgColumn.WEIGHT,       bold ? 800 : 400
        );

        this.expand_to_path (_store.get_path (iter));

        return iter;
    }

    public void set_title_state (TreeIter title_id, BuildState state)
    {
        _store.set (title_id, BuildMsgColumn.ICON, get_icon_from_state (state));
    }

    public void append_messages (TreeIter parent, Node<BuildMsg?> messages,
        bool expand = true)
    {
        unowned Node<BuildMsg?> cur_node = messages.first_child ();
        while (cur_node != null)
        {
            TreeIter child = append_single_message (parent, cur_node.data);

            // the node contains children
            if (cur_node.children != null)
                append_messages (child, cur_node, cur_node.data.expand);

            cur_node = cur_node.next_sibling ();
        }

        if (expand)
            this.expand_to_path (_store.get_path (parent));
    }

    public TreeIter append_single_message (TreeIter parent, BuildMsg msg)
    {
        File file = null;
        string path = null;

        if (msg.filename != null)
        {
            file = File.new_for_path (msg.filename);
            path = Utils.replace_home_dir_with_tilde (msg.filename);

            // the path is displayed in a tooltip
            path = Markup.escape_text (path);
        }

        string? line_str = null;
        if (msg.start_line != -1)
            line_str = msg.start_line.to_string ();

        int end_line = msg.end_line;
        if (end_line == -1)
            end_line = msg.start_line;

        TreeIter iter;
        _store.append (out iter, parent);
        _store.set (iter,
            BuildMsgColumn.ICON,         get_icon_from_msg_type (msg.type),
            BuildMsgColumn.MESSAGE,      msg.text,
            BuildMsgColumn.MESSAGE_TYPE, msg.type,
            BuildMsgColumn.WEIGHT,       400,
            BuildMsgColumn.BASENAME,     file != null ? file.get_basename () : null,
            BuildMsgColumn.FILE,         file,
            BuildMsgColumn.PATH,         path,
            BuildMsgColumn.START_LINE,   msg.start_line,
            BuildMsgColumn.END_LINE,     end_line,
            BuildMsgColumn.LINE_STR,     line_str
        );

        return iter;
    }

    private string? get_icon_from_state (BuildState state)
    {
        switch (state)
        {
            case BuildState.RUNNING:
                return Stock.EXECUTE;

            case BuildState.SUCCEEDED:
                return Stock.APPLY;

            case BuildState.FAILED:
                return Stock.DIALOG_ERROR;

            case BuildState.ABORTED:
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
