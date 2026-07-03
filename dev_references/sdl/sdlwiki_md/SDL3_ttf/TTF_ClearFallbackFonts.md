###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_ClearFallbackFonts

Remove all fallback fonts.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void TTF_ClearFallbackFonts(TTF_Font *font);
```

</div>

## Function Parameters

|                              |          |                     |
|------------------------------|----------|---------------------|
| [TTF_Font](TTF_Font.html) \* | **font** | the font to modify. |

## Remarks

This updates any [TTF_Text](TTF_Text.html) objects using this font.

## Thread Safety

This function should be called on the thread that created the font.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_AddFallbackFont](TTF_AddFallbackFont.html)
- [TTF_RemoveFallbackFont](TTF_RemoveFallbackFont.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
