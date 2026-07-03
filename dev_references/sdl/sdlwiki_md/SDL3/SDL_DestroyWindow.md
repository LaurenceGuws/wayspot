# SDL_DestroyWindow

Destroy a window.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyWindow(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                        |
|----------------------------------|------------|------------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to destroy. |

## Remarks

Any child windows owned by the window will be recursively destroyed as
well.

Note that on some platforms, the visible window may not actually be
removed from the screen until the SDL event loop is pumped again, even
though the [SDL_Window](SDL_Window.html) is no longer valid after this
call.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreatePopupWindow](SDL_CreatePopupWindow.html)
- [SDL_CreateWindow](SDL_CreateWindow.html)
- [SDL_CreateWindowWithProperties](SDL_CreateWindowWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
