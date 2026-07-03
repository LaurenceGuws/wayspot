# SDL_RemoveSurfaceAlternateImages

Remove all alternate versions of a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_RemoveSurfaceAlternateImages(SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to update. |

## Remarks

This function removes a reference from all the alternative versions,
destroying them if this is the last reference to them.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddSurfaceAlternateImage](SDL_AddSurfaceAlternateImage.html)
- [SDL_GetSurfaceImages](SDL_GetSurfaceImages.html)
- [SDL_SurfaceHasAlternateImages](SDL_SurfaceHasAlternateImages.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
