###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_SubString

The representation of a substring within text.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct TTF_SubString
{
    TTF_SubStringFlags flags;   /**< The flags for this substring */
    int offset;                 /**< The byte offset from the beginning of the text */
    int length;                 /**< The byte length starting at the offset */
    int line_index;             /**< The index of the line that contains this substring */
    int cluster_index;          /**< The internal cluster index, used for quickly iterating */
    SDL_Rect rect;              /**< The rectangle, relative to the top left of the text, containing the substring */
} TTF_SubString;
```

</div>

## Version

This struct is available since SDL_ttf 3.0.0.

## See Also

- [TTF_GetNextTextSubString](TTF_GetNextTextSubString.html)
- [TTF_GetPreviousTextSubString](TTF_GetPreviousTextSubString.html)
- [TTF_GetTextSubString](TTF_GetTextSubString.html)
- [TTF_GetTextSubStringForLine](TTF_GetTextSubStringForLine.html)
- [TTF_GetTextSubStringForPoint](TTF_GetTextSubStringForPoint.html)
- [TTF_GetTextSubStringsForRange](TTF_GetTextSubStringsForRange.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategorySDLTTF](CategorySDLTTF.html)
