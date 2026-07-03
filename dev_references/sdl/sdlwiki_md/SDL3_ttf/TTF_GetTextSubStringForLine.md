###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetTextSubStringForLine

Get the substring of a text object that contains the given line.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool TTF_GetTextSubStringForLine(TTF_Text *text, int line, TTF_SubString *substring);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Text](TTF_Text.html) \* | **text** | the [TTF_Text](TTF_Text.html) to query. |
| int | **line** | a zero-based line index, in the range \[0 .. text-\>num_lines-1\]. |
| [TTF_SubString](TTF_SubString.html) \* | **substring** | a pointer filled in with the substring containing the offset. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

If `line` is less than 0, this will return a zero length substring at
the beginning of the text with the
[TTF_SUBSTRING_TEXT_START](TTF_SUBSTRING_TEXT_START.html) flag set. If
`line` is greater than or equal to `text->num_lines` this will return a
zero length substring at the end of the text with the
[TTF_SUBSTRING_TEXT_END](TTF_SUBSTRING_TEXT_END.html) flag set.

## Thread Safety

This function should be called on the thread that created the text.

## Version

This function is available since SDL_ttf 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
