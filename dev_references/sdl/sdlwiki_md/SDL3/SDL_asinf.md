# SDL_asinf

Compute the arc sine of `x`.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_asinf(float x);
```

</div>

## Function Parameters

|       |       |                       |
|-------|-------|-----------------------|
| float | **x** | floating point value. |

## Return Value

(float) Returns arc sine of `x`, in radians.

## Remarks

The definition of `y = asin(x)` is `x = sin(y)`.

Domain: `-1 <= x <= 1`

Range: `-Pi/2 <= y <= Pi/2`

This function operates on single-precision floating point values, use
[SDL_asin](SDL_asin.html) for double-precision floats.

This function may use a different approximation across different
versions, platforms and configurations. i.e, it can return a different
value given the same input on different machines or operating systems,
or if SDL is updated.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_asin](SDL_asin.html)
- [SDL_acosf](SDL_acosf.html)
- [SDL_sinf](SDL_sinf.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
