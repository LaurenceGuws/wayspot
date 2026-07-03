# SDL_FlipSurface

Flip a surface vertically or horizontally.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_FlipSurface(SDL_Surface *surface, SDL_FlipMode flip);
```

</div>

## Function Parameters

|                                    |             |                        |
|------------------------------------|-------------|------------------------|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the surface to flip.   |
| [SDL_FlipMode](SDL_FlipMode.html)  | **flip**    | the direction to flip. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
