# SDL_LockSurface

Set up a surface for directly accessing the pixels.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_LockSurface(SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to be locked. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Between calls to [SDL_LockSurface](SDL_LockSurface.html)() /
[SDL_UnlockSurface](SDL_UnlockSurface.html)(), you can write to and read
from `surface->pixels`, using the pixel format stored in
`surface->format`. Once you are done accessing the surface, you should
use [SDL_UnlockSurface](SDL_UnlockSurface.html)() to release it.

Not all surfaces require locking. If `SDL_MUSTLOCK(surface)` evaluates
to 0, then you can read and write to the surface at any time, and the
pixel format of the surface will not change.

## Thread Safety

This function can be called on different threads with different
surfaces. The locking referred to by this function is making the pixels
available for direct access, not thread-safe locking.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_MUSTLOCK](SDL_MUSTLOCK.html)
- [SDL_UnlockSurface](SDL_UnlockSurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
