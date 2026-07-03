# SDL_GetWindowProgressValue

Get the value of the progress bar for the given window’s taskbar icon.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_GetWindowProgressValue(SDL_Window *window);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to get the current progress value from. |

## Return Value

(float) Returns the progress value in the range of \[0.0f - 1.0f\], or
-1.0f on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
