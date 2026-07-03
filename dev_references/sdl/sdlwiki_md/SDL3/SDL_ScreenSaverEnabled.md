# SDL_ScreenSaverEnabled

Check whether the screensaver is currently enabled.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ScreenSaverEnabled(void);
```

</div>

## Return Value

(bool) Returns true if the screensaver is enabled, false if it is
disabled.

## Remarks

The screensaver is disabled by default.

The default can also be changed using
[`SDL_HINT_VIDEO_ALLOW_SCREENSAVER`](SDL_HINT_VIDEO_ALLOW_SCREENSAVER.html).

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DisableScreenSaver](SDL_DisableScreenSaver.html)
- [SDL_EnableScreenSaver](SDL_EnableScreenSaver.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
