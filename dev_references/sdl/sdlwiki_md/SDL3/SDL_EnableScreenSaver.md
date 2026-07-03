# SDL_EnableScreenSaver

Allow the screen to be blanked by a screen saver.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_EnableScreenSaver(void);
```

</div>

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DisableScreenSaver](SDL_DisableScreenSaver.html)
- [SDL_ScreenSaverEnabled](SDL_ScreenSaverEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
