# SDL_SCANF_FORMAT_STRING

Macro that annotates function params as scanf-style format strings.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_SCANF_FORMAT_STRING _Scanf_format_string_impl_
```

</div>

## Remarks

If we were to annotate `fscanf`:

<div id="cb2" class="sourceCode">

``` sourceCode
int fscanf(FILE *f, SDL_SCANF_FORMAT_STRING const char *fmt, ...);
```

</div>

This notes that `fmt` should be a scanf-style format string. The
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
