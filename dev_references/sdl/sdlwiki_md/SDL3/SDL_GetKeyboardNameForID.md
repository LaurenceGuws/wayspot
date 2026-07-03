# SDL_GetKeyboardNameForID

Get the name of a keyboard.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetKeyboardNameForID(SDL_KeyboardID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_KeyboardID](SDL_KeyboardID.html) | **instance_id** | the keyboard instance ID. |

## Return Value

(const char \*) Returns the name of the selected keyboard or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function returns "" if the keyboard doesn't have a name.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetKeyboards](SDL_GetKeyboards.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
