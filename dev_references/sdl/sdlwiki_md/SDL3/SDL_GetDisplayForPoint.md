# SDL_GetDisplayForPoint

Get the display containing a point.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_DisplayID SDL_GetDisplayForPoint(const SDL_Point *point);
```

</div>

## Function Parameters

|                                      |           |                     |
|--------------------------------------|-----------|---------------------|
| const [SDL_Point](SDL_Point.html) \* | **point** | the point to query. |

## Return Value

([SDL_DisplayID](SDL_DisplayID.html)) Returns the instance ID of the
display containing the point or 0 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetDisplayBounds](SDL_GetDisplayBounds.html)
- [SDL_GetDisplays](SDL_GetDisplays.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
