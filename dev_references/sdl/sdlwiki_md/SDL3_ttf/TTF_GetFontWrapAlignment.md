###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetFontWrapAlignment

Query a font's current wrap alignment option.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_HorizontalAlignment TTF_GetFontWrapAlignment(const TTF_Font *font);
```

</div>

## Function Parameters

|                                    |          |                    |
|------------------------------------|----------|--------------------|
| const [TTF_Font](TTF_Font.html) \* | **font** | the font to query. |

## Return Value

([TTF_HorizontalAlignment](TTF_HorizontalAlignment.html)) Returns the
font's current wrap alignment option.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_SetFontWrapAlignment](TTF_SetFontWrapAlignment.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
