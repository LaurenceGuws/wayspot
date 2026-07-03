###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetGlyphImage

Get the pixel image for a UNICODE codepoint.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * TTF_GetGlyphImage(TTF_Font *font, Uint32 ch, TTF_ImageType *image_type);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Font](TTF_Font.html) \* | **font** | the font to query. |
| Uint32 | **ch** | the codepoint to check. |
| [TTF_ImageType](TTF_ImageType.html) \* | **image_type** | a pointer filled in with the glyph image type, may be NULL. |

## Return Value

(SDL_Surface \*) Returns an SDL_Surface containing the glyph, or NULL on
failure; call SDL_GetError() for more information.

## Thread Safety

This function should be called on the thread that created the font.

## Version

This function is available since SDL_ttf 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
