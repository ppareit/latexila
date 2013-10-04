/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2012 Sébastien Wilmet
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

// A simple text entry for which we can set visually that there is an error.
public class ErrorEntry : Entry
{
    public bool error { get; set; default = false; }

    public ErrorEntry ()
    {
        string style = """
        GtkEntry {
            color: white;
            background-image: none;
            background-color: rgb (237, 54, 54);
        }
        """;

        CssProvider provider = new CssProvider ();

        try
        {
            provider.load_from_data (style, -1);
        }
        catch (Error e)
        {
            warning ("Impossible to load CSS style for the error entry: %s", e.message);
            return;
        }

        notify["error"].connect (() =>
        {
            StyleContext context = get_style_context ();

            if (error)
                context.add_provider (provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
            else
                context.remove_provider (provider);
        });
    }
}
