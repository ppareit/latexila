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
 *
 * Author: Sébastien Wilmet
 */

namespace StockIcons
{
    // Add some icons to the stock icons, so it can be used e.g. in menus.
    public void add_custom ()
    {
        register_my_stock_icons ();
        add_theme_icon_to_stock ("image-x-generic", "image");
        add_theme_icon_to_stock ("x-office-presentation", "presentation");
    }

    private struct StockIcon
    {
        string filename;
        string stock_id;
    }

    // TODO: use GResource
    private const StockIcon[] stock_icons =
    {
        { Config.DATA_DIR + "/images/icons/compile_dvi.png", "compile_dvi" },
        { Config.DATA_DIR + "/images/icons/compile_pdf.png", "compile_pdf" },
        { Config.DATA_DIR + "/images/icons/compile_ps.png", "compile_ps" },
        { Config.DATA_DIR + "/images/icons/view_dvi.png", "view_dvi" },
        { Config.DATA_DIR + "/images/icons/view_pdf.png", "view_pdf" },
        { Config.DATA_DIR + "/images/icons/view_ps.png", "view_ps" },
        { Config.DATA_DIR + "/images/icons/textbf.png", "bold" },
        { Config.DATA_DIR + "/images/icons/textit.png", "italic" },
        { Config.DATA_DIR + "/images/icons/texttt.png", "typewriter" },
        { Config.DATA_DIR + "/images/icons/textsl.png", "slanted" },
        { Config.DATA_DIR + "/images/icons/textsc.png", "small_caps" },
        { Config.DATA_DIR + "/images/icons/textsf.png", "sans_serif" },
        { Config.DATA_DIR + "/images/icons/roman.png", "roman" },
        { Config.DATA_DIR + "/images/icons/underline.png", "underline" },
        { Config.DATA_DIR + "/images/misc-math/set-R.png", "blackboard" },
        { Config.DATA_DIR + "/images/icons/sectioning-part.png", "sectioning-part" },
        { Config.DATA_DIR + "/images/icons/sectioning-chapter.png",
            "sectioning-chapter" },
        { Config.DATA_DIR + "/images/icons/sectioning-section.png",
            "sectioning-section" },
        { Config.DATA_DIR + "/images/icons/sectioning-subsection.png",
            "sectioning-subsection" },
        { Config.DATA_DIR + "/images/icons/sectioning-subsubsection.png",
            "sectioning-subsubsection" },
        { Config.DATA_DIR + "/images/icons/sectioning-paragraph.png",
            "sectioning-paragraph" },
        { Config.DATA_DIR + "/images/icons/character-size.png", "character-size" },
        { Config.DATA_DIR + "/images/icons/list-itemize.png", "list-itemize" },
        { Config.DATA_DIR + "/images/icons/list-enumerate.png", "list-enumerate" },
        { Config.DATA_DIR + "/images/icons/list-description.png", "list-description" },
        { Config.DATA_DIR + "/images/icons/list-item.png", "list-item" },
        { Config.DATA_DIR + "/images/icons/references.png", "references" },
        { Config.DATA_DIR + "/images/icons/math.png", "math" },
        { Config.DATA_DIR + "/images/icons/math-centered.png", "math-centered" },
        { Config.DATA_DIR + "/images/icons/math-numbered.png", "math-numbered" },
        { Config.DATA_DIR + "/images/icons/math-array.png", "math-array" },
        { Config.DATA_DIR + "/images/icons/math-numbered-array.png",
            "math-numbered-array" },
        { Config.DATA_DIR + "/images/icons/math-superscript.png", "math-superscript" },
        { Config.DATA_DIR + "/images/icons/math-subscript.png", "math-subscript" },
        { Config.DATA_DIR + "/images/icons/math-frac.png", "math-frac" },
        { Config.DATA_DIR + "/images/icons/math-square-root.png", "math-square-root" },
        { Config.DATA_DIR + "/images/icons/math-nth-root.png", "math-nth-root" },
        { Config.DATA_DIR + "/images/icons/mathcal.png", "mathcal" },
        { Config.DATA_DIR + "/images/icons/mathfrak.png", "mathfrak" },
        { Config.DATA_DIR + "/images/icons/delimiters-left.png", "delimiters-left" },
        { Config.DATA_DIR + "/images/icons/delimiters-right.png", "delimiters-right" },
        { Config.DATA_DIR + "/images/icons/badbox.png", "badbox" },
        { Config.DATA_DIR + "/images/icons/logviewer.png", "view_log" },
        { Config.DATA_DIR + "/images/greek/01.png", "symbol_alpha" },
        { Config.DATA_DIR + "/images/icons/accent0.png", "accent0" },
        { Config.DATA_DIR + "/images/icons/accent1.png", "accent1" },
        { Config.DATA_DIR + "/images/icons/accent2.png", "accent2" },
        { Config.DATA_DIR + "/images/icons/accent3.png", "accent3" },
        { Config.DATA_DIR + "/images/icons/accent4.png", "accent4" },
        { Config.DATA_DIR + "/images/icons/accent5.png", "accent5" },
        { Config.DATA_DIR + "/images/icons/accent6.png", "accent6" },
        { Config.DATA_DIR + "/images/icons/accent7.png", "accent7" },
        { Config.DATA_DIR + "/images/icons/accent8.png", "accent8" },
        { Config.DATA_DIR + "/images/icons/accent9.png", "accent9" },
        { Config.DATA_DIR + "/images/icons/accent10.png", "accent10" },
        { Config.DATA_DIR + "/images/icons/accent11.png", "accent11" },
        { Config.DATA_DIR + "/images/icons/accent12.png", "accent12" },
        { Config.DATA_DIR + "/images/icons/accent13.png", "accent13" },
        { Config.DATA_DIR + "/images/icons/accent14.png", "accent14" },
        { Config.DATA_DIR + "/images/icons/accent15.png", "accent15" },
        { Config.DATA_DIR + "/images/icons/mathaccent0.png", "mathaccent0" },
        { Config.DATA_DIR + "/images/icons/mathaccent1.png", "mathaccent1" },
        { Config.DATA_DIR + "/images/icons/mathaccent2.png", "mathaccent2" },
        { Config.DATA_DIR + "/images/icons/mathaccent3.png", "mathaccent3" },
        { Config.DATA_DIR + "/images/icons/mathaccent4.png", "mathaccent4" },
        { Config.DATA_DIR + "/images/icons/mathaccent5.png", "mathaccent5" },
        { Config.DATA_DIR + "/images/icons/mathaccent6.png", "mathaccent6" },
        { Config.DATA_DIR + "/images/icons/mathaccent7.png", "mathaccent7" },
        { Config.DATA_DIR + "/images/icons/mathaccent8.png", "mathaccent8" },
        { Config.DATA_DIR + "/images/icons/mathaccent9.png", "mathaccent9" },
        { Config.DATA_DIR + "/images/icons/mathaccent10.png", "mathaccent10" },
        { Config.DATA_DIR + "/images/icons/completion_choice.png", "completion_choice" },
        { Config.DATA_DIR + "/images/icons/completion_cmd.png", "completion_cmd" },
        { Config.DATA_DIR + "/images/icons/tree_part.png", "tree_part" },
        { Config.DATA_DIR + "/images/icons/tree_chapter.png", "tree_chapter" },
        { Config.DATA_DIR + "/images/icons/tree_section.png", "tree_section" },
        { Config.DATA_DIR + "/images/icons/tree_subsection.png", "tree_subsection" },
        { Config.DATA_DIR + "/images/icons/tree_subsubsection.png",
            "tree_subsubsection" },
        { Config.DATA_DIR + "/images/icons/tree_paragraph.png", "tree_paragraph" },
        { Config.DATA_DIR + "/images/icons/tree_todo.png", "tree_todo" },
        { Config.DATA_DIR + "/images/icons/tree_label.png", "tree_label" },
        { Config.DATA_DIR + "/images/icons/table.png", "table" }
    };

    private void register_my_stock_icons ()
    {
        Gtk.IconFactory icon_factory = new Gtk.IconFactory ();

        foreach (StockIcon icon in stock_icons)
        {
            Gtk.IconSet icon_set = new Gtk.IconSet ();
            Gtk.IconSource icon_source = new Gtk.IconSource ();
            icon_source.set_filename (icon.filename);
            icon_set.add_source (icon_source);
            icon_factory.add (icon.stock_id, icon_set);
        }

        icon_factory.add_default ();
    }

    private void add_theme_icon_to_stock (string icon_name, string stock_id)
    {
        Gtk.IconSource icon_source = new Gtk.IconSource ();
        icon_source.set_icon_name (icon_name);

        Gtk.IconSet icon_set = new Gtk.IconSet ();
        icon_set.add_source (icon_source);

        Gtk.IconFactory icon_factory = new Gtk.IconFactory ();
        icon_factory.add (stock_id, icon_set);
        icon_factory.add_default ();
    }
}
