# SDL_GetWindowPixelFormat

Get the pixel format associated with the window.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PixelFormat SDL_GetWindowPixelFormat(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |

## Return Value

([SDL_PixelFormat](SDL_PixelFormat.html)) Returns the pixel format of
the window on success or
[SDL_PIXELFORMAT_UNKNOWN](SDL_PIXELFORMAT_UNKNOWN.html) on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
