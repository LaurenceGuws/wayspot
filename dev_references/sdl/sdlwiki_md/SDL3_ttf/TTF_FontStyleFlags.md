###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_FontStyleFlags

Font style flags for [TTF_Font](TTF_Font.html)

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef Uint32 TTF_FontStyleFlags;

#define TTF_STYLE_NORMAL        0x00 /**< No special style */
#define TTF_STYLE_BOLD          0x01 /**< Bold style */
#define TTF_STYLE_ITALIC        0x02 /**< Italic style */
#define TTF_STYLE_UNDERLINE     0x04 /**< Underlined text */
#define TTF_STYLE_STRIKETHROUGH 0x08 /**< Strikethrough text */
```

</div>

## Remarks

These are the flags which can be used to set the style of a font in
SDL_ttf. A combination of these flags can be used with functions that
set or query font style, such as
[TTF_SetFontStyle](TTF_SetFontStyle.html) or
[TTF_GetFontStyle](TTF_GetFontStyle.html).

## Version

This datatype is available since SDL_ttf 3.0.0.

## See Also

- [TTF_SetFontStyle](TTF_SetFontStyle.html)
- [TTF_GetFontStyle](TTF_GetFontStyle.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySDLTTF](CategorySDLTTF.html)
