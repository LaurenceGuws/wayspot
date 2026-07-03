# SDL_MUSTLOCK

Evaluates to true if the surface needs to be locked before access.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_MUSTLOCK(S) (((S)->flags & SDL_SURFACE_LOCK_NEEDED) == SDL_SURFACE_LOCK_NEEDED)
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategorySurface](CategorySurface.html)
