###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_SetTextString

Set the UTF-8 text used by a text object.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool TTF_SetTextString(TTF_Text *text, const char *string, size_t length);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Text](TTF_Text.html) \* | **text** | the [TTF_Text](TTF_Text.html) to modify. |
| const char \* | **string** | the UTF-8 text to use, may be NULL. |
| size_t | **length** | the length of the text, in bytes, or 0 for null terminated text. |

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
- [TTF_DeleteTextString](TTF_DeleteTextString.html)
- [TTF_InsertTextString](TTF_InsertTextString.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
