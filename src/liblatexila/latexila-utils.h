/*
 * This file is part of LaTeXila.
 *
 * Copyright (C) 2014 - Sébastien Wilmet <swilmet@gnome.org>
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

#ifndef __LATEXILA_UTILS_H__
#define __LATEXILA_UTILS_H__

#include <glib.h>

G_BEGIN_DECLS

gchar *         latexila_utils_get_shortname                    (const gchar *filename);

gchar *         latexila_utils_replace_home_dir_with_tilde      (const gchar *filename);

void            latexila_utils_register_icons                   (void);

G_END_DECLS

#endif /* __LATEXILA_UTILS_H__ */
