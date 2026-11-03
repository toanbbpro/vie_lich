#ifndef FLUTTER_MY_APPLICATION_DESKTOP_WIDGET_H_
#define FLUTTER_MY_APPLICATION_DESKTOP_WIDGET_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

void desktop_widget_init(GApplication* application,
                         GtkWindow* main_window,
                         FlBinaryMessenger* messenger);

void desktop_widget_cleanup(void);

G_END_DECLS

#endif  // FLUTTER_MY_APPLICATION_DESKTOP_WIDGET_H_

