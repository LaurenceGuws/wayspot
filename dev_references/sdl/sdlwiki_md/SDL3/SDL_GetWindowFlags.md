# SDL_GetWindowFlags

Get the window flags.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_WindowFlags SDL_GetWindowFlags(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |

## Return Value

([SDL_WindowFlags](SDL_WindowFlags.html)) Returns a mask of the
[SDL_WindowFlags](SDL_WindowFlags.html) associated with `window`.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateWindow](SDL_CreateWindow.html)
- [SDL_HideWindow](SDL_HideWindow.html)
- [SDL_MaximizeWindow](SDL_MaximizeWindow.html)
- [SDL_MinimizeWindow](SDL_MinimizeWindow.html)
- [SDL_SetWindowFullscreen](SDL_SetWindowFullscreen.html)
- [SDL_SetWindowMouseGrab](SDL_SetWindowMouseGrab.html)
- [SDL_SetWindowFillDocument](SDL_SetWindowFillDocument.html)
- [SDL_ShowWindow](SDL_ShowWindow.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
