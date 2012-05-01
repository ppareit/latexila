namespace Gdk
{
    namespace MyPixbuf
    {
        [CCode (cname = "gdk_pixbuf_new_from_resource", cheader_filename = "gdk-pixbuf/gdk-pixbuf.h")]
        public static Gdk.Pixbuf from_resource (string resource_path) throws GLib.Error;
    }
}
