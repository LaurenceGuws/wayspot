###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetFontAscent

Query the offset from the baseline to the top of a font.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int TTF_GetFontAscent(const TTF_Font *font);
```

</div>

## Function Parameters

|                                    |          |                    |
|------------------------------------|----------|--------------------|
| const [TTF_Font](TTF_Font.html) \* | **font** | the font to query. |

## Return Value

(int) Returns the font's ascent.

## Remarks

This is a positive value, relative to the baseline.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_ttf 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
