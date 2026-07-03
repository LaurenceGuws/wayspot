# SDL_fmod

Return the floating-point remainder of `x / y`

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_fmod(double x, double y);
```

</div>

## Function Parameters

|        |       |                                 |
|--------|-------|---------------------------------|
| double | **x** | the numerator.                  |
| double | **y** | the denominator. Must not be 0. |

## Return Value

(double) Returns the remainder of `x / y`.

## Remarks

Divides `x` by `y`, and returns the remainder.

Domain: `-INF <= x <= INF`, `-INF <= y <= INF`, `y != 0`

Range: `-y <= z <= y`

This function operates on double-precision floating point values, use
[SDL_fmodf](SDL_fmodf.html) for single-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_fmodf](SDL_fmodf.html)
- [SDL_modf](SDL_modf.html)
- [SDL_trunc](SDL_trunc.html)
- [SDL_ceil](SDL_ceil.html)
- [SDL_floor](SDL_floor.html)
- [SDL_round](SDL_round.html)
- [SDL_lround](SDL_lround.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
