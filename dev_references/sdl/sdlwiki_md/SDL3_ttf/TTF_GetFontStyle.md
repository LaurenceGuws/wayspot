###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetFontStyle

Query a font's current style.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_FontStyleFlags TTF_GetFontStyle(const TTF_Font *font);
```

</div>

## Function Parameters

|                                    |          |                    |
|------------------------------------|----------|--------------------|
| const [TTF_Font](TTF_Font.html) \* | **font** | the font to query. |

## Return Value

([TTF_FontStyleFlags](TTF_FontStyleFlags.html)) Returns the current font
style, as a set of bit flags.

## Remarks

The font styles are a set of bit flags, OR'd together:

- [`TTF_STYLE_NORMAL`](TTF_STYLE_NORMAL.html) (is zero)
- [`TTF_STYLE_BOLD`](TTF_STYLE_BOLD.html)
- [`TTF_STYLE_ITALIC`](TTF_STYLE_ITALIC.html)
- [`TTF_STYLE_UNDERLINE`](TTF_STYLE_UNDERLINE.html)
- [`TTF_STYLE_STRIKETHROUGH`](TTF_STYLE_STRIKETHROUGH.html)

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_SetFontStyle](TTF_SetFontStyle.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
