###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_CopyFont

Create a copy of an existing font.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_Font * TTF_CopyFont(TTF_Font *existing_font);
```

</div>

## Function Parameters

|                              |                   |                   |
|------------------------------|-------------------|-------------------|
| [TTF_Font](TTF_Font.html) \* | **existing_font** | the font to copy. |

## Return Value

([TTF_Font](TTF_Font.html) \*) Returns a valid
[TTF_Font](TTF_Font.html), or NULL on failure; call SDL_GetError() for
more information.

## Remarks

The copy will be distinct from the original, but will share the font
file and have the same size and style as the original.

When done with the returned [TTF_Font](TTF_Font.html), use
[TTF_CloseFont](TTF_CloseFont.html)() to dispose of it.

## Thread Safety

This function should be called on the thread that created the original
font.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_CloseFont](TTF_CloseFont.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
