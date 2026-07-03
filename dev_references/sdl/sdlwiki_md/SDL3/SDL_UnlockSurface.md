# SDL_UnlockSurface

Release a surface after directly accessing the pixels.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_UnlockSurface(SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to be unlocked. |

## Thread Safety

This function is not thread safe. The locking referred to by this
function is making the pixels available for direct access, not
thread-safe locking.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_LockSurface](SDL_LockSurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
