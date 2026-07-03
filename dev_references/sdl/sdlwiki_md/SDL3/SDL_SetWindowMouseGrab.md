# SDL_SetWindowMouseGrab

Set a window's mouse grab mode.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetWindowMouseGrab(SDL_Window *window, bool grabbed);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window for which the mouse grab mode should be set. |
| bool | **grabbed** | this is true to grab mouse, and false to release. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Mouse grab confines the mouse cursor to the window.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowMouseRect](SDL_GetWindowMouseRect.html)
- [SDL_SetWindowMouseRect](SDL_SetWindowMouseRect.html)
- [SDL_SetWindowKeyboardGrab](SDL_SetWindowKeyboardGrab.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html),
[CategoryMouse](CategoryMouse.html),
