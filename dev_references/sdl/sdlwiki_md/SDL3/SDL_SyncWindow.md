# SDL_SyncWindow

Block until any pending window state is finalized.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SyncWindow(SDL_Window *window);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window for which to wait for the pending state to be applied. |

## Return Value

(bool) Returns true on success or false if the operation timed out
before the window was in the requested state.

## Remarks

On asynchronous windowing systems, this acts as a synchronization
barrier for pending window state. It will attempt to wait until any
pending window state has been applied and is guaranteed to return within
finite time. Note that for how long it can potentially block depends on
the underlying window system, as window state changes may involve
somewhat lengthy animations that must complete before the window is in
its final requested state.

On windowing systems where changes are immediate, this does nothing.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetWindowSize](SDL_SetWindowSize.html)
- [SDL_SetWindowPosition](SDL_SetWindowPosition.html)
- [SDL_SetWindowFullscreen](SDL_SetWindowFullscreen.html)
- [SDL_MinimizeWindow](SDL_MinimizeWindow.html)
- [SDL_MaximizeWindow](SDL_MaximizeWindow.html)
- [SDL_RestoreWindow](SDL_RestoreWindow.html)
- [SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS](SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
