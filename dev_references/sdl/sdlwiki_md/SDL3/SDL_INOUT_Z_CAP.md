# SDL_INOUT_Z_CAP

Macro that annotates function params with input/output string buffer
size.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_INOUT_Z_CAP(x) _Inout_z_cap_(x)
```

</div>

## Remarks

If we were to annotate `strlcat`:

<div id="cb2" class="sourceCode">

``` sourceCode
size_t strlcat(SDL_INOUT_Z_CAP(maxlen) char *dst, const char *src, size_t maxlen);
```

</div>

This notes that `dst` is a null-terminated C string, should be `maxlen`
bytes in size, and is both read from and written to by the function. The
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
