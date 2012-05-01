cmake_minimum_required (VERSION 2.6.4)

# Some variables
set (APP_NAME "LaTeXila")
set (APP_VERSION "2.5.1")
set (SCHEMA_DIR "${CMAKE_INSTALL_PREFIX}/share")
set (ICONS_DIR "${CMAKE_INSTALL_PREFIX}/share/icons/hicolor")

message (STATUS "*** Building ${APP_NAME} ${APP_VERSION} ***")

project ("latexila" C)

# Include custom functions
list (APPEND CMAKE_MODULE_PATH "${latexila_SOURCE_DIR}/cmake")
include ("${latexila_SOURCE_DIR}/cmake/itstool.cmake")
include ("${latexila_SOURCE_DIR}/cmake/gresource.cmake")
include ("${latexila_SOURCE_DIR}/cmake/find_vala.cmake")
include ("${latexila_SOURCE_DIR}/cmake/use_vala.cmake")
include ("${latexila_SOURCE_DIR}/cmake/build_vala.cmake")

# Build options
set (DATA_DIR "${CMAKE_INSTALL_PREFIX}/share/latexila"
	CACHE PATH "The directory where the data is")
set (BUILD_VALA ON CACHE BOOL "Generate the C code from Vala files")
set (WITH_GNOME OFF CACHE BOOL
	"Use gsettings-desktop-schemas for a better integration with GNOME")
set (COMPILE_SCHEMA ON CACHE BOOL "Compile the GSettings schema")
set (VALAC "" CACHE FILEPATH "The valac executable to use")

# Native Language Support
set (GETTEXT_PACKAGE "latexila")
set (LOCALE_DIR "${CMAKE_INSTALL_PREFIX}/share/locale")
find_package (Gettext REQUIRED)
find_package (Itstool REQUIRED)

# Vala
if (BUILD_VALA)
	set (_vala_main_version "0.16")
	set (_vala_min_version "0.16.0")

	if (VALAC)
		message (STATUS "Use custom valac: ${VALAC}")
		set (VALA_EXECUTABLE ${VALAC})
	else ()
		find_vala (${_vala_main_version})

		if ((NOT VALA_FOUND) OR
		    ("${VALA_VERSION}" VERSION_LESS "${_vala_min_version}"))
			message (FATAL_ERROR
				"Vala ${_vala_main_version}.x >= ${_vala_min_version} required")
		endif ()
	endif ()
endif ()

# Dependencies
find_package (PkgConfig)
pkg_check_modules (GTK REQUIRED "gtk+-3.0 >= 3.4")
pkg_check_modules (GTKSOURCEVIEW REQUIRED "gtksourceview-3.0 >= 3.4.1")
pkg_check_modules (GEE REQUIRED "gee-1.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.32")
pkg_check_modules (GTKSPELL REQUIRED "gtkspell-3.0")

add_definitions (
	${GTK_CFLAGS}
	${GTKSOURCEVIEW_CFLAGS}
	${GEE_CFLAGS}
	${GIO_CFLAGS}
	${GTKSPELL_CFLAGS}
)

link_libraries (
	${GTK_LIBRARIES}
	${GTKSOURCEVIEW_LIBRARIES}
	${GEE_LIBRARIES}
	${GIO_LIBRARIES}
	${GTKSPELL_LIBRARIES}
)

if (WITH_GNOME)
	pkg_check_modules (DESKTOP-SCHEMAS REQUIRED "gsettings-desktop-schemas")
	set (DESKTOP_SCHEMAS "1")
else ()
	set (DESKTOP_SCHEMAS "0")
endif ()

# Execute CMake in sub-directories
add_subdirectory (data)
add_subdirectory (help)
add_subdirectory (man)
add_subdirectory (po)
add_subdirectory (src/ui)

# Config file
set (config_file "${latexila_BINARY_DIR}/src/config.h")

configure_file (
	${latexila_SOURCE_DIR}/src/config.h.in
	${config_file}
)

add_definitions (-include config.h)

# Resources
gresource (
	"${latexila_SOURCE_DIR}/data/images/stock-icons" # resource dir
	"stock-icons.gresource.xml" # resource file
	"${latexila_BINARY_DIR}/src" # output dir
	generated_resource
)

set (generated_resources ${generated_resource})

# Build the source code
include_directories (src/C src/gedit ${latexila_BINARY_DIR}/src)

file (GLOB gedit_source_code "${latexila_SOURCE_DIR}/src/gedit/*")

if (BUILD_VALA)
	build_vala (generated_code)
else ()
	file (GLOB generated_code "${latexila_SOURCE_DIR}/src/C/*.c")
endif ()

add_executable (
	"latexila"
	${generated_code}
	${generated_resources}
	${config_file}
	${gedit_source_code}
)

install (TARGETS "latexila" DESTINATION "bin")
