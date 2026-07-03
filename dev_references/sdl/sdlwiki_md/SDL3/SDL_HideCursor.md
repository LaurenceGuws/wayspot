# SDL_HideCursor

Hide the cursor.

## Header File

Defined in
[\<SDL3/SDL_mouse.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mouse.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HideCursor(void);
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

- [SDL_CursorVisible](SDL_CursorVisible.html)
- [SDL_ShowCursor](SDL_ShowCursor.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMouse](CategoryMouse.html)
