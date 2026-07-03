# SDL_trunc

Truncate `x` to an integer.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_trunc(double x);
```

</div>

## Function Parameters

|        |       |                       |
|--------|-------|-----------------------|
| double | **x** | floating point value. |

## Return Value

(double) Returns `x` truncated to an integer.

## Remarks

Rounds `x` to the next closest integer to 0. This is equivalent to
removing the fractional part of `x`, leaving only the integer part.

Domain: `-INF <= x <= INF`

Range: `-INF <= y <= INF`, y integer

This function operates on double-precision floating point values, use
[SDL_truncf](SDL_truncf.html) for single-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_truncf](SDL_truncf.html)
- [SDL_fmod](SDL_fmod.html)
- [SDL_ceil](SDL_ceil.html)
- [SDL_floor](SDL_floor.html)
- [SDL_round](SDL_round.html)
- [SDL_lround](SDL_lround.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
