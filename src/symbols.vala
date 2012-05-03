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

public enum SymbolsCategoryType
{
    NORMAL,
    MOST_USED
}

public enum SymbolsCategoryColumn
{
    TYPE,
    ICON, // stock-id, as a string
    NAME,
    SYMBOLS_STORE,
    N_COLUMNS
}

public enum SymbolColumn
{
    PIXBUF, // Gdk.Pixbuf
    COMMAND,
    TOOLTIP,
    ID, // used for the most used symbols
    N_COLUMNS
}

public class Symbols : GLib.Object
{
    private struct CategoryInfo
    {
        string name;
        string icon;
        string id;
    }

    private const CategoryInfo[] _normal_categories =
    {
        { N_("Greek"), "symbol_greek", "greek" },
        { N_("Arrows"), "symbol_arrows", "arrows" },
        { N_("Relations"), "symbol_relations", "relations" },
        { N_("Operators"), "symbol_operators", "operators" },
        { N_("Delimiters"), "symbol_delimiters", "delimiters" },
        { N_("Misc math"), "symbol_misc_math", "misc-math" },
        { N_("Misc text"), "symbol_misc_text", "misc-text" }
    };

    private static Symbols _instance = null;
    private ListStore _categories_store;

    // singleton
    private Symbols ()
    {
        _categories_store = new ListStore (SymbolsCategoryColumn.N_COLUMNS,
            typeof (SymbolsCategoryType),
            typeof (string), // the icon
            typeof (string), // the name
            typeof (ListStore)
        );

        /* Normal categories */
        foreach (CategoryInfo info in _normal_categories)
            add_normal_category (info);

        /* Most used symbols */
        //add_new_category (Stock.ABOUT, _("Most Used"));
    }

    public static Symbols get_default ()
    {
        if (_instance == null)
            _instance = new Symbols ();

        return _instance;
    }

    public TreeModel get_categories_model ()
    {
        return _categories_store as TreeModel;
    }

    private void add_normal_category (CategoryInfo info)
    {
        ListStore store = new NormalSymbols (info.id);

        TreeIter iter;
        _categories_store.append (out iter);
        _categories_store.set (iter,
            SymbolsCategoryColumn.TYPE, SymbolsCategoryType.NORMAL,
            SymbolsCategoryColumn.ICON, info.icon,
            SymbolsCategoryColumn.NAME, _(info.name),
            SymbolsCategoryColumn.SYMBOLS_STORE, store
        );
    }

    /* MOST USED SYMBOLS */
    public static void reload_most_used_symbols ()
    {
        /*
        _most_used_store.clear ();

        foreach (MostUsedSymbol mus in MostUsedSymbols.get_default ())
        {
            var symbol = get_symbol_info_from_most_used (mus);
            insert_symbol (_most_used_store, -1, symbol);
        }
        */
    }

    public static void insert_most_used_symbol (int index, MostUsedSymbol symbol)
    {
//        insert_symbol (_most_used_store, index, get_symbol_info_from_most_used (symbol));
    }

    public static void remove_most_used_symbol (int index)
    {
        /*
        TreePath path = new TreePath.from_indices (index, -1);
        TreeIter iter;
        if (_most_used_store.get_iter (out iter, path))
            _most_used_store.remove (iter);
        */
    }

    public static void swap_most_used_symbol (int current_index, int new_index)
    {
        /*
        TreePath current_path = new TreePath.from_indices (current_index, -1);
        TreePath new_path = new TreePath.from_indices (new_index, -1);

        TreeIter current_iter = {};
        TreeIter new_iter = {};

        if (_most_used_store.get_iter (out current_iter, current_path)
            && _most_used_store.get_iter (out new_iter, new_path))
        {
            _most_used_store.move_before (ref current_iter, new_iter);
        }
        */
    }
}

private class NormalSymbols : ListStore
{
    private struct SymbolInfo
    {
        string icon_file;
        string latex_command;
        string? package_required;
    }

    private string _category_id;
    private string _resource_path;

    public NormalSymbols (string category_id)
    {
        _category_id = category_id;
        _resource_path = @"/org/gnome/latexila/symbols/$category_id/";

        Type[] column_types = {
            typeof (Gdk.Pixbuf),
            typeof (string), // command
            typeof (string), // tooltip
            typeof (string), // package
            typeof (string)  // id
        };

        set_column_types (column_types);

        load_symbols ();
    }

    private void load_symbols ()
    {
        unowned string? contents =
            Utils.get_string_from_resource (_resource_path + "data.xml");

        if (contents == null)
            return;

        try
        {
            MarkupParser parser = { parser_start, null, null, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);
        }
        catch (GLib.Error e)
        {
            warning ("Impossible to load the symbols: %s", e.message);
        }
    }

    private void add_symbol (SymbolInfo symbol)
    {
        Gdk.Pixbuf pixbuf;

        try
        {
            pixbuf = Gdk.MyPixbuf.from_resource (_resource_path + symbol.icon_file);
        }
        catch (Error e)
        {
            warning ("Impossible to load the symbol: %s", e.message);
            return;
        }

        // Some characters ('<' for example) generate errors for the tooltip,
        // so the text must be escaped.
        string tooltip = Markup.escape_text (symbol.latex_command);

        if (symbol.package_required != null)
            tooltip += " (package %s)".printf (symbol.package_required);

        string id = "%s/%s".printf (_category_id, symbol.icon_file);

        TreeIter iter;
        append (out iter);
        set (iter,
            SymbolColumn.PIXBUF, pixbuf,
            SymbolColumn.COMMAND, symbol.latex_command,
            SymbolColumn.TOOLTIP, tooltip,
            SymbolColumn.ID, id
        );
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "symbols":
                return;

            case "symbol":
                SymbolInfo symbol = SymbolInfo ();
                symbol.package_required = null;

                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "file":
                            symbol.icon_file = attr_values[i];
                            break;

                        case "command":
                            symbol.latex_command = attr_values[i];
                            break;

                        case "package":
                            symbol.package_required = attr_values[i];
                            break;

                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }

                add_symbol (symbol);
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }
}
