/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010-2011 Sébastien Wilmet
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

using Gee;

public struct MostUsedSymbol
{
    public string id;
    public string latex_command;
    public string package_required;
    public uint num;
}

public class MostUsedSymbols : GLib.Object
{
    private static MostUsedSymbols instance = null;

    private LinkedList<MostUsedSymbol?> most_used_symbols;
    private bool modified = false;
    private GLib.Settings settings;

    private MostUsedSymbols ()
    {
        most_used_symbols = new LinkedList<MostUsedSymbol?> ();
        settings = new GLib.Settings ("org.gnome.latexila.preferences.editor");

        /* load most used symbols from the XML file */
        File file = get_xml_file ();
        if (! file.query_exists ())
            return;

        try
        {
            string contents;
            file.load_contents (null, out contents);

            MarkupParser parser = { parser_start, null, null, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);
        }
        catch (GLib.Error e)
        {
            stderr.printf ("Warning: impossible to load most used symbols: %s\n",
                e.message);
        }
    }

    // singleton
    public static MostUsedSymbols get_default ()
    {
        if (instance == null)
            instance = new MostUsedSymbols ();
        return instance;
    }

    public Iterator<MostUsedSymbol?> iterator ()
    {
        int max = settings.get_int ("nb-most-used-symbols");
        var slice = most_used_symbols.slice (0, int.min (max, most_used_symbols.size));
        return (Iterator<MostUsedSymbol?>) slice.iterator ();
    }

    public void clear ()
    {
        modified = true;
        most_used_symbols.clear ();
    }

    public void add_symbol (string id, string command, string? package)
    {
        modified = true;
        int max = settings.get_int ("nb-most-used-symbols");

        int i = 0;
        foreach (MostUsedSymbol mus in most_used_symbols)
        {
            if (mus.id == id)
            {
                mus.num++;
                // keep the list sorted
                int new_i = sort (i, mus);
                if (new_i != i && new_i < max)
                {
                    if (i >= max)
                    {
                        Symbols.remove_most_used_symbol (max - 1);
                        Symbols.insert_most_used_symbol (new_i, mus);
                    }
                    else
                        Symbols.swap_most_used_symbol (i, new_i);
                }
                return;
            }
            i++;
        }

        // not found, insert the new symbol
        MostUsedSymbol new_symbol = MostUsedSymbol ();
        new_symbol.id = id;
        new_symbol.latex_command = command;
        new_symbol.package_required = package;
        new_symbol.num = 1;

        most_used_symbols.add (new_symbol);

        if (most_used_symbols.size <= max)
            Symbols.insert_most_used_symbol (most_used_symbols.size - 1, new_symbol);
    }

    private int sort (int index, MostUsedSymbol mus)
    {
        if (index == 0)
        {
            most_used_symbols[index] = mus;
            return 0;
        }

        int new_index;
        for (new_index = index - 1 ; new_index >= 0 ; new_index--)
        {
            MostUsedSymbol symbol = most_used_symbols[new_index];
            if (symbol.num >= mus.num)
            {
                new_index++;
                break;
            }
        }

        // if the for loop didn't break
        if (new_index < 0)
            new_index = 0;

        if (new_index < index)
        {
            most_used_symbols.remove_at (index);
            most_used_symbols.insert (new_index, mus);
        }
        else
            most_used_symbols[index] = mus;

        return new_index;
    }

    /*
    private void print_summary ()
    {
        stdout.printf ("\n=== Most Used Symbols ===\n");
        foreach (MostUsedSymbol symbol in most_used_symbols)
            stdout.printf ("%s (%s) - %u\n", symbol.id, symbol.latex_command, symbol.num);
    }
    */

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "symbols":
                return;

            case "symbol":
                MostUsedSymbol symbol = MostUsedSymbol ();
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "id":
                            symbol.id = attr_values[i];
                            break;
                        case "command":
                            symbol.latex_command = attr_values[i];
                            break;
                        case "package":
                            symbol.package_required =
                                attr_values[i] != "" ? attr_values[i] : null;
                            break;
                        case "num":
                            symbol.num = (uint) attr_values[i].to_int ();
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                most_used_symbols.add (symbol);
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private File get_xml_file ()
    {
        string path = Path.build_filename (Environment.get_user_data_dir (),
            "latexila", "most_used_symbols.xml", null);
        return File.new_for_path (path);
    }

    public void save ()
    {
        if (! modified)
            return;

        File file = get_xml_file ();

        // if empty, delete the file
        if (most_used_symbols.size == 0)
        {
            Utils.delete_file (file);
            return;
        }

        string content = "<symbols>\n";
        foreach (MostUsedSymbol symbol in most_used_symbols)
        {
            content += "  <symbol id=\"%s\" command=\"%s\" package=\"%s\" num=\"%u\" />\n".printf (
                symbol.id, symbol.latex_command, symbol.package_required ?? "",
                symbol.num);
        }
        content += "</symbols>\n";

        try
        {
            // check if parent directories exist, if not, create it
            File parent = file.get_parent ();
            if (parent != null && ! parent.query_exists ())
                parent.make_directory_with_parents ();

            file.replace_contents (content, content.size (), null, false,
                FileCreateFlags.NONE, null, null);
        }
        catch (Error e)
        {
            stderr.printf ("Warning: impossible to save most used symbols: %s\n",
                e.message);
        }
    }
}
