# SDL_acosf

Compute the arc cosine of `x`.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_acosf(float x);
```

</div>

## Function Parameters

|       |       |                       |
|-------|-------|-----------------------|
| float | **x** | floating point value. |

## Return Value

(float) Returns arc cosine of `x`, in radians.

## Remarks

The definition of `y = acos(x)` is `x = cos(y)`.

Domain: `-1 <= x <= 1`

Range: `0 <= y <= Pi`

This function operates on single-precision floating point values, use
[SDL_acos](SDL_acos.html) for double-precision floats.

This function may use a different approximation across different
versions, platforms and configurations. i.e, it can return a different
value given the same input on different machines or operating systems,
or if SDL is updated.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_acos](SDL_acos.html)
- [SDL_asinf](SDL_asinf.html)
- [SDL_cosf](SDL_cosf.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
