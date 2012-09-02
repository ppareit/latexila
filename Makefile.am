ACLOCAL_AMFLAGS = -I m4

SUBDIRS = data man po src

EXTRA_DIST =			\
	HACKING			\
	latexila.doap		\
	intltool-extract.in	\
	intltool-merge.in	\
	intltool-update.in

DISTCLEANFILES =		\
	intltool-extract	\
	intltool-merge		\
	intltool-update

MAINTAINERCLEANFILES =			\
	$(srcdir)/aclocal.m4		\
	$(srcdir)/autoscan.log		\
	$(srcdir)/compile		\
	$(srcdir)/config.guess		\
	$(srcdir)/config.h.in		\
	$(srcdir)/config.sub		\
	$(srcdir)/configure.scan	\
	$(srcdir)/depcomp		\
	$(srcdir)/install-sh		\
	$(srcdir)/ltmain.sh		\
	$(srcdir)/missing		\
	$(srcdir)/mkinstalldirs		\
	`find "$(srcdir)" -type f -name Makefile.in -print`

-include $(top_srcdir)/git.mk
