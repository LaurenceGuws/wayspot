# SDL_GetWindowTitle

Get the title of a window.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetWindowTitle(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |

## Return Value

(const char \*) Returns the title of the window in UTF-8 format or "" if
there is no title.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetWindowTitle](SDL_SetWindowTitle.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
