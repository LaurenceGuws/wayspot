# SDL_FILE

A macro that reports the current file being compiled.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_FILE    __FILE_NAME__
```

</div>

## Remarks

This macro is only defined if it isn't already defined, so to override
it (perhaps with something that doesn't provide path information at all,
so build machine information doesn't leak into public binaries), apps
can define this macro before including SDL.h or
[SDL_assert](SDL_assert.html).h.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAssert](CategoryAssert.html)
