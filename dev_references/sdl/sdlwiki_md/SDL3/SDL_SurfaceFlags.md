# SDL_SurfaceFlags

The flags on an [SDL_Surface](SDL_Surface.html).

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef Uint32 SDL_SurfaceFlags;

#define SDL_SURFACE_PREALLOCATED    0x00000001u /**< Surface uses preallocated pixel memory */
#define SDL_SURFACE_LOCK_NEEDED     0x00000002u /**< Surface needs to be locked to access pixels */
#define SDL_SURFACE_LOCKED          0x00000004u /**< Surface is currently locked */
#define SDL_SURFACE_SIMD_ALIGNED    0x00000008u /**< Surface uses pixel memory allocated with SDL_aligned_alloc() */
```

</div>

## Remarks

These are generally considered read-only.

## Version

This datatype is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySurface](CategorySurface.html)
