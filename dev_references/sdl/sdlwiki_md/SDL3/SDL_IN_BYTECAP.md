# SDL_IN_BYTECAP

Macro that annotates function params with input buffer size.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_IN_BYTECAP(x) _In_bytecount_(x)
```

</div>

## Remarks

If we were to annotate `memcpy`:

<div id="cb2" class="sourceCode">

``` sourceCode
void *memcpy(void *dst, SDL_IN_BYTECAP(len) const void *src, size_t len);
```

</div>

This notes that `src` should be `len` bytes in size and is only read by
the function. The compiler or other analysis tools can warn when this
doesn't appear to be the case.

On compilers without this annotation mechanism, this is defined to
nothing.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
