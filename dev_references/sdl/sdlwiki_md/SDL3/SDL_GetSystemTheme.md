# SDL_GetSystemTheme

Get the current system theme.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_SystemTheme SDL_GetSystemTheme(void);
```

</div>

## Return Value

([SDL_SystemTheme](SDL_SystemTheme.html)) Returns the current system
theme, light, dark, or unknown.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
