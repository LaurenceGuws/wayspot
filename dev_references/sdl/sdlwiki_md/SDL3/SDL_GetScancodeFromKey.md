# SDL_GetScancodeFromKey

Get the scancode corresponding to the given key code according to the
current keyboard layout.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Scancode SDL_GetScancodeFromKey(SDL_Keycode key, SDL_Keymod *modstate);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Keycode](SDL_Keycode.html) | **key** | the desired [SDL_Keycode](SDL_Keycode.html) to query. |
| [SDL_Keymod](SDL_Keymod.html) \* | **modstate** | a pointer to the modifier state that would be used when the scancode generates this key, may be NULL. |

## Return Value

([SDL_Scancode](SDL_Scancode.html)) Returns the
[SDL_Scancode](SDL_Scancode.html) that corresponds to the given
[SDL_Keycode](SDL_Keycode.html).

## Remarks

Note that there may be multiple scancode+modifier states that can
generate this keycode, this will just return the first one found.

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetKeyFromScancode](SDL_GetKeyFromScancode.html)
- [SDL_GetScancodeName](SDL_GetScancodeName.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
