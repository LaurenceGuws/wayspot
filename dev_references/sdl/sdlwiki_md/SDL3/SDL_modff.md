# SDL_modff

Split `x` into integer and fractional parts

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_modff(float x, float *y);
```

</div>

## Function Parameters

|          |       |                                                  |
|----------|-------|--------------------------------------------------|
| float    | **x** | floating point value.                            |
| float \* | **y** | output pointer to store the integer part of `x`. |

## Return Value

(float) Returns the fractional part of `x`.

## Remarks

This function operates on single-precision floating point values, use
[SDL_modf](SDL_modf.html) for double-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_modf](SDL_modf.html)
- [SDL_truncf](SDL_truncf.html)
- [SDL_fmodf](SDL_fmodf.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
