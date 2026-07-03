###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetFontOutline

Query a font's current outline.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int TTF_GetFontOutline(const TTF_Font *font);
```

</div>

## Function Parameters

|                                    |          |                    |
|------------------------------------|----------|--------------------|
| const [TTF_Font](TTF_Font.html) \* | **font** | the font to query. |

## Return Value

(int) Returns the font's current outline value.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_SetFontOutline](TTF_SetFontOutline.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
