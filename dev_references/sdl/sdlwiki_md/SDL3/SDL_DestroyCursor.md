# SDL_DestroyCursor

Free a previously-created cursor.

## Header File

Defined in
[\<SDL3/SDL_mouse.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mouse.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyCursor(SDL_Cursor *cursor);
```

</div>

## Function Parameters

|                                  |            |                     |
|----------------------------------|------------|---------------------|
| [SDL_Cursor](SDL_Cursor.html) \* | **cursor** | the cursor to free. |

## Remarks

Use this function to free cursor resources created with
[SDL_CreateCursor](SDL_CreateCursor.html)(),
[SDL_CreateColorCursor](SDL_CreateColorCursor.html)() or
[SDL_CreateSystemCursor](SDL_CreateSystemCursor.html)().

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateAnimatedCursor](SDL_CreateAnimatedCursor.html)
- [SDL_CreateColorCursor](SDL_CreateColorCursor.html)
- [SDL_CreateCursor](SDL_CreateCursor.html)
- [SDL_CreateSystemCursor](SDL_CreateSystemCursor.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMouse](CategoryMouse.html)
