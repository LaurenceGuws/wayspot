# SDL_GetPrimaryDisplay

Return the primary display.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_DisplayID SDL_GetPrimaryDisplay(void);
```

</div>

## Return Value

([SDL_DisplayID](SDL_DisplayID.html)) Returns the instance ID of the
primary display on success or 0 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetDisplays](SDL_GetDisplays.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
