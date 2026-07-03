# SDL_GetSurfaceClipRect

Get the clipping rectangle for a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetSurfaceClipRect(SDL_Surface *surface, SDL_Rect *rect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure representing the surface to be clipped. |
| [SDL_Rect](SDL_Rect.html) \* | **rect** | an [SDL_Rect](SDL_Rect.html) structure filled in with the clipping rectangle for the surface. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

When `surface` is the destination of a blit, only the area within the
clip rectangle is drawn into.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetSurfaceClipRect](SDL_SetSurfaceClipRect.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
