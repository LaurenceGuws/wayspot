# SDL_ceilf

Compute the ceiling of `x`.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_ceilf(float x);
```

</div>

## Function Parameters

|       |       |                       |
|-------|-------|-----------------------|
| float | **x** | floating point value. |

## Return Value

(float) Returns the ceiling of `x`.

## Remarks

The ceiling of `x` is the smallest integer `y` such that `y >= x`, i.e
`x` rounded up to the nearest integer.

Domain: `-INF <= x <= INF`

Range: `-INF <= y <= INF`, y integer

This function operates on single-precision floating point values, use
[SDL_ceil](SDL_ceil.html) for double-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ceil](SDL_ceil.html)
- [SDL_floorf](SDL_floorf.html)
- [SDL_truncf](SDL_truncf.html)
- [SDL_roundf](SDL_roundf.html)
- [SDL_lroundf](SDL_lroundf.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
