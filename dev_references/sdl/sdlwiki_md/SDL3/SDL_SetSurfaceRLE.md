# SDL_SetSurfaceRLE

Set the RLE acceleration hint for a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetSurfaceRLE(SDL_Surface *surface, bool enabled);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to optimize. |
| bool | **enabled** | true to enable RLE acceleration, false to disable it. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

If RLE is enabled, color key and alpha blending blits are much faster,
but the surface must be locked before directly accessing the pixels.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_BlitSurface](SDL_BlitSurface.html)
- [SDL_LockSurface](SDL_LockSurface.html)
- [SDL_UnlockSurface](SDL_UnlockSurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
