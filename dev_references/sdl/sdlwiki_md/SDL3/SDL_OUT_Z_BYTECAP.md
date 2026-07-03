# SDL_OUT_Z_BYTECAP

Macro that annotates function params with output buffer string size.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_OUT_Z_BYTECAP(x) _Out_z_bytecap_(x)
```

</div>

## Remarks

If we were to annotate `strcpy`:

<div id="cb2" class="sourceCode">

``` sourceCode
char *strcpy(SDL_OUT_Z_BYTECAP(bufsize) char *dst, const char *src, size_t bufsize);
```

</div>

This notes that `dst` should have a capacity of `bufsize` bytes in size,
and a zero-terminated string is written to it by the function. The
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
