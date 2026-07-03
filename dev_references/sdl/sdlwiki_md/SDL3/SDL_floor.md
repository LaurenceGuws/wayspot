# SDL_floor

Compute the floor of `x`.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_floor(double x);
```

</div>

## Function Parameters

|        |       |                       |
|--------|-------|-----------------------|
| double | **x** | floating point value. |

## Return Value

(double) Returns the floor of `x`.

## Remarks

The floor of `x` is the largest integer `y` such that `y <= x`, i.e `x`
rounded down to the nearest integer.

Domain: `-INF <= x <= INF`

Range: `-INF <= y <= INF`, y integer

This function operates on double-precision floating point values, use
[SDL_floorf](SDL_floorf.html) for single-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_floorf](SDL_floorf.html)
- [SDL_ceil](SDL_ceil.html)
- [SDL_trunc](SDL_trunc.html)
- [SDL_round](SDL_round.html)
- [SDL_lround](SDL_lround.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
