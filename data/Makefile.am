SUBDIRS = build_tools icons images templates

dist_pkgdata_DATA =	\
	completion.xml	\
	latexhelp.html

desktopdir = $(datadir)/applications
desktop_DATA = latexila.desktop
@INTLTOOL_DESKTOP_RULE@

gsettings_SCHEMAS = org.gnome.latexila.gschema.xml
@GSETTINGS_RULES@

EXTRA_DIST =				\
	latexila.desktop.in		\
	org.gnome.latexila.gschema.xml

CLEANFILES = latexila.desktop

-include $(top_srcdir)/git.mk
