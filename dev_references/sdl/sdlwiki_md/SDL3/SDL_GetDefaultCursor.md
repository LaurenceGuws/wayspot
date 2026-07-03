# SDL_GetDefaultCursor

Get the default cursor.

## Header File

Defined in
[\<SDL3/SDL_mouse.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mouse.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Cursor * SDL_GetDefaultCursor(void);
```

</div>

## Return Value

([SDL_Cursor](SDL_Cursor.html) \*) Returns the default cursor on success
or NULL on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

You do not have to call [SDL_DestroyCursor](SDL_DestroyCursor.html)() on
the return value, but it is safe to do so.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMouse](CategoryMouse.html)
