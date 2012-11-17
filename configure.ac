#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

# Init Autoconf
AC_PREREQ([2.64])

AC_INIT([LaTeXila],
        [2.6.2],
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
VALA_REQUIRED_VERSION="0.17.3.1"

AC_SUBST([GLIB_REQUIRED_VERSION])
AC_SUBST([GTK_REQUIRED_VERSION])
AC_SUBST([GTKSOURCEVIEW_REQUIRED_VERSION])
AC_SUBST([VALA_REQUIRED_VERSION])

# Some directories

# adl_RECURSIVE_EVAL(VALUE, RESULT)
# =================================
# Interpolate the VALUE in loop until it doesn't change,
# and set the result to $RESULT.
# WARNING: It's easy to get an infinite loop with some unsane input.
# For example ${datadir} becomes ${datarootdir}, and then ${prefix}/share, and
# finally ${prefix} is replaced by the prefix.
AC_DEFUN([adl_RECURSIVE_EVAL],
[_lcl_receval="$1"
$2=`(test "x$prefix" = xNONE && prefix="$ac_default_prefix"
     test "x$exec_prefix" = xNONE && exec_prefix="${prefix}"
     _lcl_receval_old=''
     while test "[$]_lcl_receval_old" != "[$]_lcl_receval"; do
       _lcl_receval_old="[$]_lcl_receval"
       eval _lcl_receval="\"[$]_lcl_receval\""
     done
     echo "[$]_lcl_receval")`])

adl_RECURSIVE_EVAL(["${datadir}/latexila"], [DATA_DIR])
AC_DEFINE_UNQUOTED([DATA_DIR],
                   ["${DATA_DIR}"],
		   [latexila data directory])

adl_RECURSIVE_EVAL(["${datadir}/icons/hicolor"], [ICONS_DIR])
AC_DEFINE_UNQUOTED([ICONS_DIR],
                   ["${ICONS_DIR}"],
		   [icons directory])

# Checks for programs
AC_PROG_CC
AC_PROG_INSTALL
AM_PROG_CC_C_O
AC_PATH_PROG([GLIB_COMPILE_RESOURCES], [glib-compile-resources])

# Checks Valac
# (based on vala.m4 from GNU Automake)
# Modification: only display a warning message if the user doesn't have the
#  minimal valac version instead of display error and stop the compilation.
# A bug has been reported upstream.
AC_DEFUN([AM_PROG_VALAC_CUSTOM],
[AC_PATH_PROG([VALAC], [valac], [])
 AS_IF([test -z "$VALAC"],
   [AC_MSG_WARN([No Vala compiler found.  You will not be able to compile .vala source files.])],
   [AS_IF([test -n "$1"],
      [AC_MSG_CHECKING([$VALAC is at least version $1])
       am__vala_version=`$VALAC --version | sed 's/Vala  *//'`
       AS_VERSION_COMPARE([$1], ["$am__vala_version"],
         [AC_MSG_RESULT([yes])],
         [AC_MSG_RESULT([yes])],
         [AC_MSG_RESULT([no])
          AC_MSG_WARN([Vala $1 not found.  You will not be able to compile .vala source files.])
          unset VALAC])])])
])

AM_PROG_VALAC_CUSTOM([${VALA_REQUIRED_VERSION}])

# Checks for dependencies

if ! pkg-config --atleast-version=${GLIB_REQUIRED_VERSION} glib-2.0; then
	AC_MSG_ERROR([glib-2.0 >= ${GLIB_REQUIRED_VERSION} required.])
fi

if ! pkg-config --atleast-version=${GLIB_REQUIRED_VERSION} gio-2.0; then
	AC_MSG_ERROR([gio-2.0 >= ${GLIB_REQUIRED_VERSION} required.])
fi

if ! pkg-config --atleast-version=${GTK_REQUIRED_VERSION} gtk+-3.0; then
	AC_MSG_ERROR([gtk+-3.0 >= ${GTK_REQUIRED_VERSION} required.])
fi

if ! pkg-config --atleast-version=${GTKSOURCEVIEW_REQUIRED_VERSION} gtksourceview-3.0; then
	AC_MSG_ERROR([gtksourceview-3.0 >= ${GTKSOURCEVIEW_REQUIRED_VERSION} required.])
fi

if ! pkg-config gsettings-desktop-schemas; then
	AC_MSG_ERROR([gsettings-desktop-schemas required.])
fi

if ! pkg-config gee-1.0; then
	AC_MSG_ERROR([gee-1.0 required.])
fi

if ! pkg-config enchant; then
	AC_MSG_ERROR([enchant required.])
fi

dependencies="
	glib-2.0
	gio-2.0
	gtk+-3.0
	gtksourceview-3.0
	gsettings-desktop-schemas
	gee-1.0
	enchant"

CFLAGS="$CFLAGS `pkg-config --cflags ${dependencies}`"
LIBS="$LIBS `pkg-config --libs ${dependencies}`"

# Disable deprecated stuff
CFLAGS="$CFLAGS \
-DGSEAL_ENABLE \
-DG_DISABLE_DEPRECATED \
-DGDK_DISABLE_DEPRECATED \
-DGTK_DISABLE_DEPRECATED \
-DGDK_PIXBUF_DISABLE_DEPRECATED"

# Native Language Support
IT_PROG_INTLTOOL([0.40.0])
AM_GNU_GETTEXT_VERSION([0.17])
AM_GNU_GETTEXT([external])

GETTEXT_PACKAGE=${PACKAGE_TARNAME}
AC_SUBST([GETTEXT_PACKAGE])
AC_DEFINE_UNQUOTED([GETTEXT_PACKAGE],
                   ["${GETTEXT_PACKAGE}"],
                   [The domain to use with gettext])

adl_RECURSIVE_EVAL(["${localedir}"], [LOCALE_DIR])
AC_DEFINE_UNQUOTED([LOCALE_DIR],
                   ["${LOCALE_DIR}"],
		   [locale directory])

# Misc
YELP_HELP_INIT
GLIB_GSETTINGS

# Generate files
AC_CONFIG_FILES([Makefile
		 data/Makefile
		 data/build_tools/Makefile
		 data/latexila.desktop.in
		 data/icons/Makefile
		 data/icons/16x16/Makefile
		 data/icons/22x22/Makefile
		 data/icons/24x24/Makefile
		 data/icons/32x32/Makefile
		 data/icons/48x48/Makefile
		 data/icons/192x192/Makefile
		 data/images/Makefile
		 data/images/app/Makefile
		 data/org.gnome.latexila.gschema.xml.in
		 data/templates/Makefile
		 help/Makefile
		 man/Makefile
		 po/Makefile.in
                 src/Makefile
		 src/gedit/Makefile
		 src/gtkspell/Makefile
		 src/ui/Makefile
                 README])

AC_OUTPUT

if test -z "$VALAC"
then
	vala_compiler="valac >= ${VALA_REQUIRED_VERSION} not found."
else
	vala_compiler=${VALAC}
fi

# Print a summary of the configuration
echo "

Configuration:

    ${PACKAGE_NAME} version ${PACKAGE_VERSION}

    Prefix: ${prefix}
    Vala Compiler: ${vala_compiler}
    C Compiler: ${CC} ${CFLAGS} ${CPPFLAGS}
"
