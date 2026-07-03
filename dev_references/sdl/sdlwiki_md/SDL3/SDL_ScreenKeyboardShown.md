# SDL_ScreenKeyboardShown

Check whether the screen keyboard is shown for given window.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ScreenKeyboardShown(SDL_Window *window);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window for which screen keyboard should be queried. |

## Return Value

(bool) Returns true if screen keyboard is shown or false if not.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasScreenKeyboardSupport](SDL_HasScreenKeyboardSupport.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
