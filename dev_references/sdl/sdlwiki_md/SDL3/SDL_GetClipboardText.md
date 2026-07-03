# SDL_GetClipboardText

Get UTF-8 text from the clipboard.

## Header File

Defined in
[\<SDL3/SDL_clipboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_clipboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
char * SDL_GetClipboardText(void);
```

</div>

## Return Value

(char \*) Returns the clipboard text on success or an empty string on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.
This should be freed with [SDL_free](SDL_free.html)() when it is no
longer needed.

## Remarks

This function returns an empty string if there is not enough memory left
for a copy of the clipboard's content.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasClipboardText](SDL_HasClipboardText.html)
- [SDL_SetClipboardText](SDL_SetClipboardText.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryClipboard](CategoryClipboard.html)
