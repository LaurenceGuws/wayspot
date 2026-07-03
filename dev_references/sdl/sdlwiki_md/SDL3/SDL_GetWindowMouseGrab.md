# SDL_GetWindowMouseGrab

Get a window's mouse grab mode.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetWindowMouseGrab(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |

## Return Value

(bool) Returns true if mouse is grabbed, and false otherwise.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowMouseRect](SDL_GetWindowMouseRect.html)
- [SDL_SetWindowMouseRect](SDL_SetWindowMouseRect.html)
- [SDL_SetWindowMouseGrab](SDL_SetWindowMouseGrab.html)
- [SDL_SetWindowKeyboardGrab](SDL_SetWindowKeyboardGrab.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html),
[CategoryMouse](CategoryMouse.html),
