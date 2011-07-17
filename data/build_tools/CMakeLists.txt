set (bt_dir ${DATA_DIR}/build_tools)
set (tmp_bt_dir "${latexila_BINARY_DIR}/data/build_tools")

install (DIRECTORY "C" DESTINATION ${bt_dir})

set (all_new_bt)

# Foreach language
file (GLOB po_files *.po)
foreach (po_file ${po_files})
	# Get the language name
	get_filename_component (lang ${po_file} NAME_WE)

	# Generate the new XML file
	set (mo_file "${tmp_bt_dir}/${lang}.mo")
	set (new_bt "${tmp_bt_dir}/${lang}/build_tools.xml")
	add_custom_command (
		OUTPUT ${new_bt}
		COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} -o ${mo_file} ${po_file}
		COMMAND mkdir ${tmp_bt_dir}/${lang}
		COMMAND itstool -m ${mo_file} -o ${tmp_bt_dir}/${lang}/ ${latexila_SOURCE_DIR}/data/build_tools/C/build_tools.xml
		DEPENDS ${po_file}
	)

	# Install the directory (which contains only the pages)
	install (DIRECTORY ${tmp_bt_dir}/${lang} DESTINATION ${bt_dir})

	set (all_new_bt ${all_new_bt} ${new_bt})
endforeach ()

add_custom_target (build_tools ALL DEPENDS ${all_new_bt})
