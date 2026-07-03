# SDL_ceil

Compute the ceiling of `x`.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_ceil(double x);
```

</div>

## Function Parameters

|        |       |                       |
|--------|-------|-----------------------|
| double | **x** | floating point value. |

## Return Value

(double) Returns the ceiling of `x`.

## Remarks

The ceiling of `x` is the smallest integer `y` such that `y >= x`, i.e
`x` rounded up to the nearest integer.

Domain: `-INF <= x <= INF`

Range: `-INF <= y <= INF`, y integer

This function operates on double-precision floating point values, use
[SDL_ceilf](SDL_ceilf.html) for single-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ceilf](SDL_ceilf.html)
- [SDL_floor](SDL_floor.html)
- [SDL_trunc](SDL_trunc.html)
- [SDL_round](SDL_round.html)
- [SDL_lround](SDL_lround.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
