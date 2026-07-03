# SDL_GetCurrentDisplayMode

Get information about the current display mode.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const SDL_DisplayMode * SDL_GetCurrentDisplayMode(SDL_DisplayID displayID);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_DisplayID](SDL_DisplayID.html) | **displayID** | the instance ID of the display to query. |

## Return Value

(const [SDL_DisplayMode](SDL_DisplayMode.html) \*) Returns a pointer to
the desktop display mode or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

There's a difference between this function and
[SDL_GetDesktopDisplayMode](SDL_GetDesktopDisplayMode.html)() when SDL
runs fullscreen and has changed the resolution. In that case this
function will return the current display mode, and not the previous
native display mode.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetDesktopDisplayMode](SDL_GetDesktopDisplayMode.html)
- [SDL_GetDisplays](SDL_GetDisplays.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
