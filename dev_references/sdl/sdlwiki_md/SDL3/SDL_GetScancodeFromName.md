# SDL_GetScancodeFromName

Get a scancode from a human-readable name.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Scancode SDL_GetScancodeFromName(const char *name);
```

</div>

## Function Parameters

|               |          |                                   |
|---------------|----------|-----------------------------------|
| const char \* | **name** | the human-readable scancode name. |

## Return Value

([SDL_Scancode](SDL_Scancode.html)) Returns the
[SDL_Scancode](SDL_Scancode.html), or
[`SDL_SCANCODE_UNKNOWN`](SDL_SCANCODE_UNKNOWN.html) if the name wasn't
recognized; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetKeyFromName](SDL_GetKeyFromName.html)
- [SDL_GetScancodeFromKey](SDL_GetScancodeFromKey.html)
- [SDL_GetScancodeName](SDL_GetScancodeName.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
