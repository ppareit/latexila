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

public class LatexMenu : ActionGroup
{
    private const ActionEntry[] latex_action_entries =
    {
        // LaTeX
        { "Latex", null, "_LaTeX" },

        { "LatexDocumentClass", null, "\\documentclass", null,
            N_("Document class - \\documentclass"), on_documentclass },
        { "LatexUsepackage", null, "\\usepackage", null,
            N_("Use package - \\usepackage"), on_usepackage },
        { "LatexAMS", null, N_("AMS packages"), null,
            N_("AMS packages"), on_ams_packages },
        { "LatexAuthor", null, "\\author", null, N_("Author - \\author"), on_author },
        { "LatexTitle", null, "\\title", null, N_("Title - \\title"), on_title },
        { "LatexBeginDocument", null, "\\begin{document}", null,
            N_("Content of the document - \\begin{document}"), on_begin_document },
        { "LatexMakeTitle", null, "\\maketitle", null,
            N_("Make title - \\maketitle"), on_maketitle },
        { "LatexTableOfContents", null, "\\tableofcontents", null,
            N_("Table of contents - \\tableofcontents"), on_tableofcontents },
        { "LatexAbstract", null, "\\begin{abstract}", null,
            N_("Abstract - \\begin{abstract}"), on_abstract },

        // LaTeX: Sectioning
	    { "Sectioning", "sectioning-section", N_("_Sectioning") },
	    { "SectioningPart", "sectioning-part", "\\_part", null,
		    N_("Part"), on_sectioning_part },
	    { "SectioningChapter", "sectioning-chapter", "\\_chapter", null,
		    N_("Chapter"), on_sectioning_chapter },
	    { "SectioningSection", "sectioning-section", "\\_section", null,
		    N_("Section"), on_sectioning_section },
	    { "SectioningSubsection", "sectioning-subsection", "\\s_ubsection", null,
		    N_("Sub-section"), on_sectioning_subsection },
	    { "SectioningSubsubsection", "sectioning-subsubsection", "\\su_bsubsection",
	        null, N_("Sub-sub-section"), on_sectioning_subsubsection },
	    { "SectioningParagraph", "sectioning-paragraph", "\\p_aragraph", null,
		    N_("Paragraph"), on_sectioning_paragraph },
	    { "SectioningSubparagraph", "sectioning-paragraph", "\\subpa_ragraph", null,
		    N_("Sub-paragraph"), on_sectioning_subparagraph },

        // LaTeX: References
	    { "References", "references", N_("_References") },
	    { "ReferencesLabel", null, "\\_label", null,
	        N_("Label"), on_ref_label },
	    { "ReferencesRef", null, "\\_ref", null,
	        N_("Reference to a label"), on_ref_ref },
	    { "ReferencesPageref", null, "\\_pageref", null,
	        N_("Page reference to a label"), on_ref_pageref },
	    { "ReferencesIndex", null, "\\_index", null,
	        N_("Add a word to the index"), on_ref_index },
	    { "ReferencesFootnote", null, "\\_footnote", null,
	        N_("Footnote"), on_ref_footnote },
	    { "ReferencesCite", null, "\\_cite", null,
	        N_("Reference to a bibliography item"), on_ref_cite },

        // LaTeX: Environments
	    { "Environments", STOCK_JUSTIFY_CENTER, "_Environments" },
	    { "EnvironmentCenter", STOCK_JUSTIFY_CENTER, "\\begin{_center}", null,
		    N_("Center - \\begin{center}"), on_env_center },
	    { "EnvironmentLeft", STOCK_JUSTIFY_LEFT, "\\begin{flush_left}", null,
		    N_("Align Left - \\begin{flushleft}"), on_env_left },
	    { "EnvironmentRight", STOCK_JUSTIFY_RIGHT, "\\begin{flush_right}", null,
		    N_("Align Right - \\begin{flushright}"), on_env_right },
	    { "EnvironmentMinipage", null, "\\begin{_minipage}", null,
		    N_("Minipage - \\begin{minipage}"), on_env_minipage },
	    { "EnvironmentQuote", null, "\\begin{_quote}", null,
		    N_("Quote - \\begin{quote}"), on_env_quote },
	    { "EnvironmentQuotation", null, "\\begin{qu_otation}", null,
		    N_("Quotation - \\begin{quotation}"), on_env_quotation },
	    { "EnvironmentVerse", null, "\\begin{_verse}", null,
		    N_("Verse - \\begin{verse}"), on_env_verse },

        // LaTeX: list environments
	    { "ListEnvironments", "list-enumerate", N_("_List Environments") },
	    { "ListEnvItemize", "list-itemize", "\\begin{_itemize}", null,
		    N_("Bulleted List - \\begin{itemize}"), on_list_env_itemize },
	    { "ListEnvEnumerate", "list-enumerate", "\\begin{_enumerate}", null,
		    N_("Enumeration - \\begin{enumerate}"), on_list_env_enumerate },
	    { "ListEnvDescription", "list-description", "\\begin{_description}", null,
		    N_("Description - \\begin{description}"), on_list_env_description },
	    { "ListEnvItem", "list-item", "\\i_tem", null,
		    N_("List item - \\item"), on_list_env_item },

        // LaTeX: character sizes
	    { "CharacterSize", "character-size", N_("_Characters Sizes") },
	    { "CharacterSizeTiny", null, "_tiny", null,
		    "tiny", on_size_tiny },
	    { "CharacterSizeScriptsize", null, "_scriptsize", null,
		    "scriptsize", on_size_scriptsize },
	    { "CharacterSizeFootnotesize", null, "_footnotesize", null,
		    "footnotesize", on_size_footnotesize },
	    { "CharacterSizeSmall", null, "s_mall", null,
		    "small", on_size_small },
	    { "CharacterSizeNormalsize", null, "_normalsize", null,
		    "normalsize", on_size_normalsize },
	    { "CharacterSizelarge", null, "_large", null,
		    "large", on_size_large },
	    { "CharacterSizeLarge", null, "L_arge", null,
		    "Large", on_size_Large },
	    { "CharacterSizeLARGE", null, "LA_RGE", null,
		    "LARGE", on_size_LARGE },
	    { "CharacterSizehuge", null, "_huge", null,
		    "huge", on_size_huge },
	    { "CharacterSizeHuge", null, "H_uge", null,
		    "Huge", on_size_Huge },

        // LaTeX: font styles
	    { "FontStyles", "bold", N_("_Font Styles") },
	    { "Bold", "bold", "\\text_bf{}", null,
		    N_("Bold - \\textbf{}"), on_text_bold },
	    { "Italic", "italic", "\\text_it{}", null,
		    N_("Italic - \\textit{}"), on_text_italic },
	    { "Typewriter", "typewriter", "\\text_tt{}", null,
		    N_("Typewriter - \\texttt{}"), on_text_typewriter },
	    { "Underline", "underline", "\\_underline{}", null,
		    N_("Underline - \\underline{}"), on_text_underline },
	    { "Slanted", null, "\\text_sl{}", null,
		    N_("Slanted - \\textsl{}"), on_text_slanted },
	    { "SmallCaps", null, "\\texts_c{}", null,
		    N_("Small Capitals - \\textsc{}"), on_text_small_caps },
	    { "Emph", null, "\\_emph{}", null,
		    N_("Emphasized - \\emph{}"), on_text_emph },

	    { "FontFamily", null, N_("_Font Family") },
	    { "FontFamilyRoman", null, "\\_rmfamily", null,
		    N_("Roman - \\rmfamily"), on_text_font_family_roman },
	    { "FontFamilySansSerif", null, "\\_sffamily", null,
		    N_("Sans Serif - \\sffamily"), on_text_font_family_sans_serif },
	    { "FontFamilyMonospace", null, "\\_ttfamily", null,
		    N_("Monospace - \\ttfamily"), on_text_font_family_monospace },

	    { "FontSeries", null, N_("F_ont Series") },
	    { "FontSeriesMedium", null, "\\_mdseries", null,
		    N_("Medium - \\mdseries"), on_text_font_series_medium },
	    { "FontSeriesBold", null, "\\_bfseries", null,
		    N_("Bold - \\bfseries"), on_text_font_series_bold },

	    { "FontShape", null, N_("Fo_nt Shape") },
	    { "FontShapeUpright", null, "\\_upshape", null,
		    N_("Upright - \\upshape"), on_text_font_shape_upright },
	    { "FontShapeItalic", null, "\\_itshape", null,
		    N_("Italic - \\itshape"), on_text_font_shape_italic },
	    { "FontShapeSlanted", null, "\\_slshape", null,
		    N_("Slanted - \\slshape"), on_text_font_shape_slanted },
	    { "FontShapeSmallCaps", null, "\\s_cshape", null,
		    N_("Small Capitals - \\scshape"), on_text_font_shape_small_caps },

        // LaTeX: math
	    { "Math", null, N_("_Math") },
	    { "MathEnvironments", null, N_("_Math Environments") },
	    { "MathEnvNormal", "math", N_("_Mathematical Environment - $...$"), null,
		    N_("Mathematical Environment - $...$"), on_math_env_normal },
	    { "MathEnvCentered", "math-centered", N_("_Centered Formula - $$...$$"), null,
		    N_("Centered Formula - $$...$$"), on_math_env_centered },
	    { "MathEnvNumbered", "math-numbered", N_("_Numbered Equation - \\begin{equation}"), null,
		    N_("Numbered Equation - \\begin{equation}"), on_math_env_numbered },
	    { "MathEnvArray", "math-array", N_("_Array of Equations - \\begin{align*}"), null,
		    N_("Array of Equations - \\begin{align*}"), on_math_env_array },
	    { "MathEnvNumberedArray", "math-numbered-array", N_("Numbered Array of _Equations - \\begin{align}"), null,
		    N_("Numbered Array of Equations - \\begin{align}"), on_math_env_numbered_array },
	    { "MathSuperscript", "math-superscript", N_("_Superscript - ^{}"), null,
		    N_("Superscript - ^{}"), on_math_superscript },
	    { "MathSubscript", "math-subscript", N_("Su_bscript - __{}"), null,
		    N_("Subscript - _{}"), on_math_subscript },
	    { "MathFrac", "math-frac", N_("_Fraction - \\frac{}{}"), null,
		    N_("Fraction - \\frac{}{}"), on_math_frac },
	    { "MathSquareRoot", "math-square-root", N_("Square _Root - \\sqrt{}"), null,
		    N_("Square Root - \\sqrt{}"), on_math_square_root },
	    { "MathNthRoot", "math-nth-root", N_("_N-th Root - \\sqrt[]{}"), null,
		    N_("N-th Root - \\sqrt[]{}"), on_math_nth_root },
	    { "MathLeftDelimiters", "delimiters-left", N_("_Left Delimiters") },
	    { "MathLeftDelimiter1", null, N_("left ("), null,
		    null, on_math_left_delimiter_1 },
	    { "MathLeftDelimiter2", null, N_("left ["), null,
		    null, on_math_left_delimiter_2 },
	    { "MathLeftDelimiter3", null, N_("left { "), null,
		    null, on_math_left_delimiter_3 },
	    { "MathLeftDelimiter4", null, N_("left <"), null,
		    null, on_math_left_delimiter_4 },
	    { "MathLeftDelimiter5", null, N_("left )"), null,
		    null, on_math_left_delimiter_5 },
	    { "MathLeftDelimiter6", null, N_("left ]"), null,
		    null, on_math_left_delimiter_6 },
	    { "MathLeftDelimiter7", null, N_("left  }"), null,
		    null, on_math_left_delimiter_7 },
	    { "MathLeftDelimiter8", null, N_("left >"), null,
		    null, on_math_left_delimiter_8 },
	    { "MathLeftDelimiter9", null, N_("left ."), null,
		    null, on_math_left_delimiter_9 },
	    { "MathRightDelimiters", "delimiters-right", N_("Right _Delimiters") },
	    { "MathRightDelimiter1", null, N_("right )"), null,
		    null, on_math_right_delimiter_1 },
	    { "MathRightDelimiter2", null, N_("right ]"), null,
		    null, on_math_right_delimiter_2 },
	    { "MathRightDelimiter3", null, N_("right  }"), null,
		    null, on_math_right_delimiter_3 },
	    { "MathRightDelimiter4", null, N_("right >"), null,
		    null, on_math_right_delimiter_4 },
	    { "MathRightDelimiter5", null, N_("right ("), null,
		    null, on_math_right_delimiter_5 },
	    { "MathRightDelimiter6", null, N_("right ["), null,
		    null, on_math_right_delimiter_6 },
	    { "MathRightDelimiter7", null, N_("right { "), null,
		    null, on_math_right_delimiter_7 },
	    { "MathRightDelimiter8", null, N_("right <"), null,
		    null, on_math_right_delimiter_8 },
	    { "MathRightDelimiter9", null, N_("right ."), null,
		    null, on_math_right_delimiter_9 }
    };

    private unowned MainWindow main_window;

    public LatexMenu (MainWindow main_window)
    {
        GLib.Object (name: "LatexActionGroup");
        set_translation_domain (Config.GETTEXT_PACKAGE);

        this.main_window = main_window;

        // menus under toolitems
        var sectioning = get_menu_tool_action ("SectioningToolItem", _("Sectioning"),
            "sectioning-section");

        var sizes = get_menu_tool_action ("CharacterSizeToolItem", _("Characters Sizes"),
            "character-size");

        var references = get_menu_tool_action ("ReferencesToolItem", _("References"),
            "references");

        var math_env = get_menu_tool_action ("MathEnvironmentsToolItem",
            _("Math Environments"), "math");

        var math_left_del = get_menu_tool_action ("MathLeftDelimitersToolItem",
			_("Left Delimiters"), "delimiters-left");

		var math_right_del = get_menu_tool_action ("MathRightDelimitersToolItem",
			_("Right Delimiters"), "delimiters-right");

		add_actions (latex_action_entries, this);
		add_action (sectioning);
        add_action (sizes);
        add_action (references);
        add_action (math_env);
        add_action (math_left_del);
        add_action (math_right_del);
    }

    private Action get_menu_tool_action (string name, string? label, string? stock_id)
    {
        Action action = new MenuToolAction (name, label, label, stock_id);
        Activatable menu_tool_button = (Activatable) new MenuToolButton (null, null);
        menu_tool_button.set_related_action (action);
        return action;
    }

    private void text_buffer_insert (string text_before, string text_after,
        string? text_if_no_selection = null)
    {
        return_if_fail (main_window.active_tab != null);
        Document active_document = main_window.active_document;

	    // we don't use the insert and selection_bound marks because we don't
	    // know the order. With gtk_text_buffer_get_selection_bounds, we are certain
	    // that "start" points to the start of the selection, where we must insert
	    // "text_before".

	    TextIter start, end;
        bool text_selected = active_document.get_selection_bounds (out start, out end);

        active_document.begin_user_action ();

	    // insert around the selected text
	    // move the cursor to the end
	    if (text_selected)
	    {
	        TextMark mark_end = active_document.create_mark (null, end, false);
            active_document.insert (start, text_before, -1);
            active_document.get_iter_at_mark (out end, mark_end);
            active_document.insert (end, text_after, -1);

            active_document.get_iter_at_mark (out end, mark_end);
		    active_document.select_range (end, end);
	    }

	    // no selection
	    else if (text_if_no_selection != null)
	        active_document.insert_at_cursor (text_if_no_selection, -1);

	    // no selection
	    // move the cursor between the 2 texts inserted
	    else
	    {
	        active_document.insert_at_cursor (text_before, -1);

		    TextIter between;
		    active_document.get_iter_at_mark (out between, active_document.get_insert ());
		    TextMark mark = active_document.create_mark (null, between, true);

            active_document.insert_at_cursor (text_after, -1);

            active_document.get_iter_at_mark (out between, mark);
		    active_document.select_range (between, between);
	    }

        active_document.end_user_action ();
    }

    public void on_documentclass ()
    {
        text_buffer_insert ("\\documentclass{", "}");
    }

    public void on_usepackage ()
    {
        text_buffer_insert ("\\usepackage{", "}");
    }

    public void on_ams_packages ()
    {
        string packages = "\\usepackage{amsmath}\n"
                        + "\\usepackage{amsfonts}\n"
                        + "\\usepackage{amssymb}";
        text_buffer_insert (packages, "");
    }

    public void on_author ()
    {
        text_buffer_insert ("\\author{", "}");
    }

    public void on_title ()
    {
        text_buffer_insert ("\\title{", "}");
    }

    public void on_begin_document ()
    {
        text_buffer_insert ("\\begin{document}\n", "\n\\end{document}");
    }

    public void on_maketitle ()
    {
        text_buffer_insert ("\\maketitle", "");
    }

    public void on_tableofcontents ()
    {
        text_buffer_insert ("\\tableofcontents", "");
    }

    public void on_abstract ()
    {
        text_buffer_insert ("\\begin{abstract}\n", "\n\\end{abstract}");
    }

    /* sectioning */

    public void on_sectioning_part ()
    {
        text_buffer_insert ("\\part{", "}", null);
    }

    public void on_sectioning_chapter ()
    {
        text_buffer_insert ("\\chapter{", "}", null);
    }

    public void on_sectioning_section ()
    {
        text_buffer_insert ("\\section{", "}", null);
    }

    public void on_sectioning_subsection ()
    {
        text_buffer_insert ("\\subsection{", "}", null);
    }

    public void on_sectioning_subsubsection ()
    {
        text_buffer_insert ("\\subsubsection{", "}", null);
    }

    public void on_sectioning_paragraph ()
    {
        text_buffer_insert ("\\paragraph{", "}", null);
    }

    public void on_sectioning_subparagraph ()
    {
        text_buffer_insert ("\\subparagraph{", "}", null);
    }

    /* References */

    public void on_ref_label ()
    {
        text_buffer_insert ("\\label{", "} ", null);
    }

    public void on_ref_ref ()
    {
        text_buffer_insert ("\\ref{", "} ", null);
    }

    public void on_ref_pageref ()
    {
        text_buffer_insert ("\\pageref{", "} ", null);
    }

    public void on_ref_index ()
    {
        text_buffer_insert ("\\index{", "} ", null);
    }

    public void on_ref_footnote ()
    {
        text_buffer_insert ("\\footnote{", "} ", null);
    }

    public void on_ref_cite ()
    {
        text_buffer_insert ("\\cite{", "} ", null);
    }

    /* environments */

    public void on_env_center ()
    {
        text_buffer_insert ("\\begin{center}\n", "\n\\end{center}", null);
    }

    public void on_env_left ()
    {
        text_buffer_insert ("\\begin{flushleft}\n", "\n\\end{flushleft}", null);
    }

    public void on_env_right ()
    {
        text_buffer_insert ("\\begin{flushright}\n", "\n\\end{flushright}", null);
    }

    public void on_env_minipage ()
    {
        text_buffer_insert ("\\begin{minipage}\n", "\n\\end{minipage}", null);
    }

    public void on_env_quote ()
    {
        text_buffer_insert ("\\begin{quote}\n", "\n\\end{quote}", null);
    }

    public void on_env_quotation ()
    {
        text_buffer_insert ("\\begin{quotation}\n", "\n\\end{quotation}", null);
    }

    public void on_env_verse ()
    {
        text_buffer_insert ("\\begin{verse}\n", "\n\\end{verse}", null);
    }

    /* List Environments */

    public void on_list_env_itemize ()
    {
        text_buffer_insert ("\\begin{itemize}\n  \\item ", "\n\\end{itemize}",
                null);
    }

    public void on_list_env_enumerate ()
    {
        text_buffer_insert ("\\begin{enumerate}\n  \\item ", "\n\\end{enumerate}",
                null);
    }

    public void on_list_env_description ()
    {
        text_buffer_insert ("\\begin{description}\n  \\item[",
                "] \n\\end{description}", null);
    }

    public void on_list_env_item ()
    {
        text_buffer_insert ("\\item ", "", null);
    }


    /* Characters sizes */

    public void on_size_tiny ()
    {
        text_buffer_insert ("{\\tiny ", "}", "\\tiny ");
    }

    public void on_size_scriptsize ()
    {
        text_buffer_insert ("{\\scriptsize ", "}", "\\scriptsize ");
    }

    public void on_size_footnotesize ()
    {
        text_buffer_insert ("{\\footnotesize ", "}", "\\footnotesize ");
    }

    public void on_size_small ()
    {
        text_buffer_insert ("{\\small ", "}", "\\small ");
    }

    public void on_size_normalsize ()
    {
        text_buffer_insert ("{\\normalsize ", "}", "\\normalsize ");
    }

    public void on_size_large ()
    {
        text_buffer_insert ("{\\large ", "}", "\\large ");
    }

    public void on_size_Large ()
    {
        text_buffer_insert ("{\\Large ", "}", "\\Large ");
    }

    public void on_size_LARGE ()
    {
        text_buffer_insert ("{\\LARGE ", "}", "\\LARGE ");
    }

    public void on_size_huge ()
    {
        text_buffer_insert ("{\\huge ", "}", "\\huge ");
    }

    public void on_size_Huge ()
    {
        text_buffer_insert ("{\\Huge ", "}", "\\Huge ");
    }

    /* Font styles */

    public void on_text_bold ()
    {
        text_buffer_insert ("\\textbf{", "}", null);
    }

    public void on_text_italic ()
    {
        text_buffer_insert ("\\textit{", "}", null);
    }

    public void on_text_typewriter ()
    {
        text_buffer_insert ("\\texttt{", "}", null);
    }

    public void on_text_underline ()
    {
        text_buffer_insert ("\\underline{", "}", null);
    }

    public void on_text_slanted ()
    {
        text_buffer_insert ("\\textsl{", "}", null);
    }

    public void on_text_small_caps ()
    {
        text_buffer_insert ("\\textsc{", "}", null);
    }

    public void on_text_emph ()
    {
        text_buffer_insert ("\\emph{", "}", null);
    }

    public void on_text_font_family_roman ()
    {
        text_buffer_insert ("{\\rmfamily ", "}", "\\rmfamily ");
    }

    public void on_text_font_family_sans_serif ()
    {
        text_buffer_insert ("{\\sffamily ", "}", "\\sffamily ");
    }

    public void on_text_font_family_monospace ()
    {
        text_buffer_insert ("{\\ttfamily ", "}", "\\ttfamily ");
    }

    public void on_text_font_series_medium ()
    {
        text_buffer_insert ("{\\mdseries ", "}", "\\mdseries ");
    }

    public void on_text_font_series_bold ()
    {
        text_buffer_insert ("{\\bfseries ", "}", "\\bfseries ");
    }

    public void on_text_font_shape_upright ()
    {
        text_buffer_insert ("{\\upshape ", "}", "\\upshape ");
    }

    public void on_text_font_shape_italic ()
    {
        text_buffer_insert ("{\\itshape ", "}", "\\itshape ");
    }

    public void on_text_font_shape_slanted ()
    {
        text_buffer_insert ("{\\slshape ", "}", "\\slshape ");
    }

    public void on_text_font_shape_small_caps ()
    {
        text_buffer_insert ("{\\scshape ", "}", "\\scshape ");
    }

    public void on_math_env_normal ()
    {
        text_buffer_insert ("$ ", " $", null);
    }

    public void on_math_env_centered ()
    {
        text_buffer_insert ("$$ ", " $$", null);
    }

    public void on_math_env_numbered ()
    {
        text_buffer_insert ("\\begin{equation}\n", "\n\\end{equation}", null);
    }

    public void on_math_env_array ()
    {
        text_buffer_insert ("\\begin{align*}\n", "\n\\end{align*}", null);
    }

    public void on_math_env_numbered_array ()
    {
        text_buffer_insert ("\\begin{align}\n", "\n\\end{align}", null);
    }

    public void on_math_superscript ()
    {
        text_buffer_insert ("^{", "}", null);
    }

    public void on_math_subscript ()
    {
        text_buffer_insert ("_{", "}", null);
    }

    public void on_math_frac ()
    {
        text_buffer_insert ("\\frac{", "}{}", null);
    }

    public void on_math_square_root ()
    {
        text_buffer_insert ("\\sqrt{", "}", null);
    }

    public void on_math_nth_root ()
    {
        text_buffer_insert ("\\sqrt[]{", "}", null);
    }

    public void on_math_left_delimiter_1 ()
    {
        text_buffer_insert ("\\left( ", "", null);
    }

    public void on_math_left_delimiter_2 ()
    {
        text_buffer_insert ("\\left[ ", "", null);
    }

    public void on_math_left_delimiter_3 ()
    {
        text_buffer_insert ("\\left\\lbrace ", "", null);
    }

    public void on_math_left_delimiter_4 ()
    {
        text_buffer_insert ("\\left\\langle ", "", null);
    }

    public void on_math_left_delimiter_5 ()
    {
        text_buffer_insert ("\\left) ", "", null);
    }

    public void on_math_left_delimiter_6 ()
    {
        text_buffer_insert ("\\left] ", "", null);
    }

    public void on_math_left_delimiter_7 ()
    {
        text_buffer_insert ("\\left\\rbrace ", "", null);
    }

    public void on_math_left_delimiter_8 ()
    {
        text_buffer_insert ("\\left\\rangle ", "", null);
    }

    public void on_math_left_delimiter_9 ()
    {
        text_buffer_insert ("\\left. ", "", null);
    }

    public void on_math_right_delimiter_1 ()
    {
        text_buffer_insert ("\\right( ", "", null);
    }

    public void on_math_right_delimiter_2 ()
    {
        text_buffer_insert ("\\right[ ", "", null);
    }

    public void on_math_right_delimiter_3 ()
    {
        text_buffer_insert ("\\right\\rbrace ", "", null);
    }

    public void on_math_right_delimiter_4 ()
    {
        text_buffer_insert ("\\right\\rangle ", "", null);
    }

    public void on_math_right_delimiter_5 ()
    {
        text_buffer_insert ("\\right) ", "", null);
    }

    public void on_math_right_delimiter_6 ()
    {
        text_buffer_insert ("\\right] ", "", null);
    }

    public void on_math_right_delimiter_7 ()
    {
        text_buffer_insert ("\\right\\lbrace ", "", null);
    }

    public void on_math_right_delimiter_8 ()
    {
        text_buffer_insert ("\\right\\langle ", "", null);
    }

    public void on_math_right_delimiter_9 ()
    {
        text_buffer_insert ("\\right. ", "", null);
    }
}
