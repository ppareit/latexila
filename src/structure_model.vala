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

public struct StructData
{
    StructType type;
    string text;
    TextMark start_mark;
    TextMark? end_mark;
}

public enum StructColumn
{
    PIXBUF,
    TEXT,
    TOOLTIP,
    START_MARK,
    END_MARK,
    TYPE,
    N_COLUMNS
}

public enum StructListColumn
{
    PIXBUF,
    TEXT,
    TOOLTIP,
    N_COLUMNS
}

public errordomain StructError {
    GENERAL,
    DATA_OUTDATED
}

public class StructureModel : TreeModel, GLib.Object
{
    // This model is connected to the view only when the parsing is done. So it is useless
    // to emit signals during the initial parsing. Emitting a signal can be slow, for
    // example to get the TreePath (a signal parameter), a O(N) GNode function is used...
    public bool emit_signals { get; set; default = false; }

    private Type[] _column_types;
    private Node<StructData?> _tree;
    private int _stamp;
    private uint _nb_nodes = 0;
    private unowned Node<StructData?> _end_node = null;

    private Gee.ArrayList<unowned Node<StructData?>> _list_labels;
    private Gee.ArrayList<unowned Node<StructData?>> _list_includes;
    private Gee.ArrayList<unowned Node<StructData?>> _list_tables;
    private Gee.ArrayList<unowned Node<StructData?>> _list_figures;
    private Gee.ArrayList<unowned Node<StructData?>> _list_todos_and_fixmes;

    public StructureModel ()
    {
        _column_types = new Type[StructColumn.N_COLUMNS];
        _column_types[StructColumn.PIXBUF]      = typeof (string);
        _column_types[StructColumn.TEXT]        = typeof (string);
        _column_types[StructColumn.TOOLTIP]     = typeof (string);
        _column_types[StructColumn.START_MARK]  = typeof (TextMark);
        _column_types[StructColumn.END_MARK]    = typeof (TextMark);
        _column_types[StructColumn.TYPE]        = typeof (StructType);

        StructData empty_data = {};
        _tree = new Node<StructData?> (empty_data);

        new_stamp ();
        reset_simple_lists ();
    }

    // A new stamp should be generated each time the data in the model change
    private void new_stamp ()
    {
        _stamp = (int) Random.next_int ();
    }

    private TreeIter? create_iter_at_node (Node<StructData?> node)
    {
        return_val_if_fail (node != _tree, null);

        TreeIter new_iter = TreeIter ();
        new_iter.stamp = _stamp;
        new_iter.user_data = node;
        return new_iter;
    }

    private bool iter_is_valid (TreeIter iter)
    {
        if (iter.stamp != _stamp)
        {
//            stderr.printf ("iter not valid: bad stamp\n");
            return false;
        }

        if (iter.user_data == null)
        {
//            stderr.printf ("iter not valid: bad user_data\n");
            return false;
        }

        unowned Node<StructData?> node = get_node_from_iter (iter);
        if (node.data == null)
        {
//            stderr.printf ("iter not valid: bad node data\n");
            return false;
        }

        StructData data = node.data;
        if (data.text == null)
        {
//            stderr.printf ("iter not valid: text is null\n");
            return false;
        }

        return true;
    }

    private bool column_is_valid (int index)
    {
        return 0 <= index && index < StructColumn.N_COLUMNS;
    }

    // iter must be valid
    private unowned Node<StructData?> get_node_from_iter (TreeIter iter)
    {
        return (Node<StructData?>) iter.user_data;
    }

    /*************************************************************************/
    // TreeModel interface implementation, based on a N-ary tree (GNode)

    public Type get_column_type (int index)
    {
        return_val_if_fail (column_is_valid (index), Type.INVALID);

        return _column_types[index];
    }

    public int get_n_columns ()
    {
        return StructColumn.N_COLUMNS;
    }

    public TreeModelFlags get_flags ()
    {
        return 0;
    }

    public bool iter_has_child (TreeIter iter)
    {
        return_val_if_fail (iter_is_valid (iter), false);

        unowned Node<StructData?> node = get_node_from_iter (iter);
        return ! node.is_leaf ();
    }

    public int iter_n_children (TreeIter? iter)
    {
        unowned Node<StructData?> node;
        if (iter == null)
            node = _tree;
        else
        {
            return_val_if_fail (iter_is_valid (iter), -1);
            node = get_node_from_iter (iter);
        }

        return (int) node.n_children ();
    }

    public void get_value (TreeIter iter, int column, out Value val)
    {
        return_if_fail (iter_is_valid (iter));
        return_if_fail (column_is_valid (column));

        unowned Node<StructData?> node = get_node_from_iter (iter);
        StructData data = node.data;

        switch (column)
        {
            case StructColumn.TEXT:
                val = data.text;
                break;

            case StructColumn.START_MARK:
                val = data.start_mark;
                break;

            case StructColumn.END_MARK:
                val = data.end_mark;
                break;

            case StructColumn.TYPE:
                val = data.type;
                break;

            case StructColumn.PIXBUF:
                val = Structure.get_icon_from_type (data.type);
                break;

            case StructColumn.TOOLTIP:
                val = Structure.get_type_name (data.type);
                break;

            default:
                return_if_reached ();
        }
    }

    public bool iter_children (out TreeIter iter, TreeIter? parent)
    {
        unowned Node<StructData?> node;
        if (parent == null)
            node = _tree;
        else
        {
            return_val_if_fail (iter_is_valid (parent), false);
            node = get_node_from_iter (parent);
        }

        if (node.is_leaf ())
            return false;

        iter = create_iter_at_node (node.first_child ());
        return true;
    }

    public bool iter_next (ref TreeIter iter)
    {
        return_val_if_fail (iter_is_valid (iter), false);

        unowned Node<StructData?> node = get_node_from_iter (iter);
        unowned Node<StructData?>? next_node = node.next_sibling ();
        if (next_node == null)
            return false;

        iter = create_iter_at_node (next_node);
        return true;
    }

    public bool iter_nth_child (out TreeIter iter, TreeIter? parent, int n)
    {
        unowned Node<StructData?> node;
        if (parent == null)
            node = _tree;
        else
        {
            return_val_if_fail (iter_is_valid (parent), false);
            node = get_node_from_iter (parent);
        }

        if (node.is_leaf ())
            return false;

        if (n < 0 || node.n_children () <= n)
            return false;

        iter = create_iter_at_node (node.nth_child ((uint) n));
        return true;
    }

    public bool iter_parent (out TreeIter iter, TreeIter child)
    {
        return_val_if_fail (iter_is_valid (child), false);

        unowned Node<StructData?> node = get_node_from_iter (child);
        unowned Node<StructData?>? parent_node = node.parent;

        // normally, there is always a parent
        return_val_if_fail (parent_node != null, false);

        // but the root is not a good parent
        if (parent_node == _tree)
            return false;

        iter = create_iter_at_node (parent_node);
        return true;
    }

    public bool get_iter (out TreeIter iter, TreePath path)
    {
        int depth = path.get_depth ();
        return_val_if_fail (1 <= depth, false);

        unowned int[] indices = path.get_indices ();

        unowned Node<StructData?> node = _tree;
        for (int cur_depth = 0 ; cur_depth < depth ; cur_depth++)
        {
            int indice = indices[cur_depth];
            if (indice < 0 || node.n_children () <= indice)
                return false;

            node = node.nth_child (indice);
        }

        iter = create_iter_at_node (node);
        return true;
    }

    // TODO TreePath -> TreePath? when the next version of Vala is released
    // See https://bugzilla.gnome.org/show_bug.cgi?id=651871
    public TreePath get_path (TreeIter iter)
    {
        return_val_if_fail (iter_is_valid (iter), null);

        TreePath path = new TreePath ();
        unowned Node<StructData?> node = get_node_from_iter (iter);

        while (! node.is_root ())
        {
            int pos = node.parent.child_position (node);
            path.prepend_index (pos);
            node = node.parent;
        }

        return path;
    }

    // TODO remove (un)ref_node() when the next version of Vala is released
    // See https://bugzilla.gnome.org/show_bug.cgi?id=651872
    public void ref_node (TreeIter iter)
    {
    }

    public void unref_node (TreeIter iter)
    {
    }


    /*************************************************************************/
    // Custom methods

    public uint get_nb_items ()
    {
        return _nb_nodes;
    }

    public TreeIter? add_item_at_end (StructData item)
    {
        // A first implementation used node.last_child (), but this function is O(N)
        // with N the number of children. This was too slow with some big documents.
        // Now we keep track of the last node in the tree, so we simply have to traverse
        // the parents (wich is O(1)).

        // Another improvement is to find the previous sibling instead of the parent,
        // because when we _append_ a new child, all the children are traversed, which is
        // O(N). When we insert a node just after another, it's O(1).

        if (_end_node == null)
            search_end_node ();

        /* Search the previous sibling, or the parent */
        StructType item_depth = item.type;
        unowned Node<StructData?> parent = _end_node;
        unowned Node<StructData?>? prev_sibling = null;
        while (true)
        {
            if (parent == _tree)
                break;

            StructType cur_depth = parent.data.type;
            if (Structure.is_section (cur_depth) && cur_depth < item_depth)
                break;

            prev_sibling = parent;
            parent = parent.parent;
        }

        /* Insert the node at the right place */
        TreeIter? end_iter = insert_item_after (parent, prev_sibling, item);

        if (end_iter != null)
            _end_node = get_node_from_iter (end_iter);

        return end_iter;
    }

    // With the iter returned, we can simply go one line backward and we have the end of
    // the section. If null is returned, the end of the section is the end of the doc.
    public TreeIter? get_next_sibling_or_parent (TreeIter section_iter) throws StructError
    {
        if (! iter_is_valid (section_iter))
            throw new StructError.GENERAL ("iter is not valid.");

        unowned Node<StructData?> cur_node = get_node_from_iter (section_iter);

        if (! Structure.is_section (cur_node.data.type))
            throw new StructError.GENERAL ("iter is not a section.");

        while (cur_node != null && cur_node != _tree)
        {
            unowned Node<StructData?>? next_sibling_node = cur_node.next_sibling ();

            if (next_sibling_node != null)
                return create_iter_at_node (next_sibling_node);

            cur_node = cur_node.parent;
        }

        return null;
    }

    public void delete (TreeIter iter)
    {
        return_if_fail (iter_is_valid (iter));

        unowned Node<StructData?> node = get_node_from_iter (iter);
        delete_node (node);
        _end_node = null;
        regenerate_simple_lists ();
    }

    public void modify_data (TreePath path, string text, TextMark end_mark)
    {
        TreeIter iter;
        bool iter_is_valid = get_iter (out iter, path);
        return_if_fail (iter_is_valid);

        unowned Node<StructData?> node = get_node_from_iter (iter);

        // modify data
        new_stamp ();
        node.data.text = text;
        node.data.end_mark = end_mark;

        if (emit_signals)
            row_changed (path, iter);

        make_children_between_marks (node);
    }

    public void shift_right (TreeIter iter)
    {
        return_if_fail (iter_is_valid (iter));

        unowned Node<StructData?> node = get_node_from_iter (iter);
        StructType type = node.data.type;
        return_if_fail (type < StructType.SUBPARAGRAPH);

        StructType new_type = type + 1;

        /* Find new position in the tree */
        unowned Node<StructData?>? new_parent = node.prev_sibling ();
        int new_pos;

        if (new_parent == null || new_type <= new_parent.data.type)
        {
            // position unchanged
            new_parent = node.parent;
            new_pos = new_parent.child_position (node);
        }
        else
            // append
            new_pos = -1;

        /* Unlink the node, modify the types and reinsert the node */

        Node<StructData?> node_unlinked = delete_node (node);

        shift_node (node_unlinked, true);

        node = new_parent.insert (new_pos, (owned) node_unlinked);
        reinsert_node (node);
    }

    public void shift_left (TreeIter iter)
    {
        return_if_fail (iter_is_valid (iter));

        unowned Node<StructData?> node = get_node_from_iter (iter);
        StructType type = node.data.type;
        return_if_fail (StructType.PART < type && type <= StructType.SUBPARAGRAPH);

        StructType new_type = type - 1;

        /* Find new position in the tree */
        unowned Node<StructData?> new_parent;
        int new_pos;

        unowned Node<StructData?> parent = node.parent;
        if (parent == _tree || parent.data.type < new_type)
        {
            // position unchanged
            new_parent = parent;
            new_pos = parent.child_position (node);
        }
        else
        {
            new_parent = parent.parent;
            new_pos = new_parent.child_position (parent) + 1;
        }

        /* Unlink the node and modify the types */
        unowned Node<StructData?>? sibling = node.next_sibling ();

        Node<StructData?> node_unlinked = delete_node (node);
        shift_node (node_unlinked, false);

        /* Next siblings becomes normally children */
        while (sibling != null)
        {
            if (sibling.data.type <= new_type)
                break;

            unowned Node<StructData?>? next_sibling = sibling.next_sibling ();

            Node<StructData?> new_child = delete_node (sibling);
            node_unlinked.append ((owned) new_child);

            sibling = next_sibling;
        }

        /* Reinsert the node */
        node = new_parent.insert (new_pos, (owned) node_unlinked);
        reinsert_node (node);
    }

    public bool item_contains_subparagraph (TreeIter iter)
    {
        return_val_if_fail (iter_is_valid (iter), false);

        unowned Node<StructData?> node = get_node_from_iter (iter);
        return node_contains_subparagraph (node);
    }

    private bool node_contains_subparagraph (Node<StructData?> node)
    {
        StructType type = node.data.type;

        if (type == StructType.SUBPARAGRAPH)
            return true;

        if (! Structure.is_section (type))
            return false;

        unowned Node<StructData?>? child = node.first_child ();
        while (child != null)
        {
            if (node_contains_subparagraph (child))
                return true;
            child = child.next_sibling ();
        }

        return false;
    }

    private void insert_node (Node<StructData?> node, bool force_first_child = false)
    {
        new_stamp ();
        _nb_nodes++;

        if (! emit_signals)
            return;

        TreeIter item_iter = create_iter_at_node (node);
        TreePath item_path = get_path (item_iter);
        row_inserted (item_path, item_iter);

        // Attention, the row-has-child-toggled signal must be emitted _after_,
        // else there are strange errors.
        unowned Node<StructData?> parent = node.parent;
        bool first_child = parent != _tree && parent.children == node;
        if (force_first_child || first_child)
        {
            TreeIter parent_iter = create_iter_at_node (parent);
            TreePath parent_path = get_path (parent_iter);
            row_has_child_toggled (parent_path, parent_iter);
        }
    }

    private Node<StructData?>? delete_node (Node<StructData?> node)
    {
        new_stamp ();

        TreePath path = null;
        unowned Node<StructData?> parent = null;
        if (emit_signals)
        {
            TreeIter? iter = create_iter_at_node (node);
            return_val_if_fail (iter != null, null);

            path = get_path (iter);
            parent = node.parent;
        }

        Node<StructData?> node_unlinked = node.unlink ();
        _nb_nodes -= node_unlinked.n_nodes (TraverseFlags.ALL);

        if (emit_signals)
        {
            row_deleted (path);

            if (parent != _tree && parent.children == null)
            {
                TreeIter parent_iter = create_iter_at_node (parent);
                TreePath parent_path = get_path (parent_iter);
                row_has_child_toggled (parent_path, parent_iter);
            }
        }

        return node_unlinked;
    }

    private void shift_node (Node<StructData?> node, bool shift_right)
    {
        if (! Structure.is_section (node.data.type))
            return;

        if (shift_right)
        {
            if (node.data.type != StructType.SUBPARAGRAPH)
                node.data.type += 1;
        }
        else if (node.data.type != StructType.PART)
            node.data.type -= 1;

        unowned Node<StructData?>? child = node.first_child ();
        while (child != null)
        {
            shift_node (child, shift_right);
            child = child.next_sibling ();
        }
    }

    private void reinsert_node (Node<StructData?> node, bool force_first_child = false)
    {
        insert_node (node, force_first_child);

        unowned Node<StructData?>? child = node.first_child ();
        bool first_child = true;

        while (child != null)
        {
            reinsert_node (child, first_child);
            child = child.next_sibling ();
            first_child = false;
        }
    }

    private TreeIter? insert_item_after (Node<StructData?> parent,
        Node<StructData?>? sibling, StructData item)
    {
        return_val_if_fail (item.text != null, null);

        unowned Node<StructData?> new_node = parent.insert_after (sibling,
            new Node<StructData?> (item));

        insert_node (new_node);
        insert_node_in_list (new_node, true);

        return create_iter_at_node (new_node);
    }

    private void make_children_between_marks (Node<StructData?> node)
    {
        StructData data = node.data;
        if (data.end_mark == null)
            return;

        int end_mark_pos = get_position_from_mark (data.end_mark);

        unowned Node<StructData?>? sibling = node.next_sibling ();
        while (sibling != null)
        {
            StructData sibling_data = sibling.data;

            // if a section is in an environment, something is broken somewhere
            // (too much tequila maybe?)
            if (Structure.is_section (sibling_data.type))
                break;

            int sibling_pos = get_position_from_mark (sibling_data.start_mark);
            if (end_mark_pos <= sibling_pos)
                break;

            // unlink the node
            Node<StructData?> sibling_unlinked = delete_node (sibling);

            // append it as a child
            unowned Node<StructData?> new_child = node.append ((owned) sibling_unlinked);
            insert_node (new_child);

            sibling = node.next_sibling ();
        }
    }

    private void search_end_node ()
    {
        _end_node = _tree;
        while (! _end_node.is_leaf ())
            _end_node = _end_node.last_child ();
    }

    private static int get_position_from_mark (TextMark mark)
    {
        TextIter iter;
        TextBuffer doc = mark.get_buffer ();
        doc.get_iter_at_mark (out iter, mark);
        return iter.get_offset ();
    }


    /*************************************************************************/
    // Simple lists

    public void populate_list (ListStore store, StructType type)
    {
        var list = get_list (type);
        return_if_fail (list != null);

        foreach (unowned Node<StructData?> node in list)
        {
            StructData data = node.data;

            TreeIter iter;
            store.append (out iter);
            store.set (iter,
                StructListColumn.PIXBUF, Structure.get_icon_from_type (data.type),
                StructListColumn.TEXT, data.text,
                StructListColumn.TOOLTIP, Structure.get_type_name (data.type),
                -1);
        }
    }

    public TreePath? get_tree_path_from_list_num (StructType list_type, int num)
    {
        var list = get_list (list_type);
        return_val_if_fail (list != null, null);

        return_val_if_fail (0 <= num && num < list.size, null);

        return get_path (create_iter_at_node (list[num]));
    }

    // return -1 on error
    public int get_list_num_from_tree_iter (TreeIter tree_iter)
    {
        return_val_if_fail (iter_is_valid (tree_iter), -1);

        unowned Node<StructData?> node = get_node_from_iter (tree_iter);

        var list = get_list (node.data.type);
        return_val_if_fail (list != null, -1);

        for (int num = 0 ; num < list.size ; num++)
        {
            if (list[num] == node)
                return num;
        }

        return_val_if_reached (-1);
    }

    private void insert_node_in_list (Node<StructData?> node, bool at_end)
    {
        StructData item = node.data;

        if (Structure.is_section (item.type))
            return;

        var list = get_list (item.type);
        return_if_fail (list != null);

        // if it's an append_item(), append the item to the list too
        if (at_end)
        {
            list.add (node);
            return;
        }

        // if the item is inserted in the middle, search where to insert it in the list
        int mark_pos = get_position_from_mark (item.start_mark);
        int i;
        for (i = 0 ; i < list.size ; i++)
        {
            int cur_mark_pos = get_position_from_mark (list[i].data.start_mark);
            if (cur_mark_pos > mark_pos)
                break;
        }
        list.insert (i, node);
    }

    private void regenerate_simple_lists ()
    {
        reset_simple_lists ();

        _tree.traverse (TraverseType.PRE_ORDER, TraverseFlags.ALL, -1, (node_param) =>
        {
            unowned Node<StructData?> node = (Node<StructData?>) node_param;
            StructType type = node.data.type;
            if (! Structure.is_section (type))
            {
                var list = get_list (type);
                return_val_if_fail (list != null, true);

                list.add (node);
            }

            // continue the traversal
            return false;
        });
    }

    private void reset_simple_lists ()
    {
        _list_labels            = new Gee.ArrayList<unowned Node<StructData?>> ();
        _list_includes          = new Gee.ArrayList<unowned Node<StructData?>> ();
        _list_tables            = new Gee.ArrayList<unowned Node<StructData?>> ();
        _list_figures           = new Gee.ArrayList<unowned Node<StructData?>> ();
        _list_todos_and_fixmes  = new Gee.ArrayList<unowned Node<StructData?>> ();
    }

    private Gee.ArrayList<unowned Node<StructData?>>? get_list (StructType type)
    {
        if (Structure.is_section (type))
            return null;

        switch (type)
        {
            case StructType.LABEL:
                return _list_labels;

            case StructType.INCLUDE:
                return _list_includes;

            case StructType.TABLE:
                return _list_tables;

            case StructType.FIGURE:
            case StructType.IMAGE:
                return _list_figures;

            case StructType.TODO:
            case StructType.FIXME:
                return _list_todos_and_fixmes;

            default:
                return null;
        }
    }

//    private void print_item (StructData item)
//    {
//        stdout.printf ("\n=== ITEM ===\n");
//        stdout.printf ("Type: %s\n", Structure.get_type_name (item.type));
//        stdout.printf ("Text: %s\n\n", item.text);
//    }
}
