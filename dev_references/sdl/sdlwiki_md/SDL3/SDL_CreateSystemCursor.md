# SDL_CreateSystemCursor

Create a system cursor.

## Header File

Defined in
[\<SDL3/SDL_mouse.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mouse.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Cursor * SDL_CreateSystemCursor(SDL_SystemCursor id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_SystemCursor](SDL_SystemCursor.html) | **id** | an [SDL_SystemCursor](SDL_SystemCursor.html) enum value. |

## Return Value

([SDL_Cursor](SDL_Cursor.html) \*) Returns a cursor on success or NULL
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_Cursor* cursor;
cursor = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_POINTER);
SDL_SetCursor(cursor);
```

</div>

## See Also

- [SDL_DestroyCursor](SDL_DestroyCursor.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMouse](CategoryMouse.html)
