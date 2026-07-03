# SDL_ASSERT_FILE

A macro that reports the current file being compiled, for use in
assertions.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_ASSERT_FILE SDL_FILE
```

</div>

## Remarks

This macro is only defined if it isn't already defined, so to override
it (perhaps with something that doesn't provide path information at all,
so build machine information doesn't leak into public binaries), apps
can define this macro before including [SDL_assert](SDL_assert.html).h.
For example, defining this to `""` will make sure no source path
information is included in asserts.

## Version

This macro is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAssert](CategoryAssert.html)
