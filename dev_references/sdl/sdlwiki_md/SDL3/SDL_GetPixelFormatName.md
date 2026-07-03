# SDL_GetPixelFormatName

Get the human readable name of a pixel format.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetPixelFormatName(SDL_PixelFormat format);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PixelFormat](SDL_PixelFormat.html) | **format** | the pixel format to query. |

## Return Value

(const char \*) Returns the human readable name of the specified pixel
format or "[SDL_PIXELFORMAT_UNKNOWN](SDL_PIXELFORMAT_UNKNOWN.html)" if
the format isn't recognized.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPixels](CategoryPixels.html)
