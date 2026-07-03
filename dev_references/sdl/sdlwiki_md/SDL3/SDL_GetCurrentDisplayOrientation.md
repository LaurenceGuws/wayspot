# SDL_GetCurrentDisplayOrientation

Get the orientation of a display.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_DisplayOrientation SDL_GetCurrentDisplayOrientation(SDL_DisplayID displayID);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_DisplayID](SDL_DisplayID.html) | **displayID** | the instance ID of the display to query. |

## Return Value

([SDL_DisplayOrientation](SDL_DisplayOrientation.html)) Returns the
[SDL_DisplayOrientation](SDL_DisplayOrientation.html) enum value of the
display, or [`SDL_ORIENTATION_UNKNOWN`](SDL_ORIENTATION_UNKNOWN.html) if
it isn't available.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetDisplays](SDL_GetDisplays.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
