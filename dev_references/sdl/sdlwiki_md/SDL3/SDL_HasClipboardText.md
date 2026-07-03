# SDL_HasClipboardText

Query whether the clipboard exists and contains a non-empty text string.

## Header File

Defined in
[\<SDL3/SDL_clipboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_clipboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HasClipboardText(void);
```

</div>

## Return Value

(bool) Returns true if the clipboard has text, or false if it does not.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetClipboardText](SDL_GetClipboardText.html)
- [SDL_SetClipboardText](SDL_SetClipboardText.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryClipboard](CategoryClipboard.html)
