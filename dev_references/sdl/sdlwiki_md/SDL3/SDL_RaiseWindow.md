# SDL_RaiseWindow

Request that a window be raised above other windows and gain the input
focus.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RaiseWindow(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to raise. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The result of this request is subject to desktop window manager policy,
particularly if raising the requested window would result in stealing
focus from another application. If the window is successfully raised and
gains input focus, an
[SDL_EVENT_WINDOW_FOCUS_GAINED](SDL_EVENT_WINDOW_FOCUS_GAINED.html)
event will be emitted, and the window will have the
[SDL_WINDOW_INPUT_FOCUS](SDL_WINDOW_INPUT_FOCUS.html) flag set.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
