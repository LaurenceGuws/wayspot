# SDL_GetPixelFormatDetails

Create an [SDL_PixelFormatDetails](SDL_PixelFormatDetails.html)
structure corresponding to a pixel format.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const SDL_PixelFormatDetails * SDL_GetPixelFormatDetails(SDL_PixelFormat format);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PixelFormat](SDL_PixelFormat.html) | **format** | one of the [SDL_PixelFormat](SDL_PixelFormat.html) values. |

## Return Value

(const [SDL_PixelFormatDetails](SDL_PixelFormatDetails.html) \*) Returns
a pointer to a [SDL_PixelFormatDetails](SDL_PixelFormatDetails.html)
structure or NULL on failure; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

Returned structure may come from a shared global cache (i.e. not newly
allocated), and hence should not be modified, especially the palette.
Weird errors such as `Blit combination not supported` may occur.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPixels](CategoryPixels.html)
