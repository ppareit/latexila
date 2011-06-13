/* custom_statusbar.c generated by valac 0.12.1, the Vala compiler
 * generated from custom_statusbar.vala, do not modify */

/*
 * This file is part of LaTeXila.
 *
 * Copyright © 2010 Sébastien Wilmet
 *
 * LaTeXila is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * LaTeXila is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with LaTeXila.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>
#include <glib/gi18n-lib.h>
#include <stdlib.h>
#include <string.h>


#define TYPE_CUSTOM_STATUSBAR (custom_statusbar_get_type ())
#define CUSTOM_STATUSBAR(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_CUSTOM_STATUSBAR, CustomStatusbar))
#define CUSTOM_STATUSBAR_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_CUSTOM_STATUSBAR, CustomStatusbarClass))
#define IS_CUSTOM_STATUSBAR(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_CUSTOM_STATUSBAR))
#define IS_CUSTOM_STATUSBAR_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_CUSTOM_STATUSBAR))
#define CUSTOM_STATUSBAR_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_CUSTOM_STATUSBAR, CustomStatusbarClass))

typedef struct _CustomStatusbar CustomStatusbar;
typedef struct _CustomStatusbarClass CustomStatusbarClass;
typedef struct _CustomStatusbarPrivate CustomStatusbarPrivate;
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))
#define _g_free0(var) (var = (g_free (var), NULL))

struct _CustomStatusbar {
	GtkStatusbar parent_instance;
	CustomStatusbarPrivate * priv;
};

struct _CustomStatusbarClass {
	GtkStatusbarClass parent_class;
};

struct _CustomStatusbarPrivate {
	GtkStatusbar* cursor_position;
};


static gpointer custom_statusbar_parent_class = NULL;

GType custom_statusbar_get_type (void) G_GNUC_CONST;
#define CUSTOM_STATUSBAR_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), TYPE_CUSTOM_STATUSBAR, CustomStatusbarPrivate))
enum  {
	CUSTOM_STATUSBAR_DUMMY_PROPERTY
};
CustomStatusbar* custom_statusbar_new (void);
CustomStatusbar* custom_statusbar_construct (GType object_type);
void custom_statusbar_set_cursor_position (CustomStatusbar* self, gint line, gint col);
static void custom_statusbar_finalize (GObject* obj);


CustomStatusbar* custom_statusbar_construct (GType object_type) {
	CustomStatusbar * self = NULL;
	GtkStatusbar* _tmp0_ = NULL;
	self = (CustomStatusbar*) g_object_new (object_type, NULL);
	_tmp0_ = (GtkStatusbar*) gtk_statusbar_new ();
	_g_object_unref0 (self->priv->cursor_position);
	self->priv->cursor_position = g_object_ref_sink (_tmp0_);
	gtk_statusbar_set_has_resize_grip (self->priv->cursor_position, FALSE);
	gtk_widget_set_size_request ((GtkWidget*) self->priv->cursor_position, 150, -1);
	gtk_box_pack_end ((GtkBox*) self, (GtkWidget*) self->priv->cursor_position, FALSE, TRUE, (guint) 0);
	return self;
}


CustomStatusbar* custom_statusbar_new (void) {
	return custom_statusbar_construct (TYPE_CUSTOM_STATUSBAR);
}


void custom_statusbar_set_cursor_position (CustomStatusbar* self, gint line, gint col) {
	gboolean _tmp0_ = FALSE;
	const gchar* _tmp1_ = NULL;
	gchar* _tmp2_ = NULL;
	gchar* _tmp3_;
	g_return_if_fail (self != NULL);
	gtk_statusbar_pop (self->priv->cursor_position, (guint) 0);
	if (line == (-1)) {
		_tmp0_ = col == (-1);
	} else {
		_tmp0_ = FALSE;
	}
	if (_tmp0_) {
		return;
	}
	_tmp1_ = _ ("Ln %d, Col %d");
	_tmp2_ = g_strdup_printf (_tmp1_, line, col);
	_tmp3_ = _tmp2_;
	gtk_statusbar_push (self->priv->cursor_position, (guint) 0, _tmp3_);
	_g_free0 (_tmp3_);
}


static void custom_statusbar_class_init (CustomStatusbarClass * klass) {
	custom_statusbar_parent_class = g_type_class_peek_parent (klass);
	g_type_class_add_private (klass, sizeof (CustomStatusbarPrivate));
	G_OBJECT_CLASS (klass)->finalize = custom_statusbar_finalize;
}


static void custom_statusbar_instance_init (CustomStatusbar * self) {
	self->priv = CUSTOM_STATUSBAR_GET_PRIVATE (self);
}


static void custom_statusbar_finalize (GObject* obj) {
	CustomStatusbar * self;
	self = CUSTOM_STATUSBAR (obj);
	_g_object_unref0 (self->priv->cursor_position);
	G_OBJECT_CLASS (custom_statusbar_parent_class)->finalize (obj);
}


GType custom_statusbar_get_type (void) {
	static volatile gsize custom_statusbar_type_id__volatile = 0;
	if (g_once_init_enter (&custom_statusbar_type_id__volatile)) {
		static const GTypeInfo g_define_type_info = { sizeof (CustomStatusbarClass), (GBaseInitFunc) NULL, (GBaseFinalizeFunc) NULL, (GClassInitFunc) custom_statusbar_class_init, (GClassFinalizeFunc) NULL, NULL, sizeof (CustomStatusbar), 0, (GInstanceInitFunc) custom_statusbar_instance_init, NULL };
		GType custom_statusbar_type_id;
		custom_statusbar_type_id = g_type_register_static (GTK_TYPE_STATUSBAR, "CustomStatusbar", &g_define_type_info, 0);
		g_once_init_leave (&custom_statusbar_type_id__volatile, custom_statusbar_type_id);
	}
	return custom_statusbar_type_id__volatile;
}



