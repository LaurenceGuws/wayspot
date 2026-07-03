# SDL_GetGrabbedWindow

Get the window that currently has an input grab enabled.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Window * SDL_GetGrabbedWindow(void);
```

</div>

## Return Value

([SDL_Window](SDL_Window.html) \*) Returns the window if input is
grabbed or NULL otherwise.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetWindowMouseGrab](SDL_SetWindowMouseGrab.html)
- [SDL_SetWindowKeyboardGrab](SDL_SetWindowKeyboardGrab.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
