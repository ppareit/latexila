[CCode (cheader_filename = "gtkspell/gtkspell.h")]
public errordomain GtkspellError
{
    BACKEND
}

[Compact]
[CCode (cprefix = "gtkspell_", cheader_filename = "gtkspell/gtkspell.h", free_function = "")]
public class GtkSpell
{
    public GtkSpell.attach (Gtk.TextView view, string? lang) throws GtkspellError;
    public static GtkSpell? get_from_text_view (Gtk.TextView view);
    public void detach ();
    public bool set_language (string lang) throws GtkspellError;
    public void recheck_all ();
}
