# SDL_PRINTF_FORMAT_STRING

Macro that annotates function params as printf-style format strings.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PRINTF_FORMAT_STRING _Printf_format_string_
```

</div>

## Remarks

If we were to annotate `fprintf`:

<div id="cb2" class="sourceCode">

``` sourceCode
int fprintf(FILE *f, SDL_PRINTF_FORMAT_STRING const char *fmt, ...);
```

</div>

This notes that `fmt` should be a printf-style format string. The
compiler or other analysis tools can warn when this doesn't appear to be
the case.

On compilers without this annotation mechanism, this is defined to
nothing.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
