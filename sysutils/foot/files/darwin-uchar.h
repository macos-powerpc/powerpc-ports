/*
 * Minimal C11 <uchar.h> shim for Darwin (macOS).
 *
 * Apple's libc has never shipped <uchar.h>. This header covers only
 * what foot (https://codeberg.org/dnkl/foot) actually uses: char32_t,
 * mbrtoc32, and c32rtomb. char16_t/mbrtoc16/c16rtomb are not needed
 * and not provided.
 *
 * char32_t must be `unsigned int` here (matching the standard's
 * uint_least32_t-based definition), NOT an alias for Darwin's
 * wchar_t, which is a signed int: the compiler's own U"..." string
 * literals are always typed as an array of the compiler's built-in
 * char32_t (unsigned), independent of any typedef in this header, so
 * aliasing char32_t to a signed type causes -Wpointer-sign errors
 * anywhere foot code writes `U"..."` against a `const char32_t *`
 * parameter. Since Darwin's wchar_t is still 4 bytes UCS-4/UTF-32
 * (same width and representation as char32_t, just signed),
 * foot's own char32.h already reinterpret-casts char32_t* to wchar_t*
 * to call the real wcs.../wc... functions, which remains well-defined
 * with this typedef. Only mbrtoc32/c32rtomb (below) need to actually
 * convert values, since they take char32_t/wchar_t by value/pointee
 * rather than via a pointer cast.
 */
#pragma once

#include <wchar.h>

typedef unsigned int char32_t;

#ifdef __cplusplus
extern "C" {
#endif

size_t mbrtoc32(char32_t *pc32, const char *s, size_t n, mbstate_t *ps);
size_t c32rtomb(char *s, char32_t c32, mbstate_t *ps);

#ifdef __cplusplus
}
#endif
