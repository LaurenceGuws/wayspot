# SDL_SetCursor

Set the active cursor.

## Header File

Defined in
[\<SDL3/SDL_mouse.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mouse.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetCursor(SDL_Cursor *cursor);
```

</div>

## Function Parameters

|                                  |            |                          |
|----------------------------------|------------|--------------------------|
| [SDL_Cursor](SDL_Cursor.html) \* | **cursor** | a cursor to make active. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function sets the currently active cursor to the specified one. If
the cursor is currently visible, the change will be immediately
represented on the display. [SDL_SetCursor](SDL_SetCursor.html)(NULL)
can be used to force cursor redraw, if this is desired for any reason.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetCursor](SDL_GetCursor.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMouse](CategoryMouse.html)
