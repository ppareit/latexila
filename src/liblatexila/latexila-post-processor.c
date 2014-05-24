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

/**
 * SECTION:post-processor
 * @title: LatexilaPostProcessor
 * @short_description: post-processor base class
 *
 * When running a build tool, a post-processor is used to filter the output to
 * display only the relevant messages. It can be the output of a build job
 * command, or a log file, etc.
 */

#include "latexila-post-processor.h"
#include "latexila-build-view.h"

#define BUFFER_SIZE 4096

struct _LatexilaPostProcessorPrivate
{
  GTask *task;
  GInputStream *stream;

  /* "+1" so we can nul-terminate the buffer. */
  gchar buffer[BUFFER_SIZE + 1];

  /* The @buffer is split by lines. But since the stream is read with a fixed
   * size (BUFFER_SIZE), the last string returned by g_strsplit() is stored in
   * @line_buffer. When the next block is read, the first line returned is
   * appended to @line_buffer to have the whole line.
   */
  GString *line_buffer;

  guint has_details : 1;
  guint show_details : 1;
};

enum
{
  PROP_0,
  PROP_HAS_DETAILS,
  PROP_SHOW_DETAILS
};

G_DEFINE_TYPE_WITH_PRIVATE (LatexilaPostProcessor, latexila_post_processor, G_TYPE_OBJECT)

/* Prototypes */
static void read_stream (LatexilaPostProcessor *pp);

/**
 * latexila_post_processor_get_type_from_name:
 * @name: the name of the post-processor.
 * @type: (out): the output post-processor type.
 *
 * Returns: %TRUE on success, %FALSE otherwise.
 */
gboolean
latexila_post_processor_get_type_from_name (const gchar               *name,
                                            LatexilaPostProcessorType *type)
{
  g_assert (type != NULL);

  if (g_str_equal (name, "latexmk"))
    {
      *type = LATEXILA_POST_PROCESSOR_TYPE_LATEXMK;
      return TRUE;
    }

  if (g_str_equal (name, "latex"))
    {
      *type = LATEXILA_POST_PROCESSOR_TYPE_LATEX;
      return TRUE;
    }

  if (g_str_equal (name, "all-output"))
    {
      *type = LATEXILA_POST_PROCESSOR_TYPE_ALL_OUTPUT;
      return TRUE;
    }

  if (g_str_equal (name, "no-output"))
    {
      *type = LATEXILA_POST_PROCESSOR_TYPE_NO_OUTPUT;
      return TRUE;
    }

  return FALSE;
}

/**
 * latexila_post_processor_get_name_from_type:
 * @type: the post-processor type.
 *
 * Returns: the post-processor name.
 */
const gchar *
latexila_post_processor_get_name_from_type (LatexilaPostProcessorType type)
{
  switch (type)
    {
    case LATEXILA_POST_PROCESSOR_TYPE_LATEXMK:
      return "latexmk";

    case LATEXILA_POST_PROCESSOR_TYPE_LATEX:
      return "latex";

    case LATEXILA_POST_PROCESSOR_TYPE_ALL_OUTPUT:
      return "all-output";

    case LATEXILA_POST_PROCESSOR_TYPE_NO_OUTPUT:
      return "no-output";

    default:
      g_return_val_if_reached (NULL);
    }
}

static gboolean
free_build_msg (GNode    *node,
                gpointer  user_data)
{
  latexila_build_msg_free (node->data);
  return FALSE;
}

/**
 * latexila_build_messages_free:
 * @build_messages: a tree of #LatexilaBuildMsg's.
 *
 * Frees a tree of #LatexilaBuildMsg's.
 */
void
latexila_build_messages_free (GNode *build_messages)
{
  if (build_messages != NULL)
    {
      g_node_traverse (build_messages,
                       G_POST_ORDER,
                       G_TRAVERSE_ALL,
                       -1,
                       free_build_msg,
                       NULL);

      g_node_destroy (build_messages);
    }
}

static void
latexila_post_processor_get_property (GObject    *object,
                                      guint       prop_id,
                                      GValue     *value,
                                      GParamSpec *pspec)
{
  LatexilaPostProcessor *pp = LATEXILA_POST_PROCESSOR (object);

  switch (prop_id)
    {
    case PROP_HAS_DETAILS:
      g_value_set_boolean (value, pp->priv->has_details);
      break;

    case PROP_SHOW_DETAILS:
      g_value_set_boolean (value, pp->priv->show_details);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
    }
}

static void
latexila_post_processor_set_property (GObject      *object,
                                      guint         prop_id,
                                      const GValue *value,
                                      GParamSpec   *pspec)
{
  LatexilaPostProcessor *pp = LATEXILA_POST_PROCESSOR (object);

  switch (prop_id)
    {
    case PROP_HAS_DETAILS:
      pp->priv->has_details = g_value_get_boolean (value);
      break;

    case PROP_SHOW_DETAILS:
      pp->priv->show_details = g_value_get_boolean (value);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
    }
}

static void
latexila_post_processor_dispose (GObject *object)
{
  LatexilaPostProcessor *pp = LATEXILA_POST_PROCESSOR (object);

  g_clear_object (&pp->priv->task);
  g_clear_object (&pp->priv->stream);

  G_OBJECT_CLASS (latexila_post_processor_parent_class)->dispose (object);
}

static void
latexila_post_processor_finalize (GObject *object)
{
  LatexilaPostProcessor *pp = LATEXILA_POST_PROCESSOR (object);

  if (pp->priv->line_buffer != NULL)
    {
      g_string_free (pp->priv->line_buffer, TRUE);
      pp->priv->line_buffer = NULL;
    }

  G_OBJECT_CLASS (latexila_post_processor_parent_class)->finalize (object);
}

static void
latexila_post_processor_process_lines_default (LatexilaPostProcessor  *pp,
                                               gchar                 **lines)
{
  g_strfreev (lines);
}

static const GNode *
latexila_post_processor_get_messages_default (LatexilaPostProcessor *pp)
{
  return NULL;
}

static void
latexila_post_processor_class_init (LatexilaPostProcessorClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->get_property = latexila_post_processor_get_property;
  object_class->set_property = latexila_post_processor_set_property;
  object_class->dispose = latexila_post_processor_dispose;
  object_class->finalize = latexila_post_processor_finalize;

  klass->process_lines = latexila_post_processor_process_lines_default;
  klass->get_messages = latexila_post_processor_get_messages_default;

  g_object_class_install_property (object_class,
                                   PROP_HAS_DETAILS,
                                   g_param_spec_boolean ("has-details",
                                                         "Has details",
                                                         "",
                                                         FALSE,
                                                         G_PARAM_READWRITE |
                                                         G_PARAM_CONSTRUCT |
                                                         G_PARAM_STATIC_STRINGS));

  g_object_class_install_property (object_class,
                                   PROP_SHOW_DETAILS,
                                   g_param_spec_boolean ("show-details",
                                                         "Show details",
                                                         "",
                                                         FALSE,
                                                         G_PARAM_READWRITE |
                                                         G_PARAM_CONSTRUCT |
                                                         G_PARAM_STATIC_STRINGS));
}

static void
latexila_post_processor_init (LatexilaPostProcessor *pp)
{
  pp->priv = latexila_post_processor_get_instance_private (pp);
}

static void
read_stream_cb (GInputStream          *stream,
                GAsyncResult          *result,
                LatexilaPostProcessor *pp)
{
  gssize bytes_read;
  GCancellable *cancellable;
  gchar **lines;
  GError *error = NULL;

  bytes_read = g_input_stream_read_finish (stream, result, &error);

  cancellable = g_task_get_cancellable (pp->priv->task);
  if (g_cancellable_is_cancelled (cancellable))
    {
      if (error != NULL)
        {
          g_error_free (error);
        }

      g_task_return_boolean (pp->priv->task, FALSE);
      return;
    }

  if (error != NULL)
    {
      g_warning ("Error while reading the post-processor stream: %s", error->message);
      g_error_free (error);
      g_task_return_boolean (pp->priv->task, FALSE);
      return;
    }

  /* End of stream reached, process line_buffer. */
  if (bytes_read == 0)
    {
      /* Generally a single \n is present at the end of the stream, so an empty
       * line is present in line_buffer. But we don't want to display it in the
       * build view.
       */
      if (pp->priv->line_buffer != NULL &&
          pp->priv->line_buffer->str != NULL &&
          pp->priv->line_buffer->str[0] != '\0')
        {
          lines = g_new (gchar *, 2);
          lines[0] = g_string_free (pp->priv->line_buffer, FALSE);
          lines[1] = NULL;

          pp->priv->line_buffer = NULL;

          LATEXILA_POST_PROCESSOR_GET_CLASS (pp)->process_lines (pp, lines);
        }

      /* finished! */
      g_task_return_boolean (pp->priv->task, TRUE);
      return;
    }

  pp->priv->buffer[bytes_read] = '\0';

  lines = g_strsplit (pp->priv->buffer, "\n", 0);
  g_assert (lines != NULL);
  g_assert (lines[0] != NULL);

  if (pp->priv->line_buffer != NULL)
    {
      /* Merge line_buffer and the first line */
      g_string_append (pp->priv->line_buffer, lines[0]);
    }

  /* If a second line exists, we can call process_lines().
   * The first line must be replaced by the contents of line_buffer.
   * And the last line must go to line_buffer.
   */
  if (lines[1] != NULL)
    {
      gint last_line;

      if (pp->priv->line_buffer != NULL)
        {
          g_free (lines[0]);
          lines[0] = g_string_free (pp->priv->line_buffer, FALSE);
          pp->priv->line_buffer = NULL;
        }

      for (last_line = 1; lines[last_line+1] != NULL; last_line++);

      pp->priv->line_buffer = g_string_new (lines[last_line]);
      g_free (lines[last_line]);
      lines[last_line] = NULL;

      LATEXILA_POST_PROCESSOR_GET_CLASS (pp)->process_lines (pp, lines);
    }
  else
    {
      /* If not already done above, put the first line to line_buffer. */
      if (pp->priv->line_buffer == NULL)
        {
          pp->priv->line_buffer = g_string_new (lines[0]);
        }

      g_strfreev (lines);
    }

  /* Unfortunately for the computer, it is not finished. */
  read_stream (pp);
}

static void
read_stream (LatexilaPostProcessor *pp)
{
  g_input_stream_read_async (pp->priv->stream,
                             &pp->priv->buffer,
                             BUFFER_SIZE,
                             G_PRIORITY_DEFAULT,
                             g_task_get_cancellable (pp->priv->task),
                             (GAsyncReadyCallback) read_stream_cb,
                             pp);
}

/**
 * latexila_post_processor_process_async:
 * @pp: a post-processor.
 * @stream: the input stream to process.
 * @cancellable: a #GCancellable.
 * @callback: the callback to call when the operation is finished.
 * @user_data: the data to pass to the callback.
 *
 * Asynchronously process an input stream. The input stream can for example come
 * from the output of a command launched with #GSubprocess, or it can be the
 * input stream of a file (e.g. the LaTeX log file), etc.
 *
 * @callback will be called when the operation is finished. You can then call
 * latexila_post_processor_process_finish().
 */
void
latexila_post_processor_process_async (LatexilaPostProcessor *pp,
                                       GInputStream          *stream,
                                       GCancellable          *cancellable,
                                       GAsyncReadyCallback    callback,
                                       gpointer               user_data)
{
  g_return_if_fail (LATEXILA_IS_POST_PROCESSOR (pp));
  g_return_if_fail (G_IS_INPUT_STREAM (stream));
  g_return_if_fail (G_IS_CANCELLABLE (cancellable));
  g_return_if_fail (pp->priv->task == NULL);

  pp->priv->task = g_task_new (pp, cancellable, callback, user_data);
  pp->priv->stream = g_object_ref (stream);

  if (pp->priv->line_buffer != NULL)
    {
      g_string_free (pp->priv->line_buffer, TRUE);
      pp->priv->line_buffer = NULL;
    }

  read_stream (pp);
}

/**
 * latexila_post_processor_process_finish:
 * @pp: a post-processor.
 * @result: a #GAsyncResult.
 *
 * Finishes an operation started with latexila_post_processor_process_async().
 * After calling this function, you can get the filtered messages with
 * latexila_post_processor_get_messages().
 */
void
latexila_post_processor_process_finish (LatexilaPostProcessor *pp,
                                        GAsyncResult          *result)
{
  g_return_if_fail (g_task_is_valid (result, pp));

  g_task_propagate_boolean (G_TASK (result), NULL);

  g_clear_object (&pp->priv->task);
  g_clear_object (&pp->priv->stream);

  if (pp->priv->line_buffer != NULL)
    {
      g_string_free (pp->priv->line_buffer, TRUE);
      pp->priv->line_buffer = NULL;
    }
}

/**
 * latexila_post_processor_get_messages:
 * @pp: a post-processor.
 *
 * Gets the filtered messages. Call this function only after calling
 * latexila_post_processor_process_finish().
 *
 * Another solution would have been to pass the #LatexilaBuildView to the
 * post-processor, so the filtered messages can directly be outputed to the
 * build view as they come. But some post-processors don't know what to output
 * directly. The latexmk post-processor can have a simplified output with only
 * the LaTeX messages, in which case the detailed messages are also available,
 * but this can be known only when all the stream has been processed.
 *
 * Obviously if the build view is passed to the post-processor, the latexmk
 * post-processor can output its messages only at the end. But another reason to
 * not pass the build view is for the unit tests. It is easier for the unit
 * tests to check the returned #GNode than analyzing a #GtkTreeView. Of course
 * it would be possible to keep also the messages in a #GNode and have this
 * function only for the unit tests, but it takes more memory (unless a custom
 * #GtkTreeModel is implemented), or another function is needed to configure
 * whether a #GNode is kept in memory or not... It becomes a little too
 * complicated, and doesn't really worth the effort as most users use latexmk.
 *
 * The current solution is "good enough".
 *
 * Returns: the tree of filtered messages.
 */
const GNode *
latexila_post_processor_get_messages (LatexilaPostProcessor *pp)
{
  g_return_val_if_fail (LATEXILA_IS_POST_PROCESSOR (pp), NULL);

  return LATEXILA_POST_PROCESSOR_GET_CLASS (pp)->get_messages (pp);
}
