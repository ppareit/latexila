install (FILES "org.gnome.latexila.gschema.xml"
	DESTINATION "share/glib-2.0/schemas")

if (COMPILE_SCHEMA)
	install (SCRIPT "compile-schemas.cmake")
endif ()

install (FILES "latexhelp.html" DESTINATION ${DATA_DIR})
install (FILES "completion.xml" DESTINATION ${DATA_DIR})
install (FILES "latexila.desktop" DESTINATION share/applications)

add_subdirectory ("build_tools")
add_subdirectory ("templates")
add_subdirectory ("images/app")
