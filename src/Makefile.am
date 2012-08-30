SUBDIRS = gedit resources ui

bin_PROGRAMS = latexila

VALAFLAGS =			\
	--pkg gtk+-3.0		\
	--pkg gtksourceview-3.0	\
	--pkg gee-1.0		\
	--pkg posix

# The valac command is always executed in the sources directory, not the build
# directory. If $(top_srcdir) is used, it will be relative to the build directory.
vapidir = ../vapi

latexila_SOURCES = 			\
	app_settings.vala		\
	bottom_panel.vala		\
	build_command_runner.vala	\
	build_job_runner.vala		\
	build_tool_dialog.vala		\
	build_tool_runner.vala		\
	build_tools_preferences.vala	\
	build_tools.vala		\
	build_view.vala			\
	clean_build_files.vala		\
	completion.vala			\
	custom_statusbar.vala		\
	dialogs.vala			\
	documents_panel.vala		\
	document_structure.vala		\
	document_tab.vala		\
	document.vala			\
	document_view.vala		\
	encodings.vala			\
	error_entry.vala		\
	file_browser.vala		\
	latexila.vala			\
	latex_menu.vala			\
	latex_post_processor.vala	\
	main.vala			\
	main_window_build_tools.vala	\
	main_window_documents.vala	\
	main_window_edit.vala		\
	main_window_file.vala		\
	main_window_structure.vala	\
	main_window.vala		\
	menu_in_toolbar.vala		\
	most_used_symbols.vala		\
	post_processors.vala		\
	preferences_dialog.vala		\
	project_dialogs.vala		\
	projects.vala			\
	search.vala			\
	side_panel.vala			\
	stock_icons.vala		\
	structure_model.vala		\
	structure.vala			\
	symbols.vala			\
	symbols_view.vala		\
	tab_info_bar.vala		\
	templates_dialogs.vala		\
	templates.vala			\
	utils.vala			\
	$(vapidir)/config.vapi		\
	$(vapidir)/gedit.vapi		\
	$(vapidir)/gtkspell-2.0.vapi	\
	$(vapidir)/menu_tool_action.vapi

latexila_CPPFLAGS =		\
	-I$(top_srcdir)		\
	-I$(srcdir)/gedit	\
	-I$(srcdir)/resources	\
	$(LATEXILA_CFLAGS)

latexila_LDFLAGS = $(LATEXILA_LIBS)

latexila_LDADD = 			\
	gedit/libgedit.la		\
	resources/libresources.la

INCLUDES = -include config.h
