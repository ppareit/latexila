SUBDIRS = build_tools icons images templates

dist_pkgdata_DATA =	\
	completion.xml	\
	latexhelp.html

desktopdir = $(datadir)/applications
desktop_DATA = latexila.desktop
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
dist_appdata_DATA = latexila.appdata.xml

gsettings_SCHEMAS = org.gnome.latexila.gschema.xml
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

EXTRA_DIST =					\
	latexila.desktop.in			\
	org.gnome.latexila.gschema.xml.in.in

CLEANFILES =				\
	latexila.desktop		\
	org.gnome.latexila.gschema.xml

-include $(top_srcdir)/git.mk
