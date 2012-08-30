noinst_LTLIBRARIES = libresources.la

libresources_la_CPPFLAGS = $(LATEXILA_CFLAGS)
libresources_la_LDFLAGS = $(LATEXILA_LIBS)

EXTRA_DIST =					\
	stock-icons.gresource.xml		\
	symbols-arrows.gresource.xml		\
	symbols-delimiters.gresource.xml	\
	symbols-greek.gresource.xml		\
	symbols-misc-math.gresource.xml		\
	symbols-misc-text.gresource.xml		\
	symbols-operators.gresource.xml		\
	symbols-relations.gresource.xml

# Stock icons

res1 = stock-icons-resources.c
xml1 = $(srcdir)/stock-icons.gresource.xml
dir1 = $(top_srcdir)/data/images/stock-icons

nodist_libresources_la_SOURCES = $(res1)
CLEANFILES = $(res1)
libresources.$(OBJEXT): $(res1)

$(res1): $(xml1) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir1) --generate-dependencies $(xml1))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir1) --generate-source $(xml1)

# Arrows symbols

res2 = symbols-arrows-resources.c
xml2 = $(srcdir)/symbols-arrows.gresource.xml
dir2 = $(top_srcdir)/data/images/arrows

nodist_libresources_la_SOURCES += $(res2)
CLEANFILES += $(res2)
libresources.$(OBJEXT): $(res2)

$(res2): $(xml2) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir2) --generate-dependencies $(xml2))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir2) --generate-source $(xml2)

# Delimiters symbols

res3 = symbols-delimiters-resources.c
xml3 = $(srcdir)/symbols-delimiters.gresource.xml
dir3 = $(top_srcdir)/data/images/delimiters

nodist_libresources_la_SOURCES += $(res3)
CLEANFILES += $(res3)
libresources.$(OBJEXT): $(res3)

$(res3): $(xml3) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir3) --generate-dependencies $(xml3))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir3) --generate-source $(xml3)

# Greek symbols

res4 = symbols-greek-resources.c
xml4 = $(srcdir)/symbols-greek.gresource.xml
dir4 = $(top_srcdir)/data/images/greek

nodist_libresources_la_SOURCES += $(res4)
CLEANFILES += $(res4)
libresources.$(OBJEXT): $(res4)

$(res4): $(xml4) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir4) --generate-dependencies $(xml4))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir4) --generate-source $(xml4)

# Misc math symbols

res5 = symbols-misc-math-resources.c
xml5 = $(srcdir)/symbols-misc-math.gresource.xml
dir5 = $(top_srcdir)/data/images/misc-math

nodist_libresources_la_SOURCES += $(res5)
CLEANFILES += $(res5)
libresources.$(OBJEXT): $(res5)

$(res5): $(xml5) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir5) --generate-dependencies $(xml5))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir5) --generate-source $(xml5)

# Misc text symbols

res6 = symbols-misc-text-resources.c
xml6 = $(srcdir)/symbols-misc-text.gresource.xml
dir6 = $(top_srcdir)/data/images/misc-text

nodist_libresources_la_SOURCES += $(res6)
CLEANFILES += $(res6)
libresources.$(OBJEXT): $(res6)

$(res6): $(xml6) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir6) --generate-dependencies $(xml6))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir6) --generate-source $(xml6)

# Operators symbols

res7 = symbols-operators-resources.c
xml7 = $(srcdir)/symbols-operators.gresource.xml
dir7 = $(top_srcdir)/data/images/operators

nodist_libresources_la_SOURCES += $(res7)
CLEANFILES += $(res7)
libresources.$(OBJEXT): $(res7)

$(res7): $(xml7) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir7) --generate-dependencies $(xml7))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir7) --generate-source $(xml7)

# Relations symbols

res8 = symbols-relations-resources.c
xml8 = $(srcdir)/symbols-relations.gresource.xml
dir8 = $(top_srcdir)/data/images/relations

nodist_libresources_la_SOURCES += $(res8)
CLEANFILES += $(res8)
libresources.$(OBJEXT): $(res8)

$(res8): $(xml8) $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(dir8) --generate-dependencies $(xml8))
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(dir8) --generate-source $(xml8)
