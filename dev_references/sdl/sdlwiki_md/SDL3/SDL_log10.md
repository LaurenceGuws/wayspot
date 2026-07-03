# SDL_log10

Compute the base-10 logarithm of `x`.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_log10(double x);
```

</div>

## Function Parameters

|        |       |                                               |
|--------|-------|-----------------------------------------------|
| double | **x** | floating point value. Must be greater than 0. |

## Return Value

(double) Returns the logarithm of `x`.

## Remarks

Domain: `0 < x <= INF`

Range: `-INF <= y <= INF`

It is an error for `x` to be less than or equal to 0.

This function operates on double-precision floating point values, use
[SDL_log10f](SDL_log10f.html) for single-precision floats.

This function may use a different approximation across different
versions, platforms and configurations. i.e, it can return a different
value given the same input on different machines or operating systems,
or if SDL is updated.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_log10f](SDL_log10f.html)
- [SDL_log](SDL_log.html)
- [SDL_pow](SDL_pow.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
