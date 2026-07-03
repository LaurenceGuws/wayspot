# SDL_GetKeyFromName

Get a key code from a human-readable name.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Keycode SDL_GetKeyFromName(const char *name);
```

</div>

## Function Parameters

|               |          |                              |
|---------------|----------|------------------------------|
| const char \* | **name** | the human-readable key name. |

## Return Value

([SDL_Keycode](SDL_Keycode.html)) Returns key code, or
[`SDLK_UNKNOWN`](SDLK_UNKNOWN.html) if the name wasn't recognized; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetKeyFromScancode](SDL_GetKeyFromScancode.html)
- [SDL_GetKeyName](SDL_GetKeyName.html)
- [SDL_GetScancodeFromName](SDL_GetScancodeFromName.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
