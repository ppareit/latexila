namespace GLib
{
    namespace MyDirUtils
    {
        [CCode (cname = "g_dir_make_tmp", cheader_filename = "glib.h,glib/gstdio.h")]
        public static string make_tmp (string tmpl) throws FileError;
    }
}
