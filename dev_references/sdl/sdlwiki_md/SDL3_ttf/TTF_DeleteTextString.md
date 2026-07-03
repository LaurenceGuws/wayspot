###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_DeleteTextString

Delete UTF-8 text from a text object.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool TTF_DeleteTextString(TTF_Text *text, int offset, int length);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Text](TTF_Text.html) \* | **text** | the [TTF_Text](TTF_Text.html) to modify. |
| int | **offset** | the offset, in bytes, from the beginning of the string if \>= 0, the offset from the end of the string if \< 0. Note that this does not do UTF-8 validation, so you should only delete at UTF-8 sequence boundaries. |
| int | **length** | the length of text to delete, in bytes, or -1 for the remainder of the string. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

This function may cause the internal text representation to be rebuilt.

## Thread Safety

This function should be called on the thread that created the text.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_AppendTextString](TTF_AppendTextString.html)
- [TTF_InsertTextString](TTF_InsertTextString.html)
- [TTF_SetTextString](TTF_SetTextString.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
