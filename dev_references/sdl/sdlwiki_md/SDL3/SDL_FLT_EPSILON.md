# SDL_FLT_EPSILON

Epsilon constant, used for comparing floating-point numbers.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_FLT_EPSILON 1.1920928955078125e-07F /* 0x0.000002p0 */
```

</div>

## Remarks

Equals by default to platform-defined `FLT_EPSILON`, or
`1.1920928955078125e-07F` if that's not available.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
