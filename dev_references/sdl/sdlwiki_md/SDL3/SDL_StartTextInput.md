# SDL_StartTextInput

Start accepting Unicode text input events in a window.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_StartTextInput(SDL_Window *window);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to enable text input. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function will enable text input
([SDL_EVENT_TEXT_INPUT](SDL_EVENT_TEXT_INPUT.html) and
[SDL_EVENT_TEXT_EDITING](SDL_EVENT_TEXT_EDITING.html) events) in the
specified window. Please use this function paired with
[SDL_StopTextInput](SDL_StopTextInput.html)().

Text input events are not received by default.

On some platforms using this function shows the screen keyboard and/or
activates an IME, which can prevent some key press events from being
passed through.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetTextInputArea](SDL_SetTextInputArea.html)
- [SDL_StartTextInputWithProperties](SDL_StartTextInputWithProperties.html)
- [SDL_StopTextInput](SDL_StopTextInput.html)
- [SDL_TextInputActive](SDL_TextInputActive.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
