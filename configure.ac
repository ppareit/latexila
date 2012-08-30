#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

# Init Autoconf
AC_PREREQ([2.64])

AC_INIT([LaTeXila],
        [2.5.3],
        [https://bugzilla.gnome.org/enter_bug.cgi?product=latexila],
	[latexila],
	[http://projects.gnome.org/latexila])

AC_CONFIG_SRCDIR([src/latexila.vala])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])

# Init Automake
AM_INIT_AUTOMAKE([1.11 foreign tar-ustar no-dist-gzip dist-xz -Wno-portability])
AM_MAINTAINER_MODE([enable])
AM_SILENT_RULES([yes])

# Init Libtool
LT_PREREQ([2.2])
LT_INIT

# Required dependencies versions
GLIB_REQUIRED_VERSION="2.32"
GTK_REQUIRED_VERSION="3.4.3"
GTKSOURCEVIEW_REQUIRED_VERSION="3.4.1"
GTKSPELL_REQUIRED_VERSION="3.0"
VALA_REQUIRED_VERSION="0.17.3.1"

AC_SUBST([GLIB_REQUIRED_VERSION])
AC_SUBST([GTK_REQUIRED_VERSION])
AC_SUBST([GTKSOURCEVIEW_REQUIRED_VERSION])
AC_SUBST([GTKSPELL_REQUIRED_VERSION])
AC_SUBST([VALA_REQUIRED_VERSION])

# Some directories
AC_DEFINE_UNQUOTED([DATA_DIR],
                   ["${datadir}/latexila"],
		   [latexila data directory])

AC_DEFINE_UNQUOTED([ICONS_DIR],
                   ["${datadir}/icons/hicolor"],
		   [icons directory])

# Checks for programs
AC_PROG_CC
AC_PROG_INSTALL
AM_PROG_CC_C_O
AM_PROG_VALAC([${VALA_REQUIRED_VERSION}])
AC_PATH_PROG([GLIB_COMPILE_RESOURCES], [glib-compile-resources])

# Checks for dependencies
PKG_CHECK_MODULES([LATEXILA], [
	glib-2.0 >= ${GLIB_REQUIRED_VERSION}
	gio-2.0 >= ${GLIB_REQUIRED_VERSION}
	gtk+-3.0 >= ${GTK_REQUIRED_VERSION}
	gtksourceview-3.0 >= ${GTKSOURCEVIEW_REQUIRED_VERSION}
	gsettings-desktop-schemas
	gee-1.0
	gtkspell-3.0
])

AC_SUBST([LATEXILA_CFLAGS])
AC_SUBST([LATEXILA_LIBS])

# Native Language Support
AC_DEFINE_UNQUOTED([LOCALE_DIR],
                   ["${localedir}"],
		   [locale directory])

AC_DEFINE([GETTEXT_PACKAGE],
          ["latexila"],
	  [gettext package])

# GSettings
GLIB_GSETTINGS

AC_DEFINE_UNQUOTED([SCHEMA_DIR],
                   ["${datadir}"],
		   [GSettings schemas directory])

AC_DEFINE([DESKTOP_SCHEMAS],
          [1],
	  [Use desktop GSettings schemas])

# Generate files
AC_CONFIG_FILES([Makefile
                 src/Makefile
		 src/resources/Makefile
                 README])

AC_OUTPUT

# Print a summary of the configuration
echo "

Configuration:

    ${PACKAGE_NAME} version ${PACKAGE_VERSION}

    Prefix: ${prefix}
    Compiler: ${CC} ${CFLAGS} ${CPPFLAGS}
"
