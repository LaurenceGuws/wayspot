# SDL_SetScancodeName

Set a human-readable name for a scancode.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetScancodeName(SDL_Scancode scancode, const char *name);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Scancode](SDL_Scancode.html) | **scancode** | the desired [SDL_Scancode](SDL_Scancode.html). |
| const char \* | **name** | the name to use for the scancode, encoded as UTF-8. The string is not copied, so the pointer given to this function must stay valid while SDL is being used. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetScancodeName](SDL_GetScancodeName.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
