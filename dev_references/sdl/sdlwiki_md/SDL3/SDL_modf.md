# SDL_modf

Split `x` into integer and fractional parts

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_modf(double x, double *y);
```

</div>

## Function Parameters

|           |       |                                                  |
|-----------|-------|--------------------------------------------------|
| double    | **x** | floating point value.                            |
| double \* | **y** | output pointer to store the integer part of `x`. |

## Return Value

(double) Returns the fractional part of `x`.

## Remarks

This function operates on double-precision floating point values, use
[SDL_modff](SDL_modff.html) for single-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_modff](SDL_modff.html)
- [SDL_trunc](SDL_trunc.html)
- [SDL_fmod](SDL_fmod.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
