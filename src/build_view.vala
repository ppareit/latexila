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

public class BuildView : HBox
{
    public bool show_errors { get; set; }
    public bool show_warnings { get; set; }
    public bool show_badboxes { get; set; }

    enum BuildInfo
    {
        ICON,
        MESSAGE,
        BASENAME,
        LINE,
        MESSAGE_TYPE,
        START_LINE,
        END_LINE,
        FILENAME,
        N_COLUMNS
    }

    enum BuildMessageType
    {
        ERROR, WARNING, BADBOX, OTHER
    }

    public BuildView (Toolbar toolbar)
    {
        TreeStore tree_store = new TreeStore (BuildInfo.N_COLUMNS,
            typeof (string),    // icon (stock-id)
            typeof (string),    // message
            typeof (string),    // basename
            typeof (string),    // line
            typeof (BuildMessageType),
            typeof (int),       // start line
            typeof (int),       // end line
            typeof (string)     // filename
        );

        /* TEST tree_store */
        TreeIter iter, parent;
        tree_store.append (out parent, null);
        tree_store.set (parent,
            BuildInfo.ICON, STOCK_EXECUTE,
            BuildInfo.MESSAGE, "<b>LaTeX → PDF</b>",
            BuildInfo.MESSAGE_TYPE, BuildMessageType.OTHER,
            -1);

        tree_store.append (out iter, parent);
        tree_store.set (iter,
            BuildInfo.ICON, STOCK_APPLY,
            BuildInfo.MESSAGE, "rubber --inplace --maxerr -1 --short --force --warn all --pdf \"$filename\"",
            BuildInfo.MESSAGE_TYPE, BuildMessageType.OTHER,
            -1);
        TreeIter parent2 = iter;

        tree_store.append (out iter, parent2);
        tree_store.set (iter,
            BuildInfo.ICON, "badbox",
            BuildInfo.MESSAGE, "Overfull \\hbox",
            BuildInfo.MESSAGE_TYPE, BuildMessageType.BADBOX,
            BuildInfo.BASENAME, "test.tex",
            BuildInfo.FILENAME, "/home/seb/test.tex",
            BuildInfo.LINE, "42",
            -1);

        tree_store.append (out iter, parent2);
        tree_store.set (iter,
            BuildInfo.ICON, STOCK_DIALOG_WARNING,
            BuildInfo.MESSAGE, "Waring",
            BuildInfo.MESSAGE_TYPE, BuildMessageType.WARNING,
            -1);

        tree_store.append (out iter, parent2);
        tree_store.set (iter,
            BuildInfo.ICON, STOCK_DIALOG_ERROR,
            BuildInfo.MESSAGE, "Label 'testlabel' multiply defined.",
            BuildInfo.MESSAGE_TYPE, BuildMessageType.ERROR,
            BuildInfo.BASENAME, "test.tex",
            BuildInfo.FILENAME, "/home/seb/test.tex",
            -1);

        tree_store.append (out iter, parent);
        tree_store.set (iter,
            BuildInfo.ICON, STOCK_EXECUTE,
            BuildInfo.MESSAGE, "gnome-open \"$shortname.pdf\"",
            BuildInfo.MESSAGE_TYPE, BuildMessageType.OTHER,
            -1);

        /* create tree view */
        TreeView tree_view = new TreeView.with_model (tree_store);

        TreeViewColumn column_job = new TreeViewColumn ();
        column_job.title = _("Job");

        CellRendererPixbuf renderer_pixbuf = new CellRendererPixbuf ();
        column_job.pack_start (renderer_pixbuf, false);
        column_job.add_attribute (renderer_pixbuf, "stock-id", BuildInfo.ICON);

        CellRendererText renderer_text = new CellRendererText ();
        column_job.pack_start (renderer_text, true);
        column_job.add_attribute (renderer_text, "markup", BuildInfo.MESSAGE);

        tree_view.append_column (column_job);

        tree_view.insert_column_with_attributes (-1, _("File"), new CellRendererText (),
            "text", BuildInfo.BASENAME);
        tree_view.insert_column_with_attributes (-1, _("Line"), new CellRendererText (),
            "text", BuildInfo.LINE);

        tree_view.set_tooltip_column (BuildInfo.FILENAME);

        tree_view.expand_all ();

        pack_start (tree_view);
        pack_start (toolbar, false, false);
    }
}
