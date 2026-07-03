# SDL_HasScreenKeyboardSupport

Check whether the platform has screen keyboard support.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HasScreenKeyboardSupport(void);
```

</div>

## Return Value

(bool) Returns true if the platform has some screen keyboard support or
false if not.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_StartTextInput](SDL_StartTextInput.html)
- [SDL_ScreenKeyboardShown](SDL_ScreenKeyboardShown.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
