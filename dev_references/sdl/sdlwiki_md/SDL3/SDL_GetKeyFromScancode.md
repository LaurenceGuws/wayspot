# SDL_GetKeyFromScancode

Get the key code corresponding to the given scancode according to the
current keyboard layout.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Keycode SDL_GetKeyFromScancode(SDL_Scancode scancode, SDL_Keymod modstate, bool key_event);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Scancode](SDL_Scancode.html) | **scancode** | the desired [SDL_Scancode](SDL_Scancode.html) to query. |
| [SDL_Keymod](SDL_Keymod.html) | **modstate** | the modifier state to use when translating the scancode to a keycode. |
| bool | **key_event** | true if the keycode will be used in key events. |

## Return Value

([SDL_Keycode](SDL_Keycode.html)) Returns the
[SDL_Keycode](SDL_Keycode.html) that corresponds to the given
[SDL_Scancode](SDL_Scancode.html).

## Remarks

If you want to get the keycode as it would be delivered in key events,
including options specified in
[SDL_HINT_KEYCODE_OPTIONS](SDL_HINT_KEYCODE_OPTIONS.html), then you
should pass `key_event` as true. Otherwise this function simply
translates the scancode based on the given modifier state.

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetKeyName](SDL_GetKeyName.html)
- [SDL_GetScancodeFromKey](SDL_GetScancodeFromKey.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
