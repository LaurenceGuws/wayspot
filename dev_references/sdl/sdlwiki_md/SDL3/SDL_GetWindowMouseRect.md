# SDL_GetWindowMouseRect

Get the mouse confinement rectangle of a window.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const SDL_Rect * SDL_GetWindowMouseRect(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |

## Return Value

(const [SDL_Rect](SDL_Rect.html) \*) Returns a pointer to the mouse
confinement rectangle of a window, or NULL if there isn't one.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetWindowMouseRect](SDL_SetWindowMouseRect.html)
- [SDL_GetWindowMouseGrab](SDL_GetWindowMouseGrab.html)
- [SDL_SetWindowMouseGrab](SDL_SetWindowMouseGrab.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html),
[CategoryMouse](CategoryMouse.html),
