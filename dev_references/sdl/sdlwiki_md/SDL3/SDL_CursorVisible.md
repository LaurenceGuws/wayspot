# SDL_CursorVisible

Return whether the cursor is currently being shown.

## Header File

Defined in
[\<SDL3/SDL_mouse.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mouse.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CursorVisible(void);
```

</div>

## Return Value

(bool) Returns `true` if the cursor is being shown, or `false` if the
cursor is hidden.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HideCursor](SDL_HideCursor.html)
- [SDL_ShowCursor](SDL_ShowCursor.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMouse](CategoryMouse.html)
