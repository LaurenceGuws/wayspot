# SDL_roundf

Round `x` to the nearest integer.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_roundf(float x);
```

</div>

## Function Parameters

|       |       |                       |
|-------|-------|-----------------------|
| float | **x** | floating point value. |

## Return Value

(float) Returns the nearest integer to `x`.

## Remarks

Rounds `x` to the nearest integer. Values halfway between integers will
be rounded away from zero.

Domain: `-INF <= x <= INF`

Range: `-INF <= y <= INF`, y integer

This function operates on single-precision floating point values, use
[SDL_round](SDL_round.html) for double-precision floats. To get the
result as an integer type, use [SDL_lroundf](SDL_lroundf.html).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_round](SDL_round.html)
- [SDL_lroundf](SDL_lroundf.html)
- [SDL_floorf](SDL_floorf.html)
- [SDL_ceilf](SDL_ceilf.html)
- [SDL_truncf](SDL_truncf.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
