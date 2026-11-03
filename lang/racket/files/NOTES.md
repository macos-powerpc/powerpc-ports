# racket 9.3 for ppcports

## Blank text in native DrRacket (racket/racket#5386)

racket/gui draws every canvas into a `CGLayer`: `layer-bitmap%` in
`gui-lib/mred/private/wx/cocoa/dc.rkt` wraps `CGLayerGetContext()` with
`cairo_quartz_surface_create_for_cg_context()`. A layer context is not a bitmap
context, so cairo can only draw on it natively:

- quartz scaled font: `_cairo_quartz_cg_glyphs()` draws the glyphs with CoreGraphics.
- any other font (FreeType): falls back to `_cairo_fallback_compositor`, which needs
  `_cairo_quartz_surface_map_to_image()`. That returns `SURFACE_TYPE_MISMATCH` for
  non-bitmap contexts, so the glyphs are dropped and the `cairo_t` goes into an error
  state. Lines, rectangles and fills are native CG operations, so only text disappears.

In Dec 2025, MacPorts cairo on 10.6 had no Quartz font backend: meson only enables it
when `CTFontDrawGlyphs` links, and that function is 10.7+. Pango therefore had no
CoreText font map either. `pango_cairo_font_map_new()`, which racket/draw uses, then
returned the fontconfig map, which produces FreeType fonts, so canvas text was blank.
Racket's own `draw-ppc-macosx-3` libraries have Quartz fonts, which is why
mflatt saw text with them.

ppcports now ships cairo 1.18.6 with `cairo-enable-quartz-font.patch` and
`cairo-ctfontdrawglyphs-fallback.patch` (10.6+), and pango 1.58.0 with
`patch-meson.build-quartz.diff` (darwin 10). With those, Racket text should take the
native path with no Racket-side change. The Portfile refuses to configure the native
GUI if `cairo-quartz-font.pc` or pango's CoreText font map is missing.

On 10.5, cairo has no Quartz font backend, so `+x11` is the default there.

## Check before the long build

`racket-text-probe.m` replays Racket's three text targets (image surface, quartz
bitmap, CGLayer canvas) with the installed cairo and pango. Run it from a GUI login,
not over ssh:

    gcc -x objective-c -o racket-text-probe racket-text-probe.m \
        $(pkg-config --cflags --libs pangocairo cairo-quartz) -framework Cocoa
    ./racket-text-probe
    PANGOCAIRO_BACKEND=fc ./racket-text-probe

Expected results:

- Default backend: `PangoCairoCoreTextFontMap`, cairo font type `quartz`, and
  `TEXT VISIBLE` for all three tests.
- `fc` backend: `[layer]` shows an error status and `NO TEXT`. This reproduces #5386.

If the default backend shows `NO TEXT` for `[layer]` or `[image]`, the problem is in
the cairo `CGContextShowGlyphsWithAdvances` fallback. That can be iterated on in the
probe, without rebuilding Racket.

A Racket 9.0 install built against MacPorts libraries loads cairo and pango with
`dlopen` at runtime. If one is still installed, it picks up the current cairo and pango
as-is, so it can serve as a second check.

## Changes from the 9.0-era draft

- 9.3 checksums. The draft still had 9.0's.
- `patch-draw-pango-1.58-char-metrics.diff`: racket/draw ed715f2a53 (after 9.3).
  On Mac, `get-char-width` and `get-char-height` are wrong with Pango >= 1.58.
- The pre-configure guard described above, plus `+x11` as the default on 10.5.
- Already upstream in 9.3, so no longer needed locally:
  - racket/gui ecac746b6c: the 10.6 `redComponent` crash fix (since 9.1).
  - racket/gui ebf3f6cdc9: tab bar frameworks are optional; PSMTabBarControl is used
    below 10.10 or on 32-bit.
  - Chez Scheme dd9eb08da4: ppc32 repairs.
- openssl: kept the draft's (and MacPorts') default `openssl`. The 8.17 port in
  ppcports pinned `openssl-1.1` paths.

## Not covered

Racket's own Mac library builds carry cairo and pango patches that ppcports does not
apply: `courier-new`, `cairo-emptyglyph`, `cairo-quartz-advance`, `coretext-fontreg`
and `pango-coretext-scale` (see `racket/src/native-libs/patches`). They fix spacing,
PDF output and font-registration details, not missing text.
