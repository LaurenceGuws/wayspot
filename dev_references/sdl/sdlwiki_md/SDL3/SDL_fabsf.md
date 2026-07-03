# SDL_fabsf

Compute the absolute value of `x`

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_fabsf(float x);
```

</div>

## Function Parameters

|       |       |                                               |
|-------|-------|-----------------------------------------------|
| float | **x** | floating point value to use as the magnitude. |

## Return Value

(float) Returns the absolute value of `x`.

## Remarks

Domain: `-INF <= x <= INF`

Range: `0 <= y <= INF`

This function operates on single-precision floating point values, use
[SDL_fabs](SDL_fabs.html) for double-precision floats.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_fabs](SDL_fabs.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
