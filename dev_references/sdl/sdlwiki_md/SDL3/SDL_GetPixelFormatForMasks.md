# SDL_GetPixelFormatForMasks

Convert a bpp value and RGBA masks to an enumerated pixel format.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PixelFormat SDL_GetPixelFormatForMasks(int bpp, Uint32 Rmask, Uint32 Gmask, Uint32 Bmask, Uint32 Amask);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int | **bpp** | a bits per pixel value; usually 15, 16, or 32. |
| [Uint32](Uint32.html) | **Rmask** | the red mask for the format. |
| [Uint32](Uint32.html) | **Gmask** | the green mask for the format. |
| [Uint32](Uint32.html) | **Bmask** | the blue mask for the format. |
| [Uint32](Uint32.html) | **Amask** | the alpha mask for the format. |

## Return Value

([SDL_PixelFormat](SDL_PixelFormat.html)) Returns the
[SDL_PixelFormat](SDL_PixelFormat.html) value corresponding to the
format masks, or [SDL_PIXELFORMAT_UNKNOWN](SDL_PIXELFORMAT_UNKNOWN.html)
if there isn't a match.

## Remarks

This will return
[`SDL_PIXELFORMAT_UNKNOWN`](SDL_PIXELFORMAT_UNKNOWN.html) if the
conversion wasn't possible.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetMasksForPixelFormat](SDL_GetMasksForPixelFormat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPixels](CategoryPixels.html)
