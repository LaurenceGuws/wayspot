# SDL_GetSurfaceImages

Get an array including all versions of a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface ** SDL_GetSurfaceImages(SDL_Surface *surface, int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to query. |
| int \* | **count** | a pointer filled in with the number of surface pointers returned, may be NULL. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*\*) Returns a NULL terminated array
of [SDL_Surface](SDL_Surface.html) pointers or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Remarks

This returns all versions of a surface, with the surface being queried
as the first element in the returned array.

Freeing the array of surfaces does not affect the surfaces in the array.
They are still referenced by the surface being queried and will be
cleaned up normally.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddSurfaceAlternateImage](SDL_AddSurfaceAlternateImage.html)
- [SDL_RemoveSurfaceAlternateImages](SDL_RemoveSurfaceAlternateImages.html)
- [SDL_SurfaceHasAlternateImages](SDL_SurfaceHasAlternateImages.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
