#include "desktop_widget.h"

#include <cairo.h>
#include <math.h>
#include <pango/pangocairo.h>
#include <stdlib.h>
#include <string.h>

#include <string>
#include <vector>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

namespace {

constexpr int kShadowPad = 8;
constexpr int kSnapMargin = 20;
constexpr int kSnapThreshold = 35;

struct CellData {
  int ngay_duong = 1;
  int ngay_am = 1;
  int thang_am = 1;
  bool la_chu_nhat = false;
  bool la_hom_nay = false;
  bool co_su_kien = false;
  bool la_dau_thang_am = false;
  bool la_trong_thang = true;
};

struct WidgetState {
  GApplication* application = nullptr;
  GtkWindow* main_window = nullptr;
  GtkWidget* widget_window = nullptr;
  FlMethodChannel* channel = nullptr;

  // Native GTK System Tray
  GtkStatusIcon* tray_icon = nullptr;
  GtkWidget* tray_menu = nullptr;
  GtkCheckMenuItem* item_visible = nullptr;
  GtkCheckMenuItem* item_locked = nullptr;
  GtkCheckMenuItem* item_autostart = nullptr;
  GtkCheckMenuItem* item_size_small = nullptr;
  GtkCheckMenuItem* item_size_medium = nullptr;
  GtkCheckMenuItem* item_size_large = nullptr;
  GtkCheckMenuItem* item_size_xlarge = nullptr;
  bool updating_menu_ui = false;

  bool visible = true;
  bool locked = false;
  bool is_dark = false;
  bool autostart = false;
  std::string size_mode = "large";  // small, medium, large, extraLarge

  int card_width = 400;
  int card_height = 300;
  int pos_x = -1;
  int pos_y = -1;
  bool pos_initialized = false;

  // Drag state
  bool dragging = false;
  double drag_start_root_x = 0;
  double drag_start_root_y = 0;
  int drag_start_win_x = 0;
  int drag_start_win_y = 0;

  // Calendar data
  bool has_data = false;
  int thang_duong = 1;
  int nam_duong = 2026;
  int ngay_duong = 1;
  std::string thu = "Thứ Hai";
  int ngay_am = 1;
  int thang_am = 1;
  int nam_am = 2026;
  std::string can_chi_nam = "";
  std::string ten_su_kien = "Không có sự kiện sắp tới";
  std::string thoi_gian_su_kien = "";
  std::string loai_su_kien = "event";
  std::vector<CellData> ds_o;
};

WidgetState g_state;

bool detect_system_dark_mode() {
  GtkSettings* settings = gtk_settings_get_default();
  if (!settings) return false;

  gboolean prefer_dark = FALSE;
  gchar* theme_name = nullptr;
  g_object_get(settings,
               "gtk-application-prefer-dark-theme", &prefer_dark,
               "gtk-theme-name", &theme_name,
               nullptr);

  bool dark = (prefer_dark == TRUE);
  if (!dark && theme_name != nullptr) {
    if (strstr(theme_name, "Dark") != nullptr ||
        strstr(theme_name, "dark") != nullptr) {
      dark = true;
    }
  }
  g_free(theme_name);
  return dark;
}

void update_dimensions_for_mode() {
  if (g_state.size_mode == "small") {
    g_state.card_width = 220;
    g_state.card_height = 175;
  } else if (g_state.size_mode == "medium") {
    g_state.card_width = 380;
    g_state.card_height = 210;
  } else if (g_state.size_mode == "extraLarge") {
    g_state.card_width = 560;
    g_state.card_height = 340;
  } else {
    g_state.card_width = 400;
    g_state.card_height = 300;
  }
}

void draw_rounded_rect(cairo_t* cr,
                       double x,
                       double y,
                       double w,
                       double h,
                       double r) {
  if (r > w / 2.0) r = w / 2.0;
  if (r > h / 2.0) r = h / 2.0;
  cairo_new_sub_path(cr);
  cairo_arc(cr, x + w - r, y + r, r, -M_PI / 2.0, 0);
  cairo_arc(cr, x + w - r, y + h - r, r, 0, M_PI / 2.0);
  cairo_arc(cr, x + r, y + h - r, r, M_PI / 2.0, M_PI);
  cairo_arc(cr, x + r, y + r, r, M_PI, 3.0 * M_PI / 2.0);
  cairo_close_path(cr);
}

void draw_pango_text(cairo_t* cr,
                     const char* text,
                     double x,
                     double y,
                     double max_width,
                     const char* font_desc_str,
                     double r,
                     double g,
                     double b,
                     double a,
                     PangoAlignment align,
                     bool ellipsize = true) {
  PangoLayout* layout = pango_cairo_create_layout(cr);
  pango_layout_set_text(layout, text, -1);

  PangoFontDescription* desc = pango_font_description_from_string(font_desc_str);
  pango_layout_set_font_description(layout, desc);
  pango_font_description_free(desc);

  if (max_width > 0) {
    pango_layout_set_width(layout, static_cast<int>(max_width * PANGO_SCALE));
    pango_layout_set_alignment(layout, align);
    if (ellipsize) {
      pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
      pango_layout_set_single_paragraph_mode(layout, TRUE);
    }
  }

  cairo_save(cr);
  cairo_set_source_rgba(cr, r, g, b, a);
  cairo_move_to(cr, x, y);
  pango_cairo_show_layout(cr, layout);
  cairo_restore(cr);

  g_object_unref(layout);
}

void get_text_size(cairo_t* cr,
                   const char* text,
                   const char* font_desc_str,
                   int* out_w,
                   int* out_h) {
  PangoLayout* layout = pango_cairo_create_layout(cr);
  pango_layout_set_text(layout, text, -1);
  PangoFontDescription* desc = pango_font_description_from_string(font_desc_str);
  pango_layout_set_font_description(layout, desc);
  pango_font_description_free(desc);
  pango_layout_get_pixel_size(layout, out_w, out_h);
  g_object_unref(layout);
}

void draw_event_icon(cairo_t* cr,
                     double x,
                     double y,
                     double size,
                     const std::string& loai) {
  cairo_save(cr);
  // Orange icon color (#FF9500)
  cairo_set_source_rgba(cr, 1.0, 0.584, 0.0, 1.0);
  cairo_set_line_width(cr, 1.5);

  if (loai == "cake") {
    // Birthday cake icon
    draw_rounded_rect(cr, x + size * 0.15, y + size * 0.45, size * 0.7,
                      size * 0.45, 2.0);
    cairo_stroke(cr);
    cairo_move_to(cr, x + size * 0.5, y + size * 0.2);
    cairo_line_to(cr, x + size * 0.5, y + size * 0.45);
    cairo_stroke(cr);
    cairo_arc(cr, x + size * 0.5, y + size * 0.16, size * 0.06, 0, 2 * M_PI);
    cairo_fill(cr);
  } else if (loai == "alarm") {
    // Alarm clock icon
    cairo_arc(cr, x + size * 0.5, y + size * 0.54, size * 0.36, 0, 2 * M_PI);
    cairo_stroke(cr);
    cairo_move_to(cr, x + size * 0.5, y + size * 0.34);
    cairo_line_to(cr, x + size * 0.5, y + size * 0.54);
    cairo_line_to(cr, x + size * 0.65, y + size * 0.54);
    cairo_stroke(cr);
  } else {
    // Calendar icon
    draw_rounded_rect(cr, x + size * 0.12, y + size * 0.2, size * 0.76,
                      size * 0.68, 2.5);
    cairo_stroke(cr);
    cairo_move_to(cr, x + size * 0.12, y + size * 0.42);
    cairo_line_to(cr, x + size * 0.88, y + size * 0.42);
    cairo_move_to(cr, x + size * 0.32, y + size * 0.1);
    cairo_line_to(cr, x + size * 0.32, y + size * 0.28);
    cairo_move_to(cr, x + size * 0.68, y + size * 0.1);
    cairo_line_to(cr, x + size * 0.68, y + size * 0.28);
    cairo_stroke(cr);
  }
  cairo_restore(cr);
}

void draw_next_event_bar(cairo_t* cr,
                         double x,
                         double y,
                         double w,
                         double h,
                         int font_size,
                         double icon_size) {
  double pri_r = g_state.is_dark ? 0.95 : 0.12;
  double pri_g = g_state.is_dark ? 0.95 : 0.12;
  double pri_b = g_state.is_dark ? 0.97 : 0.14;

  double sec_r = g_state.is_dark ? 0.68 : 0.45;
  double sec_g = g_state.is_dark ? 0.68 : 0.45;
  double sec_b = g_state.is_dark ? 0.72 : 0.48;

  double cy = y + (h - icon_size) / 2.0;
  draw_event_icon(cr, x, cy, icon_size, g_state.loai_su_kien);

  double text_x = x + icon_size + 6.0;
  double avail_w = w - (icon_size + 6.0);

  char font_bold[64];
  snprintf(font_bold, sizeof(font_bold), "Sans Semibold %d", font_size);
  char font_reg[64];
  snprintf(font_reg, sizeof(font_reg), "Sans %d", font_size - 1);

  int tw = 0, th = 0;
  get_text_size(cr, g_state.ten_su_kien.c_str(), font_bold, &tw, &th);
  double text_y = y + (h - th) / 2.0;

  if (g_state.thoi_gian_su_kien.empty()) {
    draw_pango_text(cr, g_state.ten_su_kien.c_str(), text_x, text_y, avail_w,
                    font_bold, pri_r, pri_g, pri_b, 1.0, PANGO_ALIGN_LEFT);
  } else {
    std::string suffix = "  •  " + g_state.thoi_gian_su_kien;
    int sw = 0, sh = 0;
    get_text_size(cr, suffix.c_str(), font_reg, &sw, &sh);

    double max_title_w = avail_w - sw;
    if (max_title_w < avail_w * 0.45) {
      max_title_w = avail_w * 0.45;
    }
    double actual_title_w = (tw < max_title_w) ? tw : max_title_w;

    draw_pango_text(cr, g_state.ten_su_kien.c_str(), text_x, text_y,
                    actual_title_w, font_bold, pri_r, pri_g, pri_b, 1.0,
                    PANGO_ALIGN_LEFT);

    double sub_x = text_x + actual_title_w;
    double sub_w = avail_w - actual_title_w;
    if (sub_w > 10) {
      double sub_y = y + (h - sh) / 2.0;
      draw_pango_text(cr, suffix.c_str(), sub_x, sub_y, sub_w, font_reg, sec_r,
                      sec_g, sec_b, 1.0, PANGO_ALIGN_LEFT);
    }
  }
}

void draw_calendar_grid(cairo_t* cr,
                        double x,
                        double y,
                        double w,
                        double h,
                        int title_font,
                        int dow_font,
                        int duong_font,
                        int am_font) {
  double pri_r = g_state.is_dark ? 0.95 : 0.12;
  double pri_g = g_state.is_dark ? 0.95 : 0.12;
  double pri_b = g_state.is_dark ? 0.97 : 0.14;

  double sec_r = g_state.is_dark ? 0.62 : 0.48;
  double sec_g = g_state.is_dark ? 0.62 : 0.48;
  double sec_b = g_state.is_dark ? 0.66 : 0.52;

  // 1. Month title ("Tháng MM/YYYY")
  char title_buf[64];
  snprintf(title_buf, sizeof(title_buf), "Tháng %02d/%d", g_state.thang_duong,
           g_state.nam_duong);
  char title_font_str[64];
  snprintf(title_font_str, sizeof(title_font_str), "Sans Bold %d", title_font);
  int title_w = 0, title_h = 0;
  get_text_size(cr, title_buf, title_font_str, &title_w, &title_h);
  draw_pango_text(cr, title_buf, x, y, w, title_font_str, 0.90, 0.20, 0.18, 1.0,
                  PANGO_ALIGN_CENTER);

  double cur_y = y + title_h + (title_font >= 12 ? 6.0 : 3.0);

  // 2. Weekday headers (T2..CN)
  const char* dows[7] = {"T2", "T3", "T4", "T5", "T6", "T7", "CN"};
  char dow_font_str[64];
  snprintf(dow_font_str, sizeof(dow_font_str), "Sans Semibold %d", dow_font);
  int dow_w = 0, dow_h = 0;
  get_text_size(cr, "T2", dow_font_str, &dow_w, &dow_h);

  double cell_w = w / 7.0;
  for (int c = 0; c < 7; ++c) {
    bool is_cn = (c == 6);
    double r = is_cn ? 0.90 : sec_r;
    double g = is_cn ? 0.22 : sec_g;
    double b = is_cn ? 0.20 : sec_b;
    draw_pango_text(cr, dows[c], x + c * cell_w, cur_y, cell_w, dow_font_str, r,
                    g, b, 1.0, PANGO_ALIGN_CENTER);
  }

  cur_y += dow_h + (title_font >= 12 ? 6.0 : 3.0);
  double grid_h = (y + h) - cur_y;
  int num_rows = static_cast<int>(g_state.ds_o.size()) / 7;
  if (num_rows <= 0) num_rows = 5;
  double cell_h = grid_h / num_rows;

  char duong_reg_str[64];
  snprintf(duong_reg_str, sizeof(duong_reg_str), "Sans Medium %d", duong_font);
  char duong_bold_str[64];
  snprintf(duong_bold_str, sizeof(duong_bold_str), "Sans Bold %d", duong_font);

  char am_reg_str[64];
  snprintf(am_reg_str, sizeof(am_reg_str), "Sans %d", am_font);
  char am_bold_str[64];
  snprintf(am_bold_str, sizeof(am_bold_str), "Sans Semibold %d", am_font);

  for (int r = 0; r < num_rows; ++r) {
    for (int c = 0; c < 7; ++c) {
      size_t idx = static_cast<size_t>(r * 7 + c);
      if (idx >= g_state.ds_o.size()) break;
      const CellData& o = g_state.ds_o[idx];

      double cx = x + c * cell_w;
      double cy = cur_y + r * cell_h;
      double alpha_mul = o.la_trong_thang ? 1.0 : 0.35;

      // Today highlight
      if (o.la_hom_nay) {
        cairo_save(cr);
        draw_rounded_rect(cr, cx + 1.5, cy + 1.0, cell_w - 3.0, cell_h - 2.0,
                          5.0);
        cairo_set_source_rgba(cr, 0.92, 0.22, 0.20, 0.16 * alpha_mul);
        cairo_fill(cr);
        cairo_restore(cr);
      }

      // Solar day (top-left)
      char duong_buf[16];
      snprintf(duong_buf, sizeof(duong_buf), "%d", o.ngay_duong);
      double dr = pri_r, dg = pri_g, db = pri_b;
      if (o.la_hom_nay) {
        dr = 0.92;
        dg = 0.20;
        db = 0.18;
      } else if (!o.la_trong_thang) {
        dr = sec_r;
        dg = sec_g;
        db = sec_b;
      } else if (o.la_chu_nhat) {
        dr = 0.90;
        dg = 0.24;
        db = 0.22;
      }

      draw_pango_text(cr, duong_buf, cx + 4.0, cy + 2.0, cell_w - 6.0,
                      o.la_hom_nay ? duong_bold_str : duong_reg_str, dr, dg, db,
                      alpha_mul, PANGO_ALIGN_LEFT, false);

      // Lunar day (bottom-right)
      char am_buf[32];
      if (o.la_dau_thang_am) {
        snprintf(am_buf, sizeof(am_buf), "%d/%d", o.ngay_am, o.thang_am);
      } else {
        snprintf(am_buf, sizeof(am_buf), "%d", o.ngay_am);
      }
      int am_tw = 0, am_th = 0;
      get_text_size(cr, am_buf, o.la_dau_thang_am ? am_bold_str : am_reg_str,
                    &am_tw, &am_th);
      double ar = o.la_dau_thang_am ? 0.90 : sec_r;
      double ag = o.la_dau_thang_am ? 0.22 : sec_g;
      double ab = o.la_dau_thang_am ? 0.20 : sec_b;
      double aa = (o.la_dau_thang_am ? 0.92 : 0.82) * alpha_mul;

      draw_pango_text(cr, am_buf, cx + 2.0, cy + cell_h - am_th - 2.0,
                      cell_w - 5.0,
                      o.la_dau_thang_am ? am_bold_str : am_reg_str, ar, ag, ab,
                      aa, PANGO_ALIGN_RIGHT, false);

      // Event dot (bottom-left)
      if (o.co_su_kien) {
        cairo_save(cr);
        double dot_r = (duong_font >= 12) ? 2.2 : 1.6;
        cairo_arc(cr, cx + 5.0 + dot_r, cy + cell_h - 4.0 - dot_r, dot_r, 0,
                  2 * M_PI);
        cairo_set_source_rgba(cr, 0.92, 0.20, 0.18, alpha_mul);
        cairo_fill(cr);
        cairo_restore(cr);
      }
    }
  }
}

void draw_left_day_column(cairo_t* cr,
                          double x,
                          double y,
                          double w,
                          double h,
                          int big_day_font,
                          int thu_font,
                          int am_font,
                          bool show_top_month) {
  double pri_r = g_state.is_dark ? 0.95 : 0.12;
  double pri_g = g_state.is_dark ? 0.95 : 0.12;
  double pri_b = g_state.is_dark ? 0.97 : 0.14;

  double sec_r = g_state.is_dark ? 0.65 : 0.45;
  double sec_g = g_state.is_dark ? 0.65 : 0.45;
  double sec_b = g_state.is_dark ? 0.70 : 0.48;

  char month_font_str[64];
  snprintf(month_font_str, sizeof(month_font_str), "Sans Semibold %d", am_font);
  char day_font_str[64];
  snprintf(day_font_str, sizeof(day_font_str), "Sans Bold %d", big_day_font);
  char thu_font_str[64];
  snprintf(thu_font_str, sizeof(thu_font_str), "Sans Semibold %d", thu_font);
  char am_font_str[64];
  snprintf(am_font_str, sizeof(am_font_str), "Sans %d", am_font);

  char month_buf[64];
  snprintf(month_buf, sizeof(month_buf), "THÁNG %d", g_state.thang_duong);
  char day_buf[32];
  snprintf(day_buf, sizeof(day_buf), "%d", g_state.ngay_duong);
  char am_buf[128];
  snprintf(am_buf, sizeof(am_buf), "%d/%d %s", g_state.ngay_am,
           g_state.thang_am, g_state.can_chi_nam.c_str());

  int mw = 0, mh = 0;
  if (show_top_month) {
    get_text_size(cr, month_buf, month_font_str, &mw, &mh);
  }
  int dw = 0, dh = 0;
  get_text_size(cr, day_buf, day_font_str, &dw, &dh);
  int tw = 0, th = 0;
  get_text_size(cr, g_state.thu.c_str(), thu_font_str, &tw, &th);
  int aw = 0, ah = 0;
  get_text_size(cr, am_buf, am_font_str, &aw, &ah);

  double total_h = dh + th + ah + 8.0 + (show_top_month ? (mh + 2.0) : 0.0);
  double cur_y = y + (h - total_h) / 2.0;

  if (show_top_month) {
    draw_pango_text(cr, month_buf, x, cur_y, w, month_font_str, sec_r, sec_g,
                    sec_b, 1.0, PANGO_ALIGN_CENTER);
    cur_y += mh + 2.0;
  }

  draw_pango_text(cr, day_buf, x, cur_y, w, day_font_str, 0.92, 0.20, 0.18, 1.0,
                  PANGO_ALIGN_CENTER);
  cur_y += dh + 2.0;

  draw_pango_text(cr, g_state.thu.c_str(), x, cur_y, w, thu_font_str, pri_r,
                  pri_g, pri_b, 1.0, PANGO_ALIGN_CENTER);
  cur_y += th + 4.0;

  draw_pango_text(cr, am_buf, x, cur_y, w, am_font_str, sec_r, sec_g, sec_b,
                  1.0, PANGO_ALIGN_CENTER);
}

gboolean on_widget_draw(GtkWidget* widget, cairo_t* cr, gpointer user_data) {
  // Clear transparent background
  cairo_save(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
  cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0);
  cairo_paint(cr);
  cairo_restore(cr);

  double x = kShadowPad;
  double y = kShadowPad;
  double w = g_state.card_width;
  double h = g_state.card_height;
  double radius = 22.0;

  // Soft outer drop shadow layers
  for (int i = 4; i >= 1; --i) {
    double spread = i * 1.6;
    double alpha = 0.045 * (5 - i);
    cairo_save(cr);
    draw_rounded_rect(cr, x - spread + 0.5, y - spread + 2.0, w + spread * 2,
                      h + spread * 2, radius + spread);
    cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, alpha);
    cairo_fill(cr);
    cairo_restore(cr);
  }

  // Card background (macOS WidgetKit style)
  cairo_save(cr);
  draw_rounded_rect(cr, x, y, w, h, radius);
  if (g_state.is_dark) {
    cairo_set_source_rgba(cr, 0.12, 0.12, 0.14, 0.94);
  } else {
    cairo_set_source_rgba(cr, 0.99, 0.99, 1.0, 0.95);
  }
  cairo_fill_preserve(cr);

  // Subtle card border
  cairo_set_line_width(cr, 1.0);
  if (g_state.is_dark) {
    cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.12);
  } else {
    cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.08);
  }
  cairo_stroke(cr);
  cairo_restore(cr);

  if (!g_state.has_data) {
    draw_pango_text(cr, "Đang tải dữ liệu lịch...", x + 16, y + h / 2 - 10,
                    w - 32, "Sans 11", 0.5, 0.5, 0.5, 1.0, PANGO_ALIGN_CENTER);
    return FALSE;
  }

  double div_r = g_state.is_dark ? 1.0 : 0.0;
  double div_g = g_state.is_dark ? 1.0 : 0.0;
  double div_b = g_state.is_dark ? 1.0 : 0.0;
  double div_a = g_state.is_dark ? 0.14 : 0.10;

  if (g_state.size_mode == "small") {
    double bottom_h = 26.0;
    double top_h = h - bottom_h - 10.0;
    draw_left_day_column(cr, x + 10, y + 6, w - 20, top_h, 46, 11, 9, true);

    // Short centered divider
    cairo_save(cr);
    cairo_set_source_rgba(cr, div_r, div_g, div_b, div_a);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x + w * 0.3, y + h - bottom_h - 2.0);
    cairo_line_to(cr, x + w * 0.7, y + h - bottom_h - 2.0);
    cairo_stroke(cr);
    cairo_restore(cr);

    draw_next_event_bar(cr, x + 10, y + h - bottom_h, w - 20, bottom_h - 4, 9,
                        11.0);
  } else if (g_state.size_mode == "medium") {
    double bottom_h = 26.0;
    double top_h = h - bottom_h - 2.0;
    double left_w = 96.0;

    draw_left_day_column(cr, x + 8, y + 6, left_w, top_h - 8, 36, 9, 8, false);

    // Vertical divider
    cairo_save(cr);
    cairo_set_source_rgba(cr, div_r, div_g, div_b, div_a);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x + left_w + 12, y + 12);
    cairo_line_to(cr, x + left_w + 12, y + top_h - 6);
    cairo_stroke(cr);
    cairo_restore(cr);

    draw_calendar_grid(cr, x + left_w + 20, y + 6, w - left_w - 30, top_h - 10,
                       9, 7, 8, 6);

    // Horizontal divider
    cairo_save(cr);
    cairo_set_source_rgba(cr, div_r, div_g, div_b, div_a);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x + 10, y + top_h);
    cairo_line_to(cr, x + w - 10, y + top_h);
    cairo_stroke(cr);
    cairo_restore(cr);

    draw_next_event_bar(cr, x + 10, y + top_h + 2, w - 20, bottom_h - 4, 9,
                        11.0);
  } else if (g_state.size_mode == "extraLarge") {
    double bottom_h = 36.0;
    double top_h = h - bottom_h - 2.0;
    double left_w = 156.0;

    draw_left_day_column(cr, x + 14, y + 10, left_w, top_h - 16, 64, 13, 10,
                         false);

    // Vertical divider
    cairo_save(cr);
    cairo_set_source_rgba(cr, div_r, div_g, div_b, div_a);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x + left_w + 22, y + top_h * 0.15);
    cairo_line_to(cr, x + left_w + 22, y + top_h * 0.85);
    cairo_stroke(cr);
    cairo_restore(cr);

    draw_calendar_grid(cr, x + left_w + 36, y + 12, w - left_w - 52, top_h - 20,
                       12, 9, 12, 8);

    // Horizontal divider
    cairo_save(cr);
    cairo_set_source_rgba(cr, div_r, div_g, div_b, div_a);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x + 16, y + top_h);
    cairo_line_to(cr, x + w - 16, y + top_h);
    cairo_stroke(cr);
    cairo_restore(cr);

    draw_next_event_bar(cr, x + 16, y + top_h + 2, w - 32, bottom_h - 4, 11,
                        14.0);
  } else {
    // Large (344 x 344) - Default macOS desktop widget style
    double bottom_h = 34.0;
    double top_h = h - bottom_h - 2.0;

    draw_calendar_grid(cr, x + 12, y + 10, w - 24, top_h - 16, 12, 9, 12, 8);

    // Horizontal divider
    cairo_save(cr);
    cairo_set_source_rgba(cr, div_r, div_g, div_b, div_a);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x + 12, y + top_h);
    cairo_line_to(cr, x + w - 12, y + top_h);
    cairo_stroke(cr);
    cairo_restore(cr);

    draw_next_event_bar(cr, x + 12, y + top_h + 2, w - 24, bottom_h - 4, 10,
                        13.0);
  }

  return FALSE;
}

void compute_snapped_window_position(int raw_win_x,
                                     int raw_win_y,
                                     int* out_win_x,
                                     int* out_win_y) {
  int card_x = raw_win_x + kShadowPad;
  int card_y = raw_win_y + kShadowPad;
  int card_w = g_state.card_width;
  int card_h = g_state.card_height;

  GdkDisplay* display = gdk_display_get_default();
  if (!display) {
    *out_win_x = raw_win_x;
    *out_win_y = raw_win_y;
    return;
  }

  GdkMonitor* monitor = gdk_display_get_monitor_at_point(
      display, card_x + card_w / 2, card_y + card_h / 2);
  if (!monitor) {
    monitor = gdk_display_get_primary_monitor(display);
  }
  if (!monitor && gdk_display_get_n_monitors(display) > 0) {
    monitor = gdk_display_get_monitor(display, 0);
  }
  if (!monitor) {
    *out_win_x = raw_win_x;
    *out_win_y = raw_win_y;
    return;
  }

  GdkRectangle workarea;
  gdk_monitor_get_workarea(monitor, &workarea);

  int left_target = workarea.x + kSnapMargin;
  int right_target = workarea.x + workarea.width - card_w - kSnapMargin;
  int top_target = workarea.y + kSnapMargin;
  int bottom_target = workarea.y + workarea.height - card_h - kSnapMargin;

  // Snap X (20px from left or right edge)
  if (abs(card_x - left_target) <= kSnapThreshold || card_x < left_target) {
    card_x = left_target;
  } else if (abs(card_x - right_target) <= kSnapThreshold ||
             card_x > right_target) {
    card_x = right_target;
  }

  // Snap Y (20px from top or bottom edge)
  if (abs(card_y - top_target) <= kSnapThreshold || card_y < top_target) {
    card_y = top_target;
  } else if (abs(card_y - bottom_target) <= kSnapThreshold ||
             card_y > bottom_target) {
    card_y = bottom_target;
  }

  *out_win_x = card_x - kShadowPad;
  *out_win_y = card_y - kShadowPad;
}

void set_default_top_right_position() {
  GdkDisplay* display = gdk_display_get_default();
  GdkMonitor* monitor =
      display ? gdk_display_get_primary_monitor(display) : nullptr;
  if (!monitor && display && gdk_display_get_n_monitors(display) > 0) {
    monitor = gdk_display_get_monitor(display, 0);
  }
  if (monitor) {
    GdkRectangle workarea;
    gdk_monitor_get_workarea(monitor, &workarea);
    int card_x =
        workarea.x + workarea.width - g_state.card_width - kSnapMargin;
    int card_y = workarea.y + kSnapMargin;
    g_state.pos_x = card_x - kShadowPad;
    g_state.pos_y = card_y - kShadowPad;
  } else {
    g_state.pos_x = 100;
    g_state.pos_y = 40;
  }
  g_state.pos_initialized = true;
}

void notify_position_changed(int win_x, int win_y) {
  if (!g_state.channel) return;
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "x", fl_value_new_int(win_x));
  fl_value_set_string_take(args, "y", fl_value_new_int(win_y));
  fl_method_channel_invoke_method(g_state.channel, "onPositionChanged", args,
                                  nullptr, nullptr, nullptr);
}

gboolean on_widget_button_press(GtkWidget* widget,
                                GdkEventButton* event,
                                gpointer user_data) {
  if (event->button == 1 && !g_state.locked &&
      event->type == GDK_BUTTON_PRESS) {
    g_state.dragging = true;
    g_state.drag_start_root_x = event->x_root;
    g_state.drag_start_root_y = event->y_root;
    gtk_window_get_position(GTK_WINDOW(widget), &g_state.drag_start_win_x,
                            &g_state.drag_start_win_y);
    return TRUE;
  }
  return FALSE;
}

gboolean on_widget_motion_notify(GtkWidget* widget,
                                 GdkEventMotion* event,
                                 gpointer user_data) {
  if (g_state.dragging && !g_state.locked) {
    int raw_x = g_state.drag_start_win_x +
                static_cast<int>(event->x_root - g_state.drag_start_root_x);
    int raw_y = g_state.drag_start_win_y +
                static_cast<int>(event->y_root - g_state.drag_start_root_y);

    int snapped_x = raw_x;
    int snapped_y = raw_y;
    compute_snapped_window_position(raw_x, raw_y, &snapped_x, &snapped_y);

    g_state.pos_x = snapped_x;
    g_state.pos_y = snapped_y;
    gtk_window_move(GTK_WINDOW(widget), snapped_x, snapped_y);
    return TRUE;
  }
  return FALSE;
}

gboolean on_widget_button_release(GtkWidget* widget,
                                  GdkEventButton* event,
                                  gpointer user_data) {
  if (event->button == 1 && g_state.dragging) {
    g_state.dragging = false;
    int cur_x = g_state.pos_x;
    int cur_y = g_state.pos_y;
    gtk_window_get_position(GTK_WINDOW(widget), &cur_x, &cur_y);

    int snapped_x = cur_x;
    int snapped_y = cur_y;
    compute_snapped_window_position(cur_x, cur_y, &snapped_x, &snapped_y);

    g_state.pos_x = snapped_x;
    g_state.pos_y = snapped_y;
    gtk_window_move(GTK_WINDOW(widget), snapped_x, snapped_y);
    notify_position_changed(snapped_x, snapped_y);
    return TRUE;
  }
  return FALSE;
}

void ensure_widget_window_created() {
  if (g_state.widget_window != nullptr) return;

  update_dimensions_for_mode();
  int total_w = g_state.card_width + kShadowPad * 2;
  int total_h = g_state.card_height + kShadowPad * 2;

  GtkWidget* win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  g_state.widget_window = win;

  gtk_window_set_title(GTK_WINDOW(win), "VIE Lịch Widget");
  gtk_window_set_decorated(GTK_WINDOW(win), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(win), FALSE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(win), TRUE);
  gtk_window_set_skip_pager_hint(GTK_WINDOW(win), TRUE);
  gtk_window_set_keep_below(GTK_WINDOW(win), TRUE);
  gtk_window_stick(GTK_WINDOW(win));
  gtk_window_set_accept_focus(GTK_WINDOW(win), FALSE);
  gtk_window_set_type_hint(GTK_WINDOW(win), GDK_WINDOW_TYPE_HINT_UTILITY);

  gtk_widget_set_size_request(win, total_w, total_h);
  gtk_window_set_default_size(GTK_WINDOW(win), total_w, total_h);

  // Enable RGBA transparency
  GdkScreen* screen = gtk_widget_get_screen(win);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr && gdk_screen_is_composited(screen)) {
    gtk_widget_set_visual(win, visual);
  }
  gtk_widget_set_app_paintable(win, TRUE);

  gtk_widget_add_events(win, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
                                 GDK_POINTER_MOTION_MASK);

  g_signal_connect(win, "draw", G_CALLBACK(on_widget_draw), nullptr);
  g_signal_connect(win, "button-press-event",
                   G_CALLBACK(on_widget_button_press), nullptr);
  g_signal_connect(win, "motion-notify-event",
                   G_CALLBACK(on_widget_motion_notify), nullptr);
  g_signal_connect(win, "button-release-event",
                   G_CALLBACK(on_widget_button_release), nullptr);
  g_signal_connect(win, "delete-event", G_CALLBACK(gtk_widget_hide_on_delete),
                   nullptr);

  if (!g_state.pos_initialized || g_state.pos_x < -kShadowPad ||
      g_state.pos_y < -kShadowPad) {
    set_default_top_right_position();
  }
  gtk_window_move(GTK_WINDOW(win), g_state.pos_x, g_state.pos_y);
}

void parse_widget_data(FlValue* args) {
  if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return;

  FlValue* v = nullptr;
  if ((v = fl_value_lookup_string(args, "thangDuong")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    g_state.thang_duong = static_cast<int>(fl_value_get_int(v));
  }
  if ((v = fl_value_lookup_string(args, "namDuong")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    g_state.nam_duong = static_cast<int>(fl_value_get_int(v));
  }
  if ((v = fl_value_lookup_string(args, "ngayDuong")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    g_state.ngay_duong = static_cast<int>(fl_value_get_int(v));
  }
  if ((v = fl_value_lookup_string(args, "thu")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    g_state.thu = fl_value_get_string(v);
  }
  if ((v = fl_value_lookup_string(args, "ngayAm")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    g_state.ngay_am = static_cast<int>(fl_value_get_int(v));
  }
  if ((v = fl_value_lookup_string(args, "thangAm")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    g_state.thang_am = static_cast<int>(fl_value_get_int(v));
  }
  if ((v = fl_value_lookup_string(args, "namAm")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_INT) {
    g_state.nam_am = static_cast<int>(fl_value_get_int(v));
  }
  if ((v = fl_value_lookup_string(args, "canChiNam")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    g_state.can_chi_nam = fl_value_get_string(v);
  }
  if ((v = fl_value_lookup_string(args, "tenSuKien")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    g_state.ten_su_kien = fl_value_get_string(v);
  }
  if ((v = fl_value_lookup_string(args, "thoiGianSuKien")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    g_state.thoi_gian_su_kien = fl_value_get_string(v);
  }
  if ((v = fl_value_lookup_string(args, "loaiSuKien")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    g_state.loai_su_kien = fl_value_get_string(v);
  }
  if ((v = fl_value_lookup_string(args, "isDark")) &&
      fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
    g_state.is_dark = fl_value_get_bool(v);
  }

  FlValue* ds_o = fl_value_lookup_string(args, "dsO");
  if (ds_o && fl_value_get_type(ds_o) == FL_VALUE_TYPE_LIST) {
    g_state.ds_o.clear();
    size_t len = fl_value_get_length(ds_o);
    g_state.ds_o.reserve(len);
    for (size_t i = 0; i < len; ++i) {
      FlValue* item = fl_value_get_list_value(ds_o, i);
      if (!item || fl_value_get_type(item) != FL_VALUE_TYPE_MAP) continue;
      CellData cell;
      FlValue* cv = nullptr;
      if ((cv = fl_value_lookup_string(item, "ngayDuong")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_INT) {
        cell.ngay_duong = static_cast<int>(fl_value_get_int(cv));
      }
      if ((cv = fl_value_lookup_string(item, "ngayAm")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_INT) {
        cell.ngay_am = static_cast<int>(fl_value_get_int(cv));
      }
      if ((cv = fl_value_lookup_string(item, "thangAm")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_INT) {
        cell.thang_am = static_cast<int>(fl_value_get_int(cv));
      }
      if ((cv = fl_value_lookup_string(item, "laChuNhat")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_BOOL) {
        cell.la_chu_nhat = fl_value_get_bool(cv);
      }
      if ((cv = fl_value_lookup_string(item, "laHomNay")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_BOOL) {
        cell.la_hom_nay = fl_value_get_bool(cv);
      }
      if ((cv = fl_value_lookup_string(item, "coSuKien")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_BOOL) {
        cell.co_su_kien = fl_value_get_bool(cv);
      }
      if ((cv = fl_value_lookup_string(item, "laDauThangAm")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_BOOL) {
        cell.la_dau_thang_am = fl_value_get_bool(cv);
      }
      if ((cv = fl_value_lookup_string(item, "laTrongThang")) &&
          fl_value_get_type(cv) == FL_VALUE_TYPE_BOOL) {
        cell.la_trong_thang = fl_value_get_bool(cv);
      }
      g_state.ds_o.push_back(cell);
    }
    g_state.has_data = true;
  }
}

void sync_tray_menu_check_states() {
  if (!g_state.tray_menu) return;
  g_state.updating_menu_ui = true;
  if (g_state.item_visible) {
    gtk_check_menu_item_set_active(g_state.item_visible,
                                   g_state.visible ? TRUE : FALSE);
  }
  if (g_state.item_locked) {
    gtk_check_menu_item_set_active(g_state.item_locked,
                                   g_state.locked ? TRUE : FALSE);
  }
  if (g_state.item_autostart) {
    gtk_check_menu_item_set_active(g_state.item_autostart,
                                   g_state.autostart ? TRUE : FALSE);
  }
  if (g_state.item_size_small) {
    gtk_check_menu_item_set_active(
        g_state.item_size_small, g_state.size_mode == "small" ? TRUE : FALSE);
  }
  if (g_state.item_size_medium) {
    gtk_check_menu_item_set_active(
        g_state.item_size_medium, g_state.size_mode == "medium" ? TRUE : FALSE);
  }
  if (g_state.item_size_large) {
    gtk_check_menu_item_set_active(
        g_state.item_size_large, g_state.size_mode == "large" ? TRUE : FALSE);
  }
  if (g_state.item_size_xlarge) {
    gtk_check_menu_item_set_active(
        g_state.item_size_xlarge,
        g_state.size_mode == "extraLarge" ? TRUE : FALSE);
  }
  g_state.updating_menu_ui = false;
}

void apply_widget_size_and_position(int old_card_w, int old_card_h) {
  ensure_widget_window_created();
  update_dimensions_for_mode();

  // Keep widget anchored to the right or bottom edge if it was snapped there
  GdkDisplay* display = gdk_display_get_default();
  if (display && old_card_w > 0 && old_card_h > 0 && g_state.pos_initialized) {
    int old_card_x = g_state.pos_x + kShadowPad;
    int old_card_y = g_state.pos_y + kShadowPad;
    GdkMonitor* monitor = gdk_display_get_monitor_at_point(
        display, old_card_x + old_card_w / 2, old_card_y + old_card_h / 2);
    if (!monitor) monitor = gdk_display_get_primary_monitor(display);
    if (!monitor && gdk_display_get_n_monitors(display) > 0) {
      monitor = gdk_display_get_monitor(display, 0);
    }
    if (monitor) {
      GdkRectangle workarea;
      gdk_monitor_get_workarea(monitor, &workarea);
      int old_right_target =
          workarea.x + workarea.width - old_card_w - kSnapMargin;
      int old_bottom_target =
          workarea.y + workarea.height - old_card_h - kSnapMargin;

      if (abs(old_card_x - old_right_target) <= kSnapThreshold) {
        int new_right_target =
            workarea.x + workarea.width - g_state.card_width - kSnapMargin;
        g_state.pos_x = new_right_target - kShadowPad;
      }
      if (abs(old_card_y - old_bottom_target) <= kSnapThreshold) {
        int new_bottom_target =
            workarea.y + workarea.height - g_state.card_height - kSnapMargin;
        g_state.pos_y = new_bottom_target - kShadowPad;
      }
    }
  }

  int total_w = g_state.card_width + kShadowPad * 2;
  int total_h = g_state.card_height + kShadowPad * 2;
  gtk_widget_set_size_request(g_state.widget_window, total_w, total_h);
  gtk_window_resize(GTK_WINDOW(g_state.widget_window), total_w, total_h);

  int snapped_x = g_state.pos_x;
  int snapped_y = g_state.pos_y;
  compute_snapped_window_position(g_state.pos_x, g_state.pos_y, &snapped_x,
                                  &snapped_y);
  g_state.pos_x = snapped_x;
  g_state.pos_y = snapped_y;
  gtk_window_move(GTK_WINDOW(g_state.widget_window), g_state.pos_x,
                  g_state.pos_y);
  gtk_widget_queue_draw(g_state.widget_window);
}

void on_tray_open_main_window(GtkMenuItem* item, gpointer user_data) {
  if (g_state.main_window) {
    gtk_widget_show(GTK_WIDGET(g_state.main_window));
    gtk_window_deiconify(g_state.main_window);
    gtk_window_present(g_state.main_window);
  }
  if (g_state.channel) {
    fl_method_channel_invoke_method(g_state.channel, "onShowMainWindow",
                                    nullptr, nullptr, nullptr, nullptr);
  }
}

void on_tray_toggle_visible(GtkCheckMenuItem* item, gpointer user_data) {
  if (g_state.updating_menu_ui) return;
  g_state.visible = gtk_check_menu_item_get_active(item) == TRUE;
  ensure_widget_window_created();
  if (g_state.visible) {
    gtk_widget_show_all(g_state.widget_window);
    gtk_window_move(GTK_WINDOW(g_state.widget_window), g_state.pos_x,
                    g_state.pos_y);
    gtk_window_set_keep_below(GTK_WINDOW(g_state.widget_window), TRUE);
    gtk_window_stick(GTK_WINDOW(g_state.widget_window));
    gtk_widget_queue_draw(g_state.widget_window);
  } else {
    gtk_widget_hide(g_state.widget_window);
  }

  if (g_state.channel) {
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "visible",
                             fl_value_new_bool(g_state.visible));
    fl_method_channel_invoke_method(g_state.channel, "onVisibleChanged", args,
                                    nullptr, nullptr, nullptr);
  }
}

void on_tray_toggle_locked(GtkCheckMenuItem* item, gpointer user_data) {
  if (g_state.updating_menu_ui) return;
  g_state.locked = gtk_check_menu_item_get_active(item) == TRUE;
  if (g_state.locked) {
    g_state.dragging = false;
  }

  if (g_state.channel) {
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "locked", fl_value_new_bool(g_state.locked));
    fl_method_channel_invoke_method(g_state.channel, "onLockedChanged", args,
                                    nullptr, nullptr, nullptr);
  }
}

void on_tray_select_size(GtkCheckMenuItem* item, gpointer user_data) {
  if (g_state.updating_menu_ui) return;
  const char* target_mode = static_cast<const char*>(user_data);
  if (!target_mode) return;

  int old_w = g_state.card_width;
  int old_h = g_state.card_height;
  g_state.size_mode = target_mode;
  sync_tray_menu_check_states();
  apply_widget_size_and_position(old_w, old_h);
  notify_position_changed(g_state.pos_x, g_state.pos_y);

  if (g_state.channel) {
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "sizeMode",
                             fl_value_new_string(g_state.size_mode.c_str()));
    fl_method_channel_invoke_method(g_state.channel, "onSizeModeChanged", args,
                                    nullptr, nullptr, nullptr);
  }
}

void on_tray_toggle_autostart(GtkCheckMenuItem* item, gpointer user_data) {
  if (g_state.updating_menu_ui) return;
  g_state.autostart = gtk_check_menu_item_get_active(item) == TRUE;

  if (g_state.channel) {
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "autostart",
                             fl_value_new_bool(g_state.autostart));
    fl_method_channel_invoke_method(g_state.channel, "onAutostartChanged", args,
                                    nullptr, nullptr, nullptr);
  }
}

void on_tray_quit_app(GtkMenuItem* item, gpointer user_data) {
  if (g_state.application) {
    g_application_quit(g_state.application);
  }
  exit(0);
}

gboolean on_tray_icon_button_press(GtkStatusIcon* status_icon,
                                   GdkEventButton* event,
                                   gpointer user_data) {
  // Consume button-press so ShellTrayIcon's synthesized press+release pair
  // opens the menu cleanly on button-release without immediately closing it.
  return TRUE;
}

gboolean on_tray_icon_button_release(GtkStatusIcon* status_icon,
                                     GdkEventButton* event,
                                     gpointer user_data) {
  if (!g_state.tray_menu) return FALSE;
  sync_tray_menu_check_states();
  gtk_widget_show_all(g_state.tray_menu);
  gtk_menu_popup(GTK_MENU(g_state.tray_menu), nullptr, nullptr,
                 gtk_status_icon_position_menu, status_icon, 0,
                 GDK_CURRENT_TIME);
  return TRUE;
}

void ensure_tray_icon_created() {
  if (g_state.tray_icon != nullptr) return;

  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* exe_dir =
      exe_path ? g_path_get_dirname(exe_path) : g_strdup(".");
  g_autofree gchar* logo_path =
      g_build_filename(exe_dir, "data", "flutter_assets", "assets", "icon",
                       "vie_lich_logo.png", nullptr);
  g_autofree gchar* mac_tray_path =
      g_build_filename(exe_dir, "data", "flutter_assets", "assets", "icon",
                       "tray_mac.png", nullptr);

  const gchar* chosen_icon = nullptr;
  if (g_file_test(logo_path, G_FILE_TEST_EXISTS)) {
    chosen_icon = logo_path;
  } else if (g_file_test(mac_tray_path, G_FILE_TEST_EXISTS)) {
    chosen_icon = mac_tray_path;
  }

  if (chosen_icon) {
    g_state.tray_icon = gtk_status_icon_new_from_file(chosen_icon);
  } else {
    g_state.tray_icon = gtk_status_icon_new_from_icon_name("x-office-calendar");
  }
  gtk_status_icon_set_title(g_state.tray_icon, "VIE Lịch");
  gtk_status_icon_set_tooltip_text(g_state.tray_icon, "VIE Lịch");
  gtk_status_icon_set_visible(g_state.tray_icon, TRUE);

  g_signal_connect(g_state.tray_icon, "button-press-event",
                   G_CALLBACK(on_tray_icon_button_press), nullptr);
  g_signal_connect(g_state.tray_icon, "button-release-event",
                   G_CALLBACK(on_tray_icon_button_release), nullptr);

  // Build native GTK3 popup menu (submenus fly out automatically on hover)
  GtkWidget* menu = gtk_menu_new();
  g_state.tray_menu = menu;

  GtkWidget* open_item = gtk_menu_item_new_with_label("Mở cửa sổ Lịch");
  g_signal_connect(open_item, "activate", G_CALLBACK(on_tray_open_main_window),
                   nullptr);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), open_item);

  gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());

  GtkWidget* vis_item =
      gtk_check_menu_item_new_with_label("Hiện Widget ngoài Desktop");
  g_state.item_visible = GTK_CHECK_MENU_ITEM(vis_item);
  g_signal_connect(vis_item, "toggled", G_CALLBACK(on_tray_toggle_visible),
                   nullptr);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), vis_item);

  GtkWidget* lock_item =
      gtk_check_menu_item_new_with_label("Khóa vị trí Widget");
  g_state.item_locked = GTK_CHECK_MENU_ITEM(lock_item);
  g_signal_connect(lock_item, "toggled", G_CALLBACK(on_tray_toggle_locked),
                   nullptr);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), lock_item);

  // Size submenu (extends automatically when hovered)
  GtkWidget* size_root = gtk_menu_item_new_with_label("Kích thước Widget");
  GtkWidget* size_sub = gtk_menu_new();

  GtkWidget* s_small = gtk_check_menu_item_new_with_label("Nhỏ (Small)");
  gtk_check_menu_item_set_draw_as_radio(GTK_CHECK_MENU_ITEM(s_small), TRUE);
  g_state.item_size_small = GTK_CHECK_MENU_ITEM(s_small);
  g_signal_connect(s_small, "toggled", G_CALLBACK(on_tray_select_size),
                   const_cast<char*>("small"));
  gtk_menu_shell_append(GTK_MENU_SHELL(size_sub), s_small);

  GtkWidget* s_med = gtk_check_menu_item_new_with_label("Vừa (Medium)");
  gtk_check_menu_item_set_draw_as_radio(GTK_CHECK_MENU_ITEM(s_med), TRUE);
  g_state.item_size_medium = GTK_CHECK_MENU_ITEM(s_med);
  g_signal_connect(s_med, "toggled", G_CALLBACK(on_tray_select_size),
                   const_cast<char*>("medium"));
  gtk_menu_shell_append(GTK_MENU_SHELL(size_sub), s_med);

  GtkWidget* s_large =
      gtk_check_menu_item_new_with_label("Lớn (Large - Mặc định)");
  gtk_check_menu_item_set_draw_as_radio(GTK_CHECK_MENU_ITEM(s_large), TRUE);
  g_state.item_size_large = GTK_CHECK_MENU_ITEM(s_large);
  g_signal_connect(s_large, "toggled", G_CALLBACK(on_tray_select_size),
                   const_cast<char*>("large"));
  gtk_menu_shell_append(GTK_MENU_SHELL(size_sub), s_large);

  GtkWidget* s_xlarge =
      gtk_check_menu_item_new_with_label("Rất lớn (Extra Large)");
  gtk_check_menu_item_set_draw_as_radio(GTK_CHECK_MENU_ITEM(s_xlarge), TRUE);
  g_state.item_size_xlarge = GTK_CHECK_MENU_ITEM(s_xlarge);
  g_signal_connect(s_xlarge, "toggled", G_CALLBACK(on_tray_select_size),
                   const_cast<char*>("extraLarge"));
  gtk_menu_shell_append(GTK_MENU_SHELL(size_sub), s_xlarge);

  gtk_menu_item_set_submenu(GTK_MENU_ITEM(size_root), size_sub);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), size_root);

  gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());

  GtkWidget* auto_item =
      gtk_check_menu_item_new_with_label("Khởi động khi bật máy");
  g_state.item_autostart = GTK_CHECK_MENU_ITEM(auto_item);
  g_signal_connect(auto_item, "toggled", G_CALLBACK(on_tray_toggle_autostart),
                   nullptr);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), auto_item);

  gtk_menu_shell_append(GTK_MENU_SHELL(menu), gtk_separator_menu_item_new());

  GtkWidget* quit_item = gtk_menu_item_new_with_label("Thoát ứng dụng");
  g_signal_connect(quit_item, "activate", G_CALLBACK(on_tray_quit_app),
                   nullptr);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);

  sync_tray_menu_check_states();
  gtk_widget_show_all(menu);
}

void method_call_cb(FlMethodChannel* channel,
                    FlMethodCall* method_call,
                    gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "configure") == 0) {
    int old_w = g_state.card_width;
    int old_h = g_state.card_height;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = nullptr;
      if ((v = fl_value_lookup_string(args, "visible")) &&
          fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        g_state.visible = fl_value_get_bool(v);
      }
      if ((v = fl_value_lookup_string(args, "locked")) &&
          fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        g_state.locked = fl_value_get_bool(v);
      }
      if ((v = fl_value_lookup_string(args, "isDark")) &&
          fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        g_state.is_dark = fl_value_get_bool(v);
      }
      if ((v = fl_value_lookup_string(args, "autostart")) &&
          fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        g_state.autostart = fl_value_get_bool(v);
      }
      if ((v = fl_value_lookup_string(args, "sizeMode")) &&
          fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
        g_state.size_mode = fl_value_get_string(v);
      }
      FlValue* vx = fl_value_lookup_string(args, "x");
      FlValue* vy = fl_value_lookup_string(args, "y");
      if (vx && vy && fl_value_get_type(vx) == FL_VALUE_TYPE_INT &&
          fl_value_get_type(vy) == FL_VALUE_TYPE_INT) {
        int x = static_cast<int>(fl_value_get_int(vx));
        int y = static_cast<int>(fl_value_get_int(vy));
        if (x >= -kShadowPad && y >= -kShadowPad) {
          g_state.pos_x = x;
          g_state.pos_y = y;
          g_state.pos_initialized = true;
        }
      }
    }

    ensure_tray_icon_created();
    sync_tray_menu_check_states();
    apply_widget_size_and_position(old_w, old_h);

    if (g_state.visible) {
      gtk_widget_show_all(g_state.widget_window);
      gtk_window_move(GTK_WINDOW(g_state.widget_window), g_state.pos_x,
                      g_state.pos_y);
      gtk_window_set_keep_below(GTK_WINDOW(g_state.widget_window), TRUE);
      gtk_window_stick(GTK_WINDOW(g_state.widget_window));
      gtk_widget_queue_draw(g_state.widget_window);
    } else {
      gtk_widget_hide(g_state.widget_window);
    }

    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "updateData") == 0) {
    parse_widget_data(args);
    ensure_widget_window_created();
    if (g_state.visible) {
      gtk_widget_show_all(g_state.widget_window);
      gtk_window_move(GTK_WINDOW(g_state.widget_window), g_state.pos_x,
                      g_state.pos_y);
      gtk_window_set_keep_below(GTK_WINDOW(g_state.widget_window), TRUE);
      gtk_window_stick(GTK_WINDOW(g_state.widget_window));
      gtk_widget_queue_draw(g_state.widget_window);
    }
    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "setDarkMode") == 0) {
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "isDark");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        g_state.is_dark = fl_value_get_bool(v);
      }
    }
    if (g_state.widget_window) {
      gtk_widget_queue_draw(g_state.widget_window);
    }
    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "setVisible") == 0) {
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "visible");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        g_state.visible = fl_value_get_bool(v);
      }
    }
    sync_tray_menu_check_states();
    ensure_widget_window_created();
    if (g_state.visible) {
      gtk_widget_show_all(g_state.widget_window);
      gtk_window_move(GTK_WINDOW(g_state.widget_window), g_state.pos_x,
                      g_state.pos_y);
      gtk_window_set_keep_below(GTK_WINDOW(g_state.widget_window), TRUE);
      gtk_window_stick(GTK_WINDOW(g_state.widget_window));
      gtk_widget_queue_draw(g_state.widget_window);
    } else {
      gtk_widget_hide(g_state.widget_window);
    }
    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "setLocked") == 0) {
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "locked");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
        g_state.locked = fl_value_get_bool(v);
      }
    }
    sync_tray_menu_check_states();
    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "setSizeMode") == 0) {
    int old_w = g_state.card_width;
    int old_h = g_state.card_height;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* v = fl_value_lookup_string(args, "sizeMode");
      if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
        g_state.size_mode = fl_value_get_string(v);
      }
    }
    sync_tray_menu_check_states();
    apply_widget_size_and_position(old_w, old_h);
    notify_position_changed(g_state.pos_x, g_state.pos_y);

    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "showMainWindow") == 0) {
    if (g_state.main_window) {
      gtk_widget_show(GTK_WIDGET(g_state.main_window));
      gtk_window_deiconify(g_state.main_window);
      gtk_window_present(g_state.main_window);
    }
    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "hideMainWindow") == 0) {
    if (g_state.main_window) {
      gtk_widget_hide(GTK_WIDGET(g_state.main_window));
    }
    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else if (g_strcmp0(method, "quitApp") == 0) {
    if (g_state.application) {
      g_application_quit(g_state.application);
    }
    g_autoptr(FlValue) res = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

}  // namespace

void desktop_widget_init(GApplication* application,
                         GtkWindow* main_window,
                         FlBinaryMessenger* messenger) {
  g_state.application = application;
  g_state.main_window = main_window;
  g_state.is_dark = detect_system_dark_mode();

  // Keep GApplication alive even when all GtkApplicationWindows are hidden
  g_application_hold(application);

  ensure_tray_icon_created();

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_state.channel = fl_method_channel_new(
      messenger, "com.toanbb.vie_lich/linux_widget", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(g_state.channel, method_call_cb,
                                            nullptr, nullptr);
}

void desktop_widget_cleanup(void) {
  if (g_state.tray_menu != nullptr) {
    gtk_widget_destroy(g_state.tray_menu);
    g_state.tray_menu = nullptr;
  }
  g_clear_object(&g_state.tray_icon);
  if (g_state.widget_window != nullptr) {
    gtk_widget_destroy(g_state.widget_window);
    g_state.widget_window = nullptr;
  }
  g_clear_object(&g_state.channel);
}

#pragma GCC diagnostic pop

