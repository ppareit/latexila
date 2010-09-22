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
	    { "EnvCenter", STOCK_JUSTIFY_CENTER, "\\begin{_center}", null,
		    N_("Center - \\begin{center}"), on_env_center },
	    { "EnvLeft", STOCK_JUSTIFY_LEFT, "\\begin{flush_left}", null,
		    N_("Align Left - \\begin{flushleft}"), on_env_left },
	    { "EnvRight", STOCK_JUSTIFY_RIGHT, "\\begin{flush_right}", null,
		    N_("Align Right - \\begin{flushright}"), on_env_right },
		{ "EnvFigure", null, "\\begin{_figure}", null,
		    N_("Figure - \\begin{figure}"), on_env_figure },
		{ "EnvTable", null, "\\begin{_table}", null,
		    N_("Table - \\begin{table}"), on_env_table },
		{ "EnvQuote", null, "\\begin{_quote}", null,
		    N_("Quote - \\begin{quote}"), on_env_quote },
	    { "EnvQuotation", null, "\\begin{qu_otation}", null,
		    N_("Quotation - \\begin{quotation}"), on_env_quotation },
	    { "EnvVerse", null, "\\begin{_verse}", null,
		    N_("Verse - \\begin{verse}"), on_env_verse },
		{ "EnvVerbatim", null, "\\begin{ver_batim}", null,
		    N_("Verbatim - \\begin{verbatim}"), on_env_verbatim },
	    { "EnvMinipage", null, "\\begin{_minipage}", null,
		    N_("Minipage - \\begin{minipage}"), on_env_minipage },
		{ "EnvTitlepage", null, "\\begin{titlepage}", null,
		    N_("Title page - \\begin{titlepage}"), on_env_titlepage },

        // LaTeX: list environments
	    { "ListEnvironments", "list-enumerate", N_("_List Environments") },
	    { "ListEnvItemize", "list-itemize", "\\begin{_itemize}", null,
		    N_("Bulleted List - \\begin{itemize}"), on_list_env_itemize },
	    { "ListEnvEnumerate", "list-enumerate", "\\begin{_enumerate}", null,
		    N_("Enumeration - \\begin{enumerate}"), on_list_env_enumerate },
	    { "ListEnvDescription", "list-description", "\\begin{_description}", null,
		    N_("Description - \\begin{description}"), on_list_env_description },
		{ "ListEnvList", null, "\\begin{_list}", null,
		    N_("Custom list - \\begin{list}"), on_list_env_list },
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
	    { "Bold", "bold", "\\text_bf", null,
		    N_("Bold - \\textbf"), on_text_bold },
	    { "Italic", "italic", "\\text_it", null,
		    N_("Italic - \\textit"), on_text_italic },
	    { "Typewriter", "typewriter", "\\text_tt", null,
		    N_("Typewriter - \\texttt"), on_text_typewriter },
		{ "Slanted", "slanted", "\\text_sl", null,
		    N_("Slanted - \\textsl"), on_text_slanted },
	    { "SmallCaps", null, "\\texts_c", null,
		    N_("Small Capitals - \\textsc"), on_text_small_caps },
		{ "SansSerif", null, "\\texts_f", null,
		    N_("Sans Serif - \\textsf"), on_text_sans_serif },
		{ "Emph", null, "\\_emph", null,
		    N_("Emphasized - \\emph"), on_text_emph },
	    { "Underline", "underline", "\\_underline", null,
		    N_("Underline - \\underline"), on_text_underline },

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

		// Tabular

		{ "Tabular", null, N_("_Tabular") },
		{ "TabularTabbing", null, "\\begin{ta_bbing}", null,
		    N_("Tabbing - \\begin{tabbing}"), on_tabular_tabbing },
		{ "TabularTabular", null, "\\begin{_tabular}", null,
		    N_("Tabular - \\begin{tabular}"), on_tabular_tabular },
		{ "TabularMulticolumn", null, "\\_multicolumn", null,
		    N_("Multicolumn - \\multicolumn"), on_tabular_multicolumn },
		{ "TabularHline", null, "\\_hline", null,
		    N_("Horizontal line - \\hline"), on_tabular_hline },
		{ "TabularVline", null, "\\_vline", null,
		    N_("Vertical line - \\vline"), on_tabular_vline },
		{ "TabularCline", null, "\\_cline", null,
		    N_("Horizontal line (columns specified) - \\cline"), on_tabular_cline },

		// Spacing

		{ "Spacing", null, N_("_Spacing") },
		{ "SpacingNewLine", null, N_("New _Line"), null,
		    N_("New Line - \\\\"), on_spacing_new_line },
		{ "SpacingNewPage", null, "\\new_page", null,
		    N_("New page - \\newpage"), on_spacing_new_page },
		{ "SpacingLineBreak", null, "\\l_inebreak", null,
		    N_("Line break - \\linebreak"), on_spacing_line_break },
		{ "SpacingPageBreak", null, "\\p_agebreak", null,
		    N_("Page break - \\pagebreak"), on_spacing_page_break },
		{ "SpacingBigSkip", null, "\\_bigskip", null,
		    N_("Big skip - \\bigskip"), on_spacing_bigskip },
		{ "SpacingMedSkip", null, "\\_medskip", null,
		    N_("Medium skip - \\medskip"), on_spacing_medskip },
		{ "SpacingHSpace", null, "\\_hspace", null,
		    N_("Horizontal space - \\hspace"), on_spacing_hspace },
		{ "SpacingVSpace", null, "\\_vspace", null,
		    N_("Vertical space - \\vspace"), on_spacing_vspace },
		{ "SpacingNoIndent", null, "\\_noindent", null,
		    N_("No paragraph indentation - \\noindent"), on_spacing_noindent },

		// International accents

		{ "Accents", null, N_("International _Accents") },
		{ "Accent0", "accent0", "\\'", null, N_("Acute accent - \\'"), on_accent0 },
		{ "Accent1", "accent1", "\\`", null, N_("Grave accent - \\`"), on_accent1 },
		{ "Accent2", "accent2", "\\^", null, N_("Circumflex accent - \\^"), on_accent2 },
		{ "Accent3", "accent3", "\\\"", null, N_("Trema - \\\""), on_accent3 },
		{ "Accent4", "accent4", "\\~", null, N_("Tilde - \\~"), on_accent4 },
		{ "Accent5", "accent5", "\\=", null, N_("Macron - \\="), on_accent5 },
		{ "Accent6", "accent6", "\\.", null, N_("Dot - \\."), on_accent6 },
		{ "Accent7", "accent7", "\\v", null, N_("Caron - \\v"), on_accent7 },
		{ "Accent8", "accent8", "\\u", null, N_("Breve - \\u"), on_accent8 },
		{ "Accent9", "accent9", "\\H", null,
		    N_("Double acute accent - \\H"), on_accent9 },

		// Others

        { "LatexMisc", null, N_("_Misc") },
		{ "LatexDocumentClass", null, "\\_documentclass", null,
            N_("Document class - \\documentclass"), on_documentclass },
        { "LatexUsepackage", null, "\\_usepackage", null,
            N_("Use package - \\usepackage"), on_usepackage },
        { "LatexAMS", null, N_("_AMS packages"), null,
            N_("AMS packages"), on_ams_packages },
        { "LatexAuthor", null, "\\au_thor", null, N_("Author - \\author"), on_author },
        { "LatexTitle", null, "\\t_itle", null, N_("Title - \\title"), on_title },
        { "LatexBeginDocument", null, "\\begin{d_ocument}", null,
            N_("Content of the document - \\begin{document}"), on_begin_document },
        { "LatexMakeTitle", null, "\\_maketitle", null,
            N_("Make title - \\maketitle"), on_maketitle },
        { "LatexTableOfContents", null, "\\tableof_contents", null,
            N_("Table of contents - \\tableofcontents"), on_tableofcontents },
        { "LatexAbstract", null, "\\begin{abst_ract}", null,
            N_("Abstract - \\begin{abstract}"), on_abstract },
        { "LatexIncludeGraphics", null, "\\include_graphics", null,
            N_("Include an image (graphicx package) - \\includegraphics"),
            on_include_graphics },
        { "LatexInput", null, "\\_input", null,
            N_("Include a file - \\input"), on_input },

        // LaTeX: math

	    { "Math", null, N_("_Math") },

        // Math Environments

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

        // Math functions

        { "MathFunctions", null, N_("Math _Functions") },
        { "MathFuncArccos", null, "\\arccos", null, null, on_math_func_arccos },
        { "MathFuncArcsin", null, "\\arcsin", null, null, on_math_func_arcsin },
        { "MathFuncArctan", null, "\\arctan", null, null, on_math_func_arctan },
        { "MathFuncCos", null, "\\cos", null, null, on_math_func_cos },
        { "MathFuncCosh", null, "\\cosh", null, null, on_math_func_cosh },
        { "MathFuncCot", null, "\\cot", null, null, on_math_func_cot },
        { "MathFuncCoth", null, "\\coth", null, null, on_math_func_coth },
        { "MathFuncCsc", null, "\\csc", null, null, on_math_func_csc },
        { "MathFuncDeg", null, "\\deg", null, null, on_math_func_deg },
        { "MathFuncDet", null, "\\det", null, null, on_math_func_det },
        { "MathFuncDim", null, "\\dim", null, null, on_math_func_dim },
        { "MathFuncExp", null, "\\exp", null, null, on_math_func_exp },
        { "MathFuncGcd", null, "\\gcd", null, null, on_math_func_gcd },
        { "MathFuncHom", null, "\\hom", null, null, on_math_func_hom },
        { "MathFuncInf", null, "\\inf", null, null, on_math_func_inf },
        { "MathFuncKer", null, "\\ker", null, null, on_math_func_ker },
        { "MathFuncLg", null, "\\lg", null, null, on_math_func_lg },
        { "MathFuncLim", null, "\\lim", null, null, on_math_func_lim },
        { "MathFuncLiminf", null, "\\liminf", null, null, on_math_func_liminf },
        { "MathFuncLimsup", null, "\\limsup", null, null, on_math_func_limsup },
        { "MathFuncLn", null, "\\ln", null, null, on_math_func_ln },
        { "MathFuncLog", null, "\\log", null, null, on_math_func_log },
        { "MathFuncMax", null, "\\max", null, null, on_math_func_max },
        { "MathFuncMin", null, "\\min", null, null, on_math_func_min },
        { "MathFuncSec", null, "\\sec", null, null, on_math_func_sec },
        { "MathFuncSin", null, "\\sin", null, null, on_math_func_sin },
        { "MathFuncSinh", null, "\\sinh", null, null, on_math_func_sinh },
        { "MathFuncSup", null, "\\sup", null, null, on_math_func_sup },
        { "MathFuncTan", null, "\\tan", null, null, on_math_func_tan },
        { "MathFuncTanh", null, "\\tanh", null, null, on_math_func_tanh },

        // Math Font Styles

        { "MathFontStyles", null, N_("Math Font _Styles") },
        { "MathFSrm", null, "\\math_rm", null,
            N_("Roman - \\mathrm"), on_math_font_style_rm },
        { "MathFSit", "italic", "\\math_it", null,
            N_("Italic - \\mathit"), on_math_font_style_it },
        { "MathFSbf", "bold", "\\math_bf", null,
            N_("Bold - \\mathbf"), on_math_font_style_bf },
        { "MathFSsf", null, "\\math_sf", null,
            N_("Sans Serif - \\mathsf"), on_math_font_style_sf },
        { "MathFStt", "typewriter", "\\math_tt", null,
            N_("Typewriter - \\mathtt"), on_math_font_style_tt },
        { "MathFScal", null, "\\math_cal", null,
            N_("Calligraphic - \\mathcal"), on_math_font_style_cal },
        { "MathFSbb", "blackboard", "\\_mathbb", null,
            N_("Blackboard (uppercase only)  - \\mathbb (amsfonts package)"),
            on_math_font_style_bb },
        { "MathFSfrak", null, "\\math_frak", null,
            N_("Euler Fraktur - \\mathfrak (amsfonts package)"),
            on_math_font_style_frak },

        // Math Accents

        { "MathAccents", null, N_("Math _Accents") },
        { "MathAccentAcute", null, "\\_acute", null, null, on_math_accent_acute },
        { "MathAccentGrave", null, "\\_grave", null, null, on_math_accent_grave },
        { "MathAccentTilde", null, "\\_tilde", null, null, on_math_accent_tilde },
        { "MathAccentBar", null, "\\_bar", null, null, on_math_accent_bar },
        { "MathAccentVec", null, "\\_vec", null, null, on_math_accent_vec },
        { "MathAccentHat", null, "\\_hat", null, null, on_math_accent_hat },
        { "MathAccentCheck", null, "\\_check", null, null, on_math_accent_check },
        { "MathAccentBreve", null, "\\b_reve", null, null, on_math_accent_breve },
        { "MathAccentDot", null, "\\_dot", null, null, on_math_accent_dot },
        { "MathAccentDdot", null, "\\dd_ot", null, null, on_math_accent_ddot },
        { "MathAccentRing", null, "\\_mathring", null, null, on_math_accent_ring },

        // Math Spaces

        { "MathSpaces", null, N_("Math _Spaces") },
        { "MathSpaceSmall", null, N_("_Small"), null,
            N_("Small - \\,"), on_math_space_small },
        { "MathSpaceMedium", null, N_("_Medium"), null,
            N_("Medium - \\:"), on_math_space_medium },
        { "MathSpaceLarge", null, N_("_Large"), null,
            N_("Large - \\;"), on_math_space_large },
        { "MathSpaceQuad", null, "\\_quad", null, null, on_math_space_quad },
        { "MathSpaceQquad", null, "\\qqu_ad", null, null, on_math_space_qquad },

        // Left Delimiters

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

        // Right Delimiters

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

    private string get_indentation ()
    {
        DocumentView view = main_window.active_view;
        return Utils.get_indentation_style (view);
    }

    private void insert_character_style (string style)
    {
        return_if_fail (main_window.active_tab != null);

        if (main_window.active_document.get_selection_type ()
            == SelectionType.MULTIPLE_LINES)
            text_buffer_insert (@"\\begin{$style}\n", @"\n\\end{$style}");
        else
            text_buffer_insert (@"{\\$style ", "}", @"\\$style ");
    }

    /* Sectioning */

    public void on_sectioning_part ()
    {
        text_buffer_insert ("\\part{", "}");
    }

    public void on_sectioning_chapter ()
    {
        text_buffer_insert ("\\chapter{", "}");
    }

    public void on_sectioning_section ()
    {
        text_buffer_insert ("\\section{", "}");
    }

    public void on_sectioning_subsection ()
    {
        text_buffer_insert ("\\subsection{", "}");
    }

    public void on_sectioning_subsubsection ()
    {
        text_buffer_insert ("\\subsubsection{", "}");
    }

    public void on_sectioning_paragraph ()
    {
        text_buffer_insert ("\\paragraph{", "}");
    }

    public void on_sectioning_subparagraph ()
    {
        text_buffer_insert ("\\subparagraph{", "}");
    }

    /* References */

    public void on_ref_label ()
    {
        text_buffer_insert ("\\label{", "} ");
    }

    public void on_ref_ref ()
    {
        text_buffer_insert ("\\ref{", "} ");
    }

    public void on_ref_pageref ()
    {
        text_buffer_insert ("\\pageref{", "} ");
    }

    public void on_ref_index ()
    {
        text_buffer_insert ("\\index{", "} ");
    }

    public void on_ref_footnote ()
    {
        text_buffer_insert ("\\footnote{", "} ");
    }

    public void on_ref_cite ()
    {
        text_buffer_insert ("\\cite{", "} ");
    }

    /* Environments */

    public void on_env_center ()
    {
        text_buffer_insert ("\\begin{center}\n", "\n\\end{center}");
    }

    public void on_env_left ()
    {
        text_buffer_insert ("\\begin{flushleft}\n", "\n\\end{flushleft}");
    }

    public void on_env_right ()
    {
        text_buffer_insert ("\\begin{flushright}\n", "\n\\end{flushright}");
    }

    public void on_env_figure ()
    {
        text_buffer_insert ("\\begin{figure}\n", "\n\\caption{}\n\\end{figure}");
    }

    public void on_env_table ()
    {
        text_buffer_insert ("\\begin{table}\n", "\n\\caption{}\n\\end{table}");
    }

    public void on_env_quote ()
    {
        text_buffer_insert ("\\begin{quote}\n", "\n\\end{quote}");
    }

    public void on_env_quotation ()
    {
        text_buffer_insert ("\\begin{quotation}\n", "\n\\end{quotation}");
    }

    public void on_env_verse ()
    {
        text_buffer_insert ("\\begin{verse}\n", "\n\\end{verse}");
    }

    public void on_env_verbatim ()
    {
        text_buffer_insert ("\\begin{verbatim}\n", "\n\\end{verbatim}");
    }

    public void on_env_minipage ()
    {
        text_buffer_insert ("\\begin{minipage}\n", "\n\\end{minipage}");
    }

    public void on_env_titlepage ()
    {
        text_buffer_insert ("\\begin{titlepage}\n", "\n\\end{titlepage}");
    }

    /* List Environments */

    public void on_list_env_itemize ()
    {
        string indent = get_indentation ();
        text_buffer_insert (@"\\begin{itemize}\n$indent\\item ", "\n\\end{itemize}");
    }

    public void on_list_env_enumerate ()
    {
        string indent = get_indentation ();
        text_buffer_insert (@"\\begin{enumerate}\n$indent\\item ", "\n\\end{enumerate}");
    }

    public void on_list_env_description ()
    {
        string indent = get_indentation ();
        text_buffer_insert (@"\\begin{description}\n$indent\\item[",
                "] \n\\end{description}");
    }

    public void on_list_env_list ()
    {
        string indent = get_indentation ();
        text_buffer_insert ("\\begin{list}{", @"}{}\n$indent\\item \n\\end{list}");
    }

    public void on_list_env_item ()
    {
        text_buffer_insert ("\\item ", "");
    }

    /* Characters sizes */

    public void on_size_tiny ()
    {
        insert_character_style ("tiny");
    }

    public void on_size_scriptsize ()
    {
        insert_character_style ("scriptsize");
    }

    public void on_size_footnotesize ()
    {
        insert_character_style ("footnotesize");
    }

    public void on_size_small ()
    {
        insert_character_style ("small");
    }

    public void on_size_normalsize ()
    {
        insert_character_style ("normalsize");
    }

    public void on_size_large ()
    {
        insert_character_style ("large");
    }

    public void on_size_Large ()
    {
        insert_character_style ("Large");
    }

    public void on_size_LARGE ()
    {
        insert_character_style ("LARGE");
    }

    public void on_size_huge ()
    {
        insert_character_style ("huge");
    }

    public void on_size_Huge ()
    {
        insert_character_style ("Huge");
    }

    /* Font styles */

    public void on_text_bold ()
    {
        text_buffer_insert ("\\textbf{", "}");
    }

    public void on_text_italic ()
    {
        text_buffer_insert ("\\textit{", "}");
    }

    public void on_text_typewriter ()
    {
        text_buffer_insert ("\\texttt{", "}");
    }

    public void on_text_slanted ()
    {
        text_buffer_insert ("\\textsl{", "}");
    }

    public void on_text_small_caps ()
    {
        text_buffer_insert ("\\textsc{", "}");
    }

    public void on_text_sans_serif ()
    {
        text_buffer_insert ("\\textsf{", "}");
    }

    public void on_text_emph ()
    {
        text_buffer_insert ("\\emph{", "}");
    }

    public void on_text_underline ()
    {
        text_buffer_insert ("\\underline{", "}");
    }

    public void on_text_font_family_roman ()
    {
        insert_character_style ("rmfamily");
    }

    public void on_text_font_family_sans_serif ()
    {
        insert_character_style ("sffamily");
    }

    public void on_text_font_family_monospace ()
    {
        insert_character_style ("ttfamily");
    }

    public void on_text_font_series_medium ()
    {
        insert_character_style ("mdseries");
    }

    public void on_text_font_series_bold ()
    {
        insert_character_style ("bfseries");
    }

    public void on_text_font_shape_upright ()
    {
        insert_character_style ("upshape");
    }

    public void on_text_font_shape_italic ()
    {
        insert_character_style ("itshape");
    }

    public void on_text_font_shape_slanted ()
    {
        insert_character_style ("slshape");
    }

    public void on_text_font_shape_small_caps ()
    {
        insert_character_style ("scshape");
    }

    /* Tabular */

    public void on_tabular_tabbing ()
    {
        text_buffer_insert ("\\begin{tabbing}\n", "\n\\end{tabbing}");
    }

    public void on_tabular_tabular ()
    {
        text_buffer_insert ("\\begin{tabular}\n", "\n\\end{tabular}");
    }

    public void on_tabular_multicolumn ()
    {
        text_buffer_insert ("\\multicolumn{}{}{", "}");
    }

    public void on_tabular_hline ()
    {
        text_buffer_insert ("\\hline ", "");
    }

    public void on_tabular_vline ()
    {
        text_buffer_insert ("\\vline ", "");
    }

    public void on_tabular_cline ()
    {
        text_buffer_insert ("\\cline{", "-}");
    }

    /* Spacing */

    public void on_spacing_new_line ()
    {
        text_buffer_insert ("\\\\\n", "");
    }

    public void on_spacing_new_page ()
    {
        text_buffer_insert ("\\newpage\n", "");
    }

    public void on_spacing_line_break ()
    {
        text_buffer_insert ("\\linebreak\n", "");
    }

    public void on_spacing_page_break ()
    {
        text_buffer_insert ("\\pagebreak\n", "");
    }

    public void on_spacing_bigskip ()
    {
        text_buffer_insert ("\\bigskip ", "");
    }

    public void on_spacing_medskip ()
    {
        text_buffer_insert ("\\medskip ", "");
    }

    public void on_spacing_hspace ()
    {
        text_buffer_insert ("\\hspace{", "}");
    }

    public void on_spacing_vspace ()
    {
        text_buffer_insert ("\\vspace{", "}");
    }

    public void on_spacing_noindent ()
    {
        text_buffer_insert ("\\noindent ", "");
    }

    /* International accents */

    public void on_accent0 ()
    {
        text_buffer_insert ("\\'{", "}");
    }

    public void on_accent1 ()
    {
        text_buffer_insert ("\\`{", "}");
    }

    public void on_accent2 ()
    {
        text_buffer_insert ("\\^{", "}");
    }

    public void on_accent3 ()
    {
        text_buffer_insert ("\\\"{", "}");
    }

    public void on_accent4 ()
    {
        text_buffer_insert ("\\~{", "}");
    }

    public void on_accent5 ()
    {
        text_buffer_insert ("\\={", "}");
    }

    public void on_accent6 ()
    {
        text_buffer_insert ("\\.{", "}");
    }

    public void on_accent7 ()
    {
        text_buffer_insert ("\\v{", "}");
    }

    public void on_accent8 ()
    {
        text_buffer_insert ("\\u{", "}");
    }

    public void on_accent9 ()
    {
        text_buffer_insert ("\\H{", "}");
    }

    /* Others */

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

    public void on_include_graphics ()
    {
        text_buffer_insert ("\\includegraphics{", "}");
    }

    public void on_input ()
    {
        text_buffer_insert ("\\input{", "}");
    }

    /* Math environments */

    public void on_math_env_normal ()
    {
        text_buffer_insert ("$ ", " $");
    }

    public void on_math_env_centered ()
    {
        text_buffer_insert ("$$ ", " $$");
    }

    public void on_math_env_numbered ()
    {
        text_buffer_insert ("\\begin{equation}\n", "\n\\end{equation}");
    }

    public void on_math_env_array ()
    {
        text_buffer_insert ("\\begin{align*}\n", "\n\\end{align*}");
    }

    public void on_math_env_numbered_array ()
    {
        text_buffer_insert ("\\begin{align}\n", "\n\\end{align}");
    }

    public void on_math_superscript ()
    {
        text_buffer_insert ("^{", "}");
    }

    public void on_math_subscript ()
    {
        text_buffer_insert ("_{", "}");
    }

    public void on_math_frac ()
    {
        text_buffer_insert ("\\frac{", "}{}");
    }

    public void on_math_square_root ()
    {
        text_buffer_insert ("\\sqrt{", "}");
    }

    public void on_math_nth_root ()
    {
        text_buffer_insert ("\\sqrt[]{", "}");
    }

    /* Math Functions */

    public void on_math_func_arccos ()
    {
        text_buffer_insert ("\\arccos ", "");
    }

    public void on_math_func_arcsin ()
    {
        text_buffer_insert ("\\arcsin ", "");
    }

    public void on_math_func_arctan ()
    {
        text_buffer_insert ("\\arctan ", "");
    }

    public void on_math_func_cos ()
    {
        text_buffer_insert ("\\cos ", "");
    }

    public void on_math_func_cosh ()
    {
        text_buffer_insert ("\\cosh ", "");
    }

    public void on_math_func_cot ()
    {
        text_buffer_insert ("\\cot ", "");
    }

    public void on_math_func_coth ()
    {
        text_buffer_insert ("\\coth ", "");
    }

    public void on_math_func_csc ()
    {
        text_buffer_insert ("\\csc ", "");
    }

    public void on_math_func_deg ()
    {
        text_buffer_insert ("\\deg ", "");
    }

    public void on_math_func_det ()
    {
        text_buffer_insert ("\\det ", "");
    }

    public void on_math_func_dim ()
    {
        text_buffer_insert ("\\dim ", "");
    }

    public void on_math_func_exp ()
    {
        text_buffer_insert ("\\exp ", "");
    }

    public void on_math_func_gcd ()
    {
        text_buffer_insert ("\\gcd ", "");
    }

    public void on_math_func_hom ()
    {
        text_buffer_insert ("\\hom ", "");
    }

    public void on_math_func_inf ()
    {
        text_buffer_insert ("\\inf ", "");
    }

    public void on_math_func_ker ()
    {
        text_buffer_insert ("\\ker ", "");
    }

    public void on_math_func_lg ()
    {
        text_buffer_insert ("\\lg ", "");
    }

    public void on_math_func_lim ()
    {
        text_buffer_insert ("\\lim ", "");
    }

    public void on_math_func_liminf ()
    {
        text_buffer_insert ("\\liminf ", "");
    }

    public void on_math_func_limsup ()
    {
        text_buffer_insert ("\\limsup ", "");
    }

    public void on_math_func_ln ()
    {
        text_buffer_insert ("\\ln ", "");
    }

    public void on_math_func_log ()
    {
        text_buffer_insert ("\\log ", "");
    }

    public void on_math_func_max ()
    {
        text_buffer_insert ("\\max ", "");
    }

    public void on_math_func_min ()
    {
        text_buffer_insert ("\\min ", "");
    }

    public void on_math_func_sec ()
    {
        text_buffer_insert ("\\sec ", "");
    }

    public void on_math_func_sin ()
    {
        text_buffer_insert ("\\sin ", "");
    }

    public void on_math_func_sinh ()
    {
        text_buffer_insert ("\\sinh ", "");
    }

    public void on_math_func_sup ()
    {
        text_buffer_insert ("\\sup ", "");
    }

    public void on_math_func_tan ()
    {
        text_buffer_insert ("\\tan ", "");
    }

    public void on_math_func_tanh ()
    {
        text_buffer_insert ("\\tanh ", "");
    }

    /* Math Font Styles */

    public void on_math_font_style_rm ()
    {
        text_buffer_insert ("\\mathrm{", "}");
    }

    public void on_math_font_style_it ()
    {
        text_buffer_insert ("\\mathit{", "}");
    }

    public void on_math_font_style_bf ()
    {
        text_buffer_insert ("\\mathbf{", "}");
    }

    public void on_math_font_style_sf ()
    {
        text_buffer_insert ("\\mathsf{", "}");
    }

    public void on_math_font_style_tt ()
    {
        text_buffer_insert ("\\mathtt{", "}");
    }

    public void on_math_font_style_cal ()
    {
        text_buffer_insert ("\\mathcal{", "}");
    }

    public void on_math_font_style_bb ()
    {
        text_buffer_insert ("\\mathbb{", "}");
    }

    public void on_math_font_style_frak ()
    {
        text_buffer_insert ("\\mathfrak{", "}");
    }

    /* Math Accents */

    public void on_math_accent_acute ()
    {
        text_buffer_insert ("\\acute{", "}");
    }

    public void on_math_accent_grave ()
    {
        text_buffer_insert ("\\grave{", "}");
    }

    public void on_math_accent_tilde ()
    {
        text_buffer_insert ("\\tilde{", "}");
    }

    public void on_math_accent_bar ()
    {
        text_buffer_insert ("\\bar{", "}");
    }

    public void on_math_accent_vec ()
    {
        text_buffer_insert ("\\vec{", "}");
    }

    public void on_math_accent_hat ()
    {
        text_buffer_insert ("\\hat{", "}");
    }

    public void on_math_accent_check ()
    {
        text_buffer_insert ("\\check{", "}");
    }

    public void on_math_accent_breve ()
    {
        text_buffer_insert ("\\breve{", "}");
    }

    public void on_math_accent_dot ()
    {
        text_buffer_insert ("\\dot{", "}");
    }

    public void on_math_accent_ddot ()
    {
        text_buffer_insert ("\\ddot{", "}");
    }

    public void on_math_accent_ring ()
    {
        text_buffer_insert ("\\mathring{", "}");
    }

    /* Math Spaces */

    public void on_math_space_small ()
    {
        text_buffer_insert ("\\, ", "");
    }

    public void on_math_space_medium ()
    {
        text_buffer_insert ("\\: ", "");
    }

    public void on_math_space_large ()
    {
        text_buffer_insert ("\\; ", "");
    }

    public void on_math_space_quad ()
    {
        text_buffer_insert ("\\quad ", "");
    }

    public void on_math_space_qquad ()
    {
        text_buffer_insert ("\\qquad ", "");
    }

    /* Left Delimiters */

    public void on_math_left_delimiter_1 ()
    {
        text_buffer_insert ("\\left( ", "");
    }

    public void on_math_left_delimiter_2 ()
    {
        text_buffer_insert ("\\left[ ", "");
    }

    public void on_math_left_delimiter_3 ()
    {
        text_buffer_insert ("\\left\\lbrace ", "");
    }

    public void on_math_left_delimiter_4 ()
    {
        text_buffer_insert ("\\left\\langle ", "");
    }

    public void on_math_left_delimiter_5 ()
    {
        text_buffer_insert ("\\left) ", "");
    }

    public void on_math_left_delimiter_6 ()
    {
        text_buffer_insert ("\\left] ", "");
    }

    public void on_math_left_delimiter_7 ()
    {
        text_buffer_insert ("\\left\\rbrace ", "");
    }

    public void on_math_left_delimiter_8 ()
    {
        text_buffer_insert ("\\left\\rangle ", "");
    }

    public void on_math_left_delimiter_9 ()
    {
        text_buffer_insert ("\\left. ", "");
    }

    public void on_math_right_delimiter_1 ()
    {
        text_buffer_insert ("\\right( ", "");
    }

    public void on_math_right_delimiter_2 ()
    {
        text_buffer_insert ("\\right[ ", "");
    }

    public void on_math_right_delimiter_3 ()
    {
        text_buffer_insert ("\\right\\rbrace ", "");
    }

    public void on_math_right_delimiter_4 ()
    {
        text_buffer_insert ("\\right\\rangle ", "");
    }

    public void on_math_right_delimiter_5 ()
    {
        text_buffer_insert ("\\right) ", "");
    }

    public void on_math_right_delimiter_6 ()
    {
        text_buffer_insert ("\\right] ", "");
    }

    public void on_math_right_delimiter_7 ()
    {
        text_buffer_insert ("\\right\\lbrace ", "");
    }

    public void on_math_right_delimiter_8 ()
    {
        text_buffer_insert ("\\right\\langle ", "");
    }

    public void on_math_right_delimiter_9 ()
    {
        text_buffer_insert ("\\right. ", "");
    }
}
