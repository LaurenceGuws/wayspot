# SDL_ClipboardCleanupCallback

Callback function that will be called when the clipboard is cleared, or
when new data is set.

## Header File

Defined in
[\<SDL3/SDL_clipboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_clipboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_ClipboardCleanupCallback)(void *userdata);
```

</div>

## Function Parameters

|              |                                      |
|--------------|--------------------------------------|
| **userdata** | a pointer to the provided user data. |

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetClipboardData](SDL_SetClipboardData.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryClipboard](CategoryClipboard.html)
