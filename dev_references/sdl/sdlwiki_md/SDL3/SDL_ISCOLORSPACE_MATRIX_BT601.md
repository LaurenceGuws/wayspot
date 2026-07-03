# SDL_ISCOLORSPACE_MATRIX_BT601

A macro to determine if an [SDL_Colorspace](SDL_Colorspace.html) uses
BT601 (or BT470BG) matrix coefficients.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_ISCOLORSPACE_MATRIX_BT601(cspace)        (SDL_COLORSPACEMATRIX(cspace) == SDL_MATRIX_COEFFICIENTS_BT601 || SDL_COLORSPACEMATRIX(cspace) == SDL_MATRIX_COEFFICIENTS_BT470BG)
```

</div>

## Macro Parameters

|            |                                                    |
|------------|----------------------------------------------------|
| **cspace** | an [SDL_Colorspace](SDL_Colorspace.html) to check. |

## Return Value

Returns true if BT601 or BT470BG, false otherwise.

## Remarks

Note that this macro double-evaluates its parameter, so do not use
expressions with side-effects here.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
