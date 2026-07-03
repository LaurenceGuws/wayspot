# SDL_OUT_CAP

Macro that annotates function params with output buffer size.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_OUT_CAP(x) _Out_cap_(x)
```

</div>

## Remarks

If we were to annotate `wcsncpy`:

<div id="cb2" class="sourceCode">

``` sourceCode
char *wcscpy(SDL_OUT_CAP(bufsize) wchar_t *dst, const wchar_t *src, size_t bufsize);
```

</div>

This notes that `dst` should have a capacity of `bufsize` wchar_t in
size, and is only written to by the function. The compiler or other
analysis tools can warn when this doesn't appear to be the case.

This operates on counts of objects, not bytes. Use
[SDL_OUT_BYTECAP](SDL_OUT_BYTECAP.html) for bytes.

On compilers without this annotation mechanism, this is defined to
nothing.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
