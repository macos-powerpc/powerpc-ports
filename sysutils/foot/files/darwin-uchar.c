#include "darwin-uchar.h"

size_t
mbrtoc32(char32_t *pc32, const char *s, size_t n, mbstate_t *ps)
{
    wchar_t wc;
    size_t rc = mbrtowc(pc32 != NULL ? &wc : NULL, s, n, ps);

    if (pc32 != NULL && rc != (size_t)-1 && rc != (size_t)-2)
        *pc32 = (char32_t)wc;

    return rc;
}

size_t
c32rtomb(char *s, char32_t c32, mbstate_t *ps)
{
    return wcrtomb(s, (wchar_t)c32, ps);
}
