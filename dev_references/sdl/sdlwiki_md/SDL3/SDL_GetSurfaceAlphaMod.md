# SDL_GetSurfaceAlphaMod

Get the additional alpha value used in blit operations.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetSurfaceAlphaMod(SDL_Surface *surface, Uint8 *alpha);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to query. |
| Uint8 \* | **alpha** | a pointer filled in with the current alpha value. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetSurfaceColorMod](SDL_GetSurfaceColorMod.html)
- [SDL_SetSurfaceAlphaMod](SDL_SetSurfaceAlphaMod.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
