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

// Compile-me:
// $ valac --pkg gio-2.0 generate_symbols.vala

private class GenerateSymbols : Object
{
    struct Symbol
    {
        string command;
        string? name;
        bool math;
        string? package;
    }

    private string documentclass_args = null;
    private string preamble_additional = null;
    private string convert_extent = null;
    private Symbol[] symbols = {};

    private string directory;

    private static const string TEX_FILE = "symbol.tex";
    private static const string DVI_FILE = "symbol.dvi";
    private static const string PNG_FILE = "symbol.png";

    public GenerateSymbols (File xml_file, string directory)
    {
        this.directory = directory;

        try
        {
            string contents;
            xml_file.load_contents (null, out contents);

            MarkupParser parser = { parser_start, null, null, null, null };
            MarkupParseContext context = new MarkupParseContext (parser, 0, this, null);
            context.parse (contents, -1);

            foreach (Symbol symbol in symbols)
            {
                stdout.printf ("create symbol %s\n", symbol.name);
                create_symbol (symbol);
            }
        }
        catch (Error e)
        {
            stderr.printf ("Impossible to generate symbols\n");
        }
    }

    private void parser_start (MarkupParseContext context, string name,
        string[] attr_names, string[] attr_values) throws MarkupError
    {
        switch (name)
        {
            case "symbols":
                break;

            case "documentclass":
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "args":
                            documentclass_args = attr_values[i];
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "preamble":
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "additional":
                            preamble_additional = attr_values[i];
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "convert":
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "extent":
                            convert_extent = attr_values[i];
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                break;

            case "symbol":
                Symbol symbol = Symbol ();
                symbol.command = "";
                symbol.name = null;
                symbol.math = false;
                symbol.package = null;
                for (int i = 0 ; i < attr_names.length ; i++)
                {
                    switch (attr_names[i])
                    {
                        case "command":
                            symbol.command = attr_values[i];
                            break;
                        case "name":
                            symbol.name = attr_values[i];
                            break;
                        case "math":
                            symbol.math = attr_values[i].to_bool ();
                            break;
                        case "package":
                            symbol.package = attr_values[i];
                            break;
                        default:
                            throw new MarkupError.UNKNOWN_ATTRIBUTE (
                                "unknown attribute \"" + attr_names[i] + "\"");
                    }
                }
                if (symbol.name == null)
                    symbol.name = (symbols.length + 1).to_string ();
                symbols += symbol;
                break;

            default:
                throw new MarkupError.UNKNOWN_ELEMENT (
                    "unknown element \"" + name + "\"");
        }
    }

    private void create_symbol (Symbol symbol)
    {
        try
        {
            create_tex_file (symbol);

            string[] argv = { "./generate_symbol.sh", directory, symbol.name,
                convert_extent };
            Process.spawn_sync (null, argv, null, 0, null);
        }
        catch (Error e)
        {
            stderr.printf ("Error: %s\n", e.message);
        }
    }

    private void create_tex_file (Symbol symbol) throws Error
    {
        string doc = "\\documentclass[%s]{article}\n".printf (documentclass_args);
        doc += "\\pagestyle{empty}\n";
        doc += "\\usepackage[T1]{fontenc}\n";
        doc += "\n" + preamble_additional + "\n";

        if (symbol.package != null)
            doc += "\\usepackage{%s}\n".printf (symbol.package);

        doc += "\\begin{document}\n";

        if (symbol.math)
            doc += "\\ensuremath{%s}\n".printf (symbol.command);
        else
            doc += symbol.command + "\n";

        doc += "\\end{document}\n";

        File tex_file = File.new_for_path (directory + "/" + TEX_FILE);
        try
        {
            tex_file.replace_contents (doc, doc.size (), null, false,
                FileCreateFlags.NONE, null);
        }
        catch (Error e)
        {
            throw e;
        }
    }
}

int main (string[] args)
{
    if (args.length != 3)
    {
        stderr.printf ("Usage: %s <XML file> <directory>\n", args[0]);
        return 1;
    }

    File xml_file = File.new_for_commandline_arg (args[1]);
    if (! xml_file.query_exists ())
    {
        stderr.printf ("'%s' does not exist.\n", args[1]);
        return 1;
    }

    File dir = File.new_for_commandline_arg (args[2]);
    if (! dir.query_exists ())
    {
        stderr.printf ("'%s' does not exist.\n", args[2]);
        return 1;
    }

    string directory = args[2];
    if (directory[directory.length - 1] == '/')
        directory = directory[0 : directory.length - 1];

    new GenerateSymbols (xml_file, directory);

    return 0;
}
