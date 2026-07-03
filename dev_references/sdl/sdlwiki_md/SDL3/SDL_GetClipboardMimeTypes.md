# SDL_GetClipboardMimeTypes

Retrieve the list of mime types available in the clipboard.

## Header File

Defined in
[\<SDL3/SDL_clipboard.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_clipboard.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
char ** SDL_GetClipboardMimeTypes(size_t *num_mime_types);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| size_t \* | **num_mime_types** | a pointer filled with the number of mime types, may be NULL. |

## Return Value

(char \*\*) Returns a null-terminated array of strings with mime types,
or NULL on failure; call [SDL_GetError](SDL_GetError.html)() for more
information. This should be freed with [SDL_free](SDL_free.html)() when
it is no longer needed.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetClipboardData](SDL_SetClipboardData.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryClipboard](CategoryClipboard.html)
