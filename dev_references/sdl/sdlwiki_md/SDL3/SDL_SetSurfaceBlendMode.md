# SDL_SetSurfaceBlendMode

Set the blend mode used for blit operations.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetSurfaceBlendMode(SDL_Surface *surface, SDL_BlendMode blendMode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to update. |
| [SDL_BlendMode](SDL_BlendMode.html) | **blendMode** | the [SDL_BlendMode](SDL_BlendMode.html) to use for blit blending. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

To copy a surface to another surface (or texture) without blending with
the existing data, the blendmode of the SOURCE surface should be set to
[`SDL_BLENDMODE_NONE`](SDL_BLENDMODE_NONE.html).

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetSurfaceBlendMode](SDL_GetSurfaceBlendMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
