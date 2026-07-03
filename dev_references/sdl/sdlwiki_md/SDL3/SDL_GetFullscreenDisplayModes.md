# SDL_GetFullscreenDisplayModes

Get a list of fullscreen display modes available on a display.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_DisplayMode ** SDL_GetFullscreenDisplayModes(SDL_DisplayID displayID, int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_DisplayID](SDL_DisplayID.html) | **displayID** | the instance ID of the display to query. |
| int \* | **count** | a pointer filled in with the number of display modes returned, may be NULL. |

## Return Value

([SDL_DisplayMode](SDL_DisplayMode.html) \*\*) Returns a NULL terminated
array of display mode pointers or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This is a
single allocation that should be freed with [SDL_free](SDL_free.html)()
when it is no longer needed.

## Remarks

The display modes are sorted in this priority:

- w -\> largest to smallest
- h -\> largest to smallest
- bits per pixel -\> more colors to fewer colors
- packed pixel layout -\> largest to smallest
- refresh rate -\> highest to lowest
- pixel density -\> lowest to highest

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
