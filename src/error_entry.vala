/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2012, 2013 Sébastien Wilmet
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

// Add and remove a style for errors (e.g. text not found) in a GtkEntry.
// The style is: red background, white foreground.
public class ErrorEntry : Object
{
    private static CssProvider _provider = null;

    private static void init_provider ()
    {
        if (_provider != null)
            return;

        string style = """
        GtkEntry {
            color: white;
            background-image: none;
            background-color: rgb (237, 54, 54);
        }
        """;

        _provider = new CssProvider ();

        try
        {
            _provider.load_from_data (style, -1);
        }
        catch (Error e)
        {
            warning ("Impossible to load CSS style for the error entry: %s", e.message);
        }
    }

    public static void add_error (Widget widget)
    {
        StyleContext context = widget.get_style_context ();

        init_provider ();

        if (_provider != null)
            context.add_provider (_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    public static void remove_error (Widget widget)
    {
        StyleContext context = widget.get_style_context ();

        init_provider ();

        if (_provider != null)
            context.remove_provider (_provider);
    }
}
