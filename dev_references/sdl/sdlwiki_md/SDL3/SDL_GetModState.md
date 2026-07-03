# SDL_GetModState

Get the current key modifier state for the keyboard.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Keymod SDL_GetModState(void);
```

</div>

## Return Value

([SDL_Keymod](SDL_Keymod.html)) Returns an OR'd combination of the
modifier keys for the keyboard.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetKeyboardState](SDL_GetKeyboardState.html)
- [SDL_SetModState](SDL_SetModState.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
