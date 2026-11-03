/* Reproduces how racket/draw + racket/gui (Cocoa) render text, without Racket.
 *
 *   gcc -x objective-c -o racket-text-probe racket-text-probe.m \
 *       $(pkg-config --cflags --libs pangocairo cairo-quartz) -framework Cocoa
 *   ./racket-text-probe
 *   PANGOCAIRO_BACKEND=fc ./racket-text-probe
 */

#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#import <Cocoa/Cocoa.h>
#include <cairo.h>
#include <cairo-quartz.h>
#include <pango/pangocairo.h>

#define W 320
#define H 48

static const char *backend_tag;

static const char *
font_type_name (cairo_font_type_t t)
{
    switch (t) {
    case CAIRO_FONT_TYPE_TOY:    return "toy";
    case CAIRO_FONT_TYPE_FT:     return "ft";
    case CAIRO_FONT_TYPE_QUARTZ: return "quartz";
    default:                     return "other";
    }
}

static void
draw_text (cairo_t *cr)
{
    PangoFontMap *fm = pango_cairo_font_map_new ();
    PangoContext *ctx;
    PangoLayout *layout;
    PangoLayoutLine *line;
    PangoFontDescription *desc;
    cairo_font_options_t *opts;

    if (!fm) {
        printf ("  pango_cairo_font_map_new () returned NULL\n");
        return;
    }
    printf ("  font map:        %s\n", G_OBJECT_TYPE_NAME (fm));

    ctx = pango_font_map_create_context (fm);
    pango_cairo_update_context (cr, ctx);
    opts = cairo_font_options_create ();
    cairo_font_options_set_antialias (opts, CAIRO_ANTIALIAS_SUBPIXEL);
    pango_cairo_context_set_font_options (ctx, opts);
    cairo_font_options_destroy (opts);

    layout = pango_layout_new (ctx);
    desc = pango_font_description_from_string ("Lucida Grande 24");
    pango_layout_set_font_description (layout, desc);
    pango_layout_set_text (layout, "Hello, Racket", -1);
    line = pango_layout_get_line_readonly (layout, 0);

    if (line && line->runs) {
        PangoGlyphItem *run = line->runs->data;
        PangoFont *font = run->item->analysis.font;
        PangoFontDescription *used = pango_font_describe (font);
        char *name = pango_font_description_to_string (used);
        cairo_scaled_font_t *sf = pango_cairo_font_get_scaled_font (PANGO_CAIRO_FONT (font));

        printf ("  font:            %s\n", name);
        printf ("  cairo font type: %s\n",
                sf ? font_type_name (cairo_scaled_font_get_type (sf)) : "(none)");
        g_free (name);
        pango_font_description_free (used);
    }

    cairo_set_source_rgb (cr, 0, 0, 0);
    cairo_move_to (cr, 8, 36);
    pango_cairo_show_layout_line (cr, line);
    printf ("  cairo status:    %s\n", cairo_status_to_string (cairo_status (cr)));

    pango_font_description_free (desc);
    g_object_unref (layout);
    g_object_unref (ctx);
    g_object_unref (fm);
}

static void
report (const char *test, unsigned char *data, int stride)
{
    long ink = 0;
    int x, y;
    char path[256];
    cairo_surface_t *img;

    for (y = 0; y < H; y++) {
        uint32_t *row = (uint32_t *) (data + y * stride);
        for (x = 0; x < W; x++)
            if (row[x] >> 24)
                ink++;
    }

    snprintf (path, sizeof path, "probe-%s-%s.png", test, backend_tag);
    img = cairo_image_surface_create_for_data (data, CAIRO_FORMAT_ARGB32, W, H, stride);
    cairo_surface_write_to_png (img, path);
    cairo_surface_destroy (img);

    printf ("  ink pixels:      %ld (%s)\n", ink, path);
    printf ("  => %s\n\n", ink > 0 ? "TEXT VISIBLE" : "NO TEXT");
}

static void
test_image (void)
{
    cairo_surface_t *s = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, W, H);
    cairo_t *cr = cairo_create (s);

    printf ("[image]  cairo image surface (make-bitmap)\n");
    draw_text (cr);
    cairo_destroy (cr);
    cairo_surface_flush (s);
    report ("image", cairo_image_surface_get_data (s), cairo_image_surface_get_stride (s));
    cairo_surface_destroy (s);
}

static void
test_quartz_bitmap (void)
{
    cairo_surface_t *s = cairo_quartz_surface_create (CAIRO_FORMAT_ARGB32, W, H);
    cairo_t *cr = cairo_create (s);
    CGContextRef cg;

    printf ("[bitmap] quartz bitmap surface (make-screen-bitmap)\n");
    draw_text (cr);
    cairo_destroy (cr);
    cairo_surface_flush (s);
    cg = cairo_quartz_surface_get_cg_context (s);
    report ("bitmap", CGBitmapContextGetData (cg), (int) CGBitmapContextGetBytesPerRow (cg));
    cairo_surface_destroy (s);
}

static void
test_layer (void)
{
    NSWindow *win;
    CGContextRef wcg, lcg, bcg;
    CGLayerRef layer;
    CGColorSpaceRef cs;
    cairo_surface_t *s;
    cairo_t *cr;
    unsigned char *buf;
    unsigned int (*get_type) (CGContextRef);

    printf ("[layer]  quartz surface on a CGLayer context (racket/gui canvas)\n");

    win = [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 10, 10)
                                      styleMask: NSBorderlessWindowMask
                                        backing: NSBackingStoreBuffered
                                          defer: NO];
    wcg = (CGContextRef) [[NSGraphicsContext graphicsContextWithWindow: win] graphicsPort];
    if (!wcg) {
        printf ("  no window graphics context; run from a GUI login session\n\n");
        [win release];
        return;
    }

    layer = CGLayerCreateWithContext (wcg, CGSizeMake (W, H), NULL);
    lcg = CGLayerGetContext (layer);
    get_type = (unsigned int (*) (CGContextRef)) dlsym (RTLD_DEFAULT, "CGContextGetType");
    if (get_type)
        printf ("  layer ctx type:  %u (4 = bitmap)\n", get_type (lcg));
    CGContextTranslateCTM (lcg, 0, H);
    CGContextScaleCTM (lcg, 1, -1);

    s = cairo_quartz_surface_create_for_cg_context (lcg, W, H);
    cr = cairo_create (s);
    draw_text (cr);
    cairo_destroy (cr);
    cairo_surface_flush (s);
    cairo_surface_destroy (s);

    buf = calloc (H, W * 4);
    cs = CGColorSpaceCreateDeviceRGB ();
    bcg = CGBitmapContextCreate (buf, W, H, 8, W * 4, cs,
                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGContextDrawLayerAtPoint (bcg, CGPointZero, layer);
    CGContextRelease (bcg);
    CGColorSpaceRelease (cs);
    report ("layer", buf, W * 4);

    free (buf);
    CGLayerRelease (layer);
    [win release];
}

int
main (void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    const char *be = getenv ("PANGOCAIRO_BACKEND");

    backend_tag = (be && *be) ? be : "default";
    printf ("cairo %s, pango %s, PANGOCAIRO_BACKEND=%s\n\n",
            cairo_version_string (), pango_version_string (), be ? be : "(unset)");

    [NSApplication sharedApplication];
    test_image ();
    test_quartz_bitmap ();
    test_layer ();

    [pool release];
    return 0;
}
