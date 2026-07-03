# SDL_SurfaceHasAlternateImages

Return whether a surface has alternate versions available.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SurfaceHasAlternateImages(SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to query. |

## Return Value

(bool) Returns true if alternate versions are available or false
otherwise.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddSurfaceAlternateImage](SDL_AddSurfaceAlternateImage.html)
- [SDL_RemoveSurfaceAlternateImages](SDL_RemoveSurfaceAlternateImages.html)
- [SDL_GetSurfaceImages](SDL_GetSurfaceImages.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
