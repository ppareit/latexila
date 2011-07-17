set (help_dir "share/gnome/help/latexila")
set (tmp_help_dir "${latexila_BINARY_DIR}/help")

install (DIRECTORY "C" DESTINATION ${help_dir})

# Get list of pages
file (GLOB path_pages "C/*.page")
set (list_pages)
foreach (path_page ${path_pages})
	get_filename_component (page ${path_page} NAME)
	set (list_pages ${list_pages} ${page})
endforeach ()

set (all_new_pages)

# Foreach language
file (GLOB po_files *.po)
foreach (po_file ${po_files})
	# Get the language name
	get_filename_component (lang ${po_file} NAME_WE)

	# Get the paths of the new pages
	set (lang_pages)
	foreach (page ${list_pages})
		set (lang_pages ${lang_pages} "${tmp_help_dir}/${lang}/${page}")
	endforeach ()

	# Generate the new pages from the .po
	set (mo_file "${tmp_help_dir}/${lang}.mo")
	add_custom_command (
		OUTPUT ${lang_pages}
		COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} -o ${mo_file} ${po_file}
		COMMAND mkdir ${tmp_help_dir}/${lang}
		COMMAND itstool -m ${mo_file} -o ${tmp_help_dir}/${lang}/ ${latexila_SOURCE_DIR}/help/C/*.page
		DEPENDS ${po_file}
	)

	# Install the directory (which contains only the pages)
	install (DIRECTORY ${tmp_help_dir}/${lang} DESTINATION ${help_dir})

	set (all_new_pages ${all_new_pages} ${lang_pages})
endforeach ()

add_custom_target (documentation ALL DEPENDS ${all_new_pages})
