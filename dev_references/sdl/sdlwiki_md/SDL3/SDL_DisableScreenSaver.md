# SDL_DisableScreenSaver

Prevent the screen from being blanked by a screen saver.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_DisableScreenSaver(void);
```

</div>

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

If you disable the screensaver, it is automatically re-enabled when SDL
quits.

The screensaver is disabled by default, but this may by changed by
[SDL_HINT_VIDEO_ALLOW_SCREENSAVER](SDL_HINT_VIDEO_ALLOW_SCREENSAVER.html).

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_EnableScreenSaver](SDL_EnableScreenSaver.html)
- [SDL_ScreenSaverEnabled](SDL_ScreenSaverEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
