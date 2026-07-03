# SDL_lround

Round `x` to the nearest integer representable as a long

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
long SDL_lround(double x);
```

</div>

## Function Parameters

|        |       |                       |
|--------|-------|-----------------------|
| double | **x** | floating point value. |

## Return Value

(long) Returns the nearest integer to `x`.

## Remarks

Rounds `x` to the nearest integer. Values halfway between integers will
be rounded away from zero.

Domain: `-INF <= x <= INF`

Range: `MIN_LONG <= y <= MAX_LONG`

This function operates on double-precision floating point values, use
[SDL_lroundf](SDL_lroundf.html) for single-precision floats. To get the
result as a floating-point type, use [SDL_round](SDL_round.html).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_lroundf](SDL_lroundf.html)
- [SDL_round](SDL_round.html)
- [SDL_floor](SDL_floor.html)
- [SDL_ceil](SDL_ceil.html)
- [SDL_trunc](SDL_trunc.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
