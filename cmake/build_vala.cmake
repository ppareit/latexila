# Build the Vala sources of LaTeXila.
#
# generated_code: This variable will be set with the complete paths of
#                 the C files that will be generated.

function (build_vala generated_code)
	file (GLOB vala_sources "${latexila_SOURCE_DIR}/src/*.vala")
	file (GLOB vapi_files "${latexila_SOURCE_DIR}/vapi/*.vapi")

	vala_precompile (
		OUTPUT
			_generated_code

		SOURCES
			${vala_sources}

		PACKAGES
			gtk+-3.0
			gtksourceview-3.0
			gee-1.0
			posix

		VAPIS
			${vapi_files}

		OUTPUT_DIR
			"${latexila_SOURCE_DIR}/src/C"
	)

	set (${generated_code} ${_generated_code} PARENT_SCOPE)
endfunction ()
