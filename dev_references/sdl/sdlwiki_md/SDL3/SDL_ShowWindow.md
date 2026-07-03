# SDL_ShowWindow

Show a window.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ShowWindow(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                     |
|----------------------------------|------------|---------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to show. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HideWindow](SDL_HideWindow.html)
- [SDL_RaiseWindow](SDL_RaiseWindow.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
