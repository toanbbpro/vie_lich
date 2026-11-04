#include "my_application.h"

#include <dlfcn.h>
#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "desktop_widget.h"
#include "flutter/generated_plugin_registrant.h"

// Workaround for Skia SkFontMgr_fontconfig bug in libflutter_linux_gtk.so:
// When a system font (e.g., WOFF fonts in /usr/share/fonts/woff/opendyslexic
// on Ubuntu/Zorin OS) has no FC_FAMILY property in Fontconfig,
// FcPatternGetString(pattern, "family", id, &s) returns FcResultNoMatch (1)
// instead of FcResultNoId (3). Skia's loop only breaks on FcResultNoId (3),
// causing it to loop id from 0 to 2^32-1 (4.29 billion times) per font and
// freeze the main thread at 100% CPU before the window can appear.
extern "C" __attribute__((visibility("default"))) int FcPatternGetString(
    void* p,
    const char* object,
    int n,
    unsigned char** s) {
  typedef int (*FcPatternGetStringFn)(void*, const char*, int, unsigned char**);
  static FcPatternGetStringFn real_fn = nullptr;
  if (!real_fn) {
    real_fn = reinterpret_cast<FcPatternGetStringFn>(
        dlsym(RTLD_NEXT, "FcPatternGetString"));
  }
  int res = real_fn(p, object, n, s);
  if (res == 1 /* FcResultNoMatch */ && n > 0) {
    return 3; /* FcResultNoId */
  }
  return res;
}

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  gboolean start_hidden;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gchar* resolve_executable_path() {
  return g_file_read_link("/proc/self/exe", nullptr);
}

static gchar* resolve_app_icon_path() {
  g_autofree gchar* exe_path = resolve_executable_path();
  if (!exe_path) return nullptr;
  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
  gchar* icon_path = g_build_filename(
      exe_dir, "data", "flutter_assets", "assets", "icon",
      "vie_lich_logo.png", nullptr);
  if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
    return icon_path;
  }
  g_free(icon_path);
  return nullptr;
}

static void ensure_local_desktop_entry(const gchar* icon_path) {
  if (!icon_path) return;
  g_autofree gchar* exe_path = resolve_executable_path();
  if (!exe_path) return;

  const gchar* data_home = g_get_user_data_dir();
  if (!data_home) return;

  g_autofree gchar* apps_dir = g_build_filename(data_home, "applications", nullptr);
  g_mkdir_with_parents(apps_dir, 0755);

  g_autofree gchar* desktop_file =
      g_build_filename(apps_dir, APPLICATION_ID ".desktop", nullptr);
  g_autofree gchar* content = g_strdup_printf(
      "[Desktop Entry]\n"
      "Version=1.0\n"
      "Type=Application\n"
      "Name=VIE Lịch\n"
      "Comment=Ứng dụng Lịch Âm Dương Việt Nam\n"
      "Exec=\"%s\" %%u\n"
      "Icon=%s\n"
      "Terminal=false\n"
      "Categories=Utility;Calendar;Office;\n"
      "MimeType=x-scheme-handler/vielich;application/vnd.vielich;\n"
      "StartupWMClass=%s\n",
      exe_path, icon_path, APPLICATION_ID);
  g_file_set_contents(desktop_file, content, -1, nullptr);

  // Đăng ký scheme vielich:// cho user hiện tại
  g_autofree gchar* cmd = g_strdup_printf(
      "(update-desktop-database \"%s\" >/dev/null 2>&1; "
      "xdg-mime default %s.desktop x-scheme-handler/vielich >/dev/null 2>&1) &",
      apps_dir, APPLICATION_ID);
  int rc = system(cmd);
  (void)rc;
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  g_autofree gchar* icon_path = resolve_app_icon_path();
  if (icon_path && GTK_IS_WINDOW(toplevel)) {
    gtk_window_set_icon_from_file(GTK_WINDOW(toplevel), icon_path, nullptr);
  }
  if (!self->start_hidden) {
    gtk_widget_show(toplevel);
  }
}

static gboolean on_main_window_delete_event(GtkWidget* widget,
                                            GdkEvent* event,
                                            gpointer user_data) {
  gtk_widget_hide(widget);
  return TRUE;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows) {
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }

  g_autofree gchar* icon_path = resolve_app_icon_path();
  if (icon_path) {
    gtk_window_set_default_icon_from_file(icon_path, nullptr);
    ensure_local_desktop_entry(icon_path);
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  if (icon_path) {
    gtk_window_set_icon_from_file(window, icon_path, nullptr);
  }

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "VIE Lịch");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    if (icon_path) {
      GdkPixbuf* pixbuf =
          gdk_pixbuf_new_from_file_at_scale(icon_path, 22, 22, TRUE, nullptr);
      if (pixbuf) {
        GtkWidget* icon_img = gtk_image_new_from_pixbuf(pixbuf);
        g_object_unref(pixbuf);
        gtk_widget_set_margin_start(icon_img, 8);
        gtk_widget_show(icon_img);
        gtk_header_bar_pack_start(header_bar, icon_img);
      }
    }
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "VIE Lịch");
  }

  gtk_window_set_default_size(window, 1000, 700);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Hide main window instead of quitting when clicking the close button (X),
  // keeping the tray icon and desktop widget running in the background.
  g_signal_connect(window, "delete-event",
                   G_CALLBACK(on_main_window_delete_event), nullptr);

  FlEngine* engine = fl_view_get_engine(view);
  desktop_widget_init(application, window,
                      fl_engine_get_binary_messenger(engine));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::command_line.
static gint my_application_command_line(GApplication* application,
                                        GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  gint argc = 0;
  g_auto(GStrv) argv =
      g_application_command_line_get_arguments(command_line, &argc);

  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows == nullptr) {
    // Khởi chạy lần đầu (Cold start)
    g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
    if (argc > 1) {
      self->dart_entrypoint_arguments = g_strdupv(argv + 1);
    }
    self->start_hidden = FALSE;
    if (self->dart_entrypoint_arguments != nullptr) {
      for (int i = 0; self->dart_entrypoint_arguments[i] != nullptr; ++i) {
        if (g_strcmp0(self->dart_entrypoint_arguments[i], "--autostart") == 0) {
          self->start_hidden = TRUE;
          break;
        }
      }
    }
    my_application_activate(application);
  } else {
    // App đang chạy ngầm hoặc đang mở (Warm start, ví dụ nhận link vielich://)
    GtkWindow* window = GTK_WINDOW(windows->data);
    gtk_widget_show(GTK_WIDGET(window));
    gtk_window_present(window);
  }

  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  desktop_widget_cleanup();

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE,
                                     nullptr));
}
