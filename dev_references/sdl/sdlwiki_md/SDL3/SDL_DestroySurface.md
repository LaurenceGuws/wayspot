# SDL_DestroySurface

Free a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroySurface(SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) to free. |

## Remarks

It is safe to pass NULL to this function.

## Thread Safety

No other thread should be using the surface when it is freed.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateSurface](SDL_CreateSurface.html)
- [SDL_CreateSurfaceFrom](SDL_CreateSurfaceFrom.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
