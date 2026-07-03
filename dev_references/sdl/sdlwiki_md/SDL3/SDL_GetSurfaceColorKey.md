# SDL_GetSurfaceColorKey

Get the color key (transparent pixel) for a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetSurfaceColorKey(SDL_Surface *surface, Uint32 *key);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to query. |
| [Uint32](Uint32.html) \* | **key** | a pointer filled in with the transparent pixel. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The color key is a pixel of the format used by the surface, as generated
by [SDL_MapRGB](SDL_MapRGB.html)().

If the surface doesn't have color key enabled this function returns
false.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetSurfaceColorKey](SDL_SetSurfaceColorKey.html)
- [SDL_SurfaceHasColorKey](SDL_SurfaceHasColorKey.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
