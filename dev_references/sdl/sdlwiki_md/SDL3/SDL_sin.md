# SDL_sin

Compute the sine of `x`.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_sin(double x);
```

</div>

## Function Parameters

|        |       |                                   |
|--------|-------|-----------------------------------|
| double | **x** | floating point value, in radians. |

## Return Value

(double) Returns sine of `x`.

## Remarks

Domain: `-INF <= x <= INF`

Range: `-1 <= y <= 1`

This function operates on double-precision floating point values, use
[SDL_sinf](SDL_sinf.html) for single-precision floats.

This function may use a different approximation across different
versions, platforms and configurations. i.e, it can return a different
value given the same input on different machines or operating systems,
or if SDL is updated.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_sinf](SDL_sinf.html)
- [SDL_asin](SDL_asin.html)
- [SDL_cos](SDL_cos.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
