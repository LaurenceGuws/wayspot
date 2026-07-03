###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetFontHinting

Query a font's current FreeType hinter setting.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_HintingFlags TTF_GetFontHinting(const TTF_Font *font);
```

</div>

## Function Parameters

|                                    |          |                    |
|------------------------------------|----------|--------------------|
| const [TTF_Font](TTF_Font.html) \* | **font** | the font to query. |

## Return Value

([TTF_HintingFlags](TTF_HintingFlags.html)) Returns the font's current
hinter value, or [TTF_HINTING_INVALID](TTF_HINTING_INVALID.html) if the
font is invalid.

## Remarks

The hinter setting is a single value:

- [`TTF_HINTING_NORMAL`](TTF_HINTING_NORMAL.html)
- [`TTF_HINTING_LIGHT`](TTF_HINTING_LIGHT.html)
- [`TTF_HINTING_MONO`](TTF_HINTING_MONO.html)
- [`TTF_HINTING_NONE`](TTF_HINTING_NONE.html)
- [`TTF_HINTING_LIGHT_SUBPIXEL`](TTF_HINTING_LIGHT_SUBPIXEL.html)
  (available in SDL_ttf 3.0.0 and later)

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_SetFontHinting](TTF_SetFontHinting.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
