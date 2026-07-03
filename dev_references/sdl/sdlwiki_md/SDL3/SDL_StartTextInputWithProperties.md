# SDL_StartTextInputWithProperties

Start accepting Unicode text input events in a window, with properties
describing the input.

## Header File

Defined in
[\<SDL3/SDL_keyboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_keyboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_StartTextInputWithProperties(SDL_Window *window, SDL_PropertiesID props);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to enable text input. |
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to use. |

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

These are the supported properties:

- [`SDL_PROP_TEXTINPUT_TYPE_NUMBER`](SDL_PROP_TEXTINPUT_TYPE_NUMBER.html) -
  an [SDL_TextInputType](SDL_TextInputType.html) value that describes
  text being input, defaults to
  [SDL_TEXTINPUT_TYPE_TEXT](SDL_TEXTINPUT_TYPE_TEXT.html).
- [`SDL_PROP_TEXTINPUT_CAPITALIZATION_NUMBER`](SDL_PROP_TEXTINPUT_CAPITALIZATION_NUMBER.html)
  - an [SDL_Capitalization](SDL_Capitalization.html) value that
    describes how text should be capitalized, defaults to
    [SDL_CAPITALIZE_SENTENCES](SDL_CAPITALIZE_SENTENCES.html) for normal
    text entry, [SDL_CAPITALIZE_WORDS](SDL_CAPITALIZE_WORDS.html) for
    [SDL_TEXTINPUT_TYPE_TEXT_NAME](SDL_TEXTINPUT_TYPE_TEXT_NAME.html),
    and [SDL_CAPITALIZE_NONE](SDL_CAPITALIZE_NONE.html) for e-mail
    addresses, usernames, and passwords.
- [`SDL_PROP_TEXTINPUT_AUTOCORRECT_BOOLEAN`](SDL_PROP_TEXTINPUT_AUTOCORRECT_BOOLEAN.html)
  - true to enable auto completion and auto correction, defaults to
    true.
- [`SDL_PROP_TEXTINPUT_MULTILINE_BOOLEAN`](SDL_PROP_TEXTINPUT_MULTILINE_BOOLEAN.html)
  - true if multiple lines of text are allowed. This defaults to true if
    [SDL_HINT_RETURN_KEY_HIDES_IME](SDL_HINT_RETURN_KEY_HIDES_IME.html)
    is "0" or is not set, and defaults to false if
    [SDL_HINT_RETURN_KEY_HIDES_IME](SDL_HINT_RETURN_KEY_HIDES_IME.html)
    is "1".

On Android you can directly specify the input type:

- [`SDL_PROP_TEXTINPUT_ANDROID_INPUTTYPE_NUMBER`](SDL_PROP_TEXTINPUT_ANDROID_INPUTTYPE_NUMBER.html)
  - the text input type to use, overriding other properties. This is
    documented at
    <https://developer.android.com/reference/android/text/InputType>

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetTextInputArea](SDL_SetTextInputArea.html)
- [SDL_StartTextInput](SDL_StartTextInput.html)
- [SDL_StopTextInput](SDL_StopTextInput.html)
- [SDL_TextInputActive](SDL_TextInputActive.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryKeyboard](CategoryKeyboard.html)
