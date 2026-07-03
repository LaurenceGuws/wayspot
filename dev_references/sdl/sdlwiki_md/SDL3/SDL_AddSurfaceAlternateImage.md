# SDL_AddSurfaceAlternateImage

Add an alternate version of a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_AddSurfaceAlternateImage(SDL_Surface *surface, SDL_Surface *image);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to update. |
| [SDL_Surface](SDL_Surface.html) \* | **image** | a pointer to an alternate [SDL_Surface](SDL_Surface.html) to associate with this surface. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function adds an alternate version of this surface, usually used
for content with high DPI representations like cursors or icons. The
size, format, and content do not need to match the original surface, and
these alternate versions will not be updated when the original surface
changes.

This function adds a reference to the alternate version, so you should
call [SDL_DestroySurface](SDL_DestroySurface.html)() on the image after
this call.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RemoveSurfaceAlternateImages](SDL_RemoveSurfaceAlternateImages.html)
- [SDL_GetSurfaceImages](SDL_GetSurfaceImages.html)
- [SDL_SurfaceHasAlternateImages](SDL_SurfaceHasAlternateImages.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
