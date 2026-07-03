###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_SetFontHinting

Set a font's current hinter setting.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void TTF_SetFontHinting(TTF_Font *font, TTF_HintingFlags hinting);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Font](TTF_Font.html) \* | **font** | the font to set a new hinter setting on. |
| [TTF_HintingFlags](TTF_HintingFlags.html) | **hinting** | the new hinter setting. |

## Remarks

This updates any [TTF_Text](TTF_Text.html) objects using this font, and
clears already-generated glyphs, if any, from the cache.

The hinter setting is a single value:

- [`TTF_HINTING_NORMAL`](TTF_HINTING_NORMAL.html)
- [`TTF_HINTING_LIGHT`](TTF_HINTING_LIGHT.html)
- [`TTF_HINTING_MONO`](TTF_HINTING_MONO.html)
- [`TTF_HINTING_NONE`](TTF_HINTING_NONE.html)
- [`TTF_HINTING_LIGHT_SUBPIXEL`](TTF_HINTING_LIGHT_SUBPIXEL.html)
  (available in SDL_ttf 3.0.0 and later)

## Thread Safety

This function should be called on the thread that created the font.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_GetFontHinting](TTF_GetFontHinting.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
