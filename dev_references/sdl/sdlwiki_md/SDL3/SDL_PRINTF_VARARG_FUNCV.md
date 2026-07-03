# SDL_PRINTF_VARARG_FUNCV

Macro that annotates a va_list function that operates like printf.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PRINTF_VARARG_FUNCV( fmtargnumber ) __attribute__(( format( __printf__, fmtargnumber, 0 )))
```

</div>

## Remarks

If we were to annotate `vfprintf`:

<div id="cb2" class="sourceCode">

``` sourceCode
int vfprintf(FILE *f, const char *fmt, va_list ap) SDL_PRINTF_VARARG_FUNCV(2);
```

</div>

This notes that the second parameter should be a printf-style format
string, followed by a va_list. The compiler or other analysis tools can
warn when this doesn't appear to be the case.

On compilers without this annotation mechanism, this is defined to
nothing.

This can (and should) be used with
[SDL_PRINTF_FORMAT_STRING](SDL_PRINTF_FORMAT_STRING.html) as well, which
between them will cover at least Visual Studio, GCC, and Clang.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
