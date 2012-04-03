file (GLOB vala_sources RELATIVE "${latexila_SOURCE_DIR}/src/" "*.vala")
file (GLOB vapi_files "${latexila_SOURCE_DIR}/vapi/*.vapi")
file (GLOB gedit_files "${latexila_SOURCE_DIR}/src/gedit/*")

vala_precompile (
	VALA_C
		${vala_sources}
	PACKAGES
		gtk+-3.0
		gtksourceview-3.0
		gee-1.0
		posix

	CUSTOM_VAPIS
		${vapi_files}
	DIRECTORY
		"C"
)

add_executable (latexila ${VALA_C} ${gedit_files})
install (TARGETS latexila DESTINATION "bin")
