# SDL_round

Round `x` to the nearest integer.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_round(double x);
```

</div>

## Function Parameters

|        |       |                       |
|--------|-------|-----------------------|
| double | **x** | floating point value. |

## Return Value

(double) Returns the nearest integer to `x`.

## Remarks

Rounds `x` to the nearest integer. Values halfway between integers will
be rounded away from zero.

Domain: `-INF <= x <= INF`

Range: `-INF <= y <= INF`, y integer

This function operates on double-precision floating point values, use
[SDL_roundf](SDL_roundf.html) for single-precision floats. To get the
result as an integer type, use [SDL_lround](SDL_lround.html).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_roundf](SDL_roundf.html)
- [SDL_lround](SDL_lround.html)
- [SDL_floor](SDL_floor.html)
- [SDL_ceil](SDL_ceil.html)
- [SDL_trunc](SDL_trunc.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
