###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_RemoveFallbackFont

Remove a fallback font.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void TTF_RemoveFallbackFont(TTF_Font *font, TTF_Font *fallback);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Font](TTF_Font.html) \* | **font** | the font to modify. |
| [TTF_Font](TTF_Font.html) \* | **fallback** | the font to remove as a fallback. |

## Remarks

This updates any [TTF_Text](TTF_Text.html) objects using this font.

## Thread Safety

This function should be called on the thread that created both fonts.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_AddFallbackFont](TTF_AddFallbackFont.html)
- [TTF_ClearFallbackFonts](TTF_ClearFallbackFonts.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
