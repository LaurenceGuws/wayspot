# SDL_GetSurfaceBlendMode

Get the blend mode used for blit operations.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetSurfaceBlendMode(SDL_Surface *surface, SDL_BlendMode *blendMode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to query. |
| [SDL_BlendMode](SDL_BlendMode.html) \* | **blendMode** | a pointer filled in with the current [SDL_BlendMode](SDL_BlendMode.html). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetSurfaceBlendMode](SDL_SetSurfaceBlendMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
