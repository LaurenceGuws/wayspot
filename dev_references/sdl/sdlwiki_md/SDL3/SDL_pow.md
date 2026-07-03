# SDL_pow

Raise `x` to the power `y`

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_pow(double x, double y);
```

</div>

## Function Parameters

|        |       |               |
|--------|-------|---------------|
| double | **x** | the base.     |
| double | **y** | the exponent. |

## Return Value

(double) Returns `x` raised to the power `y`.

## Remarks

Domain: `-INF <= x <= INF`, `-INF <= y <= INF`

Range: `-INF <= z <= INF`

If `y` is the base of the natural logarithm (e), consider using
[SDL_exp](SDL_exp.html) instead.

This function operates on double-precision floating point values, use
[SDL_powf](SDL_powf.html) for single-precision floats.

This function may use a different approximation across different
versions, platforms and configurations. i.e, it can return a different
value given the same input on different machines or operating systems,
or if SDL is updated.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_powf](SDL_powf.html)
- [SDL_exp](SDL_exp.html)
- [SDL_log](SDL_log.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
