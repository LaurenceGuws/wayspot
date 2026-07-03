###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetFontDirection

Get the direction to be used for text shaping by a font.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_Direction TTF_GetFontDirection(TTF_Font *font);
```

</div>

## Function Parameters

|                              |          |                    |
|------------------------------|----------|--------------------|
| [TTF_Font](TTF_Font.html) \* | **font** | the font to query. |

## Return Value

([TTF_Direction](TTF_Direction.html)) Returns the direction to be used
for text shaping.

## Remarks

This defaults to [TTF_DIRECTION_INVALID](TTF_DIRECTION_INVALID.html) if
it hasn't been set.

## Thread Safety

This function should be called on the thread that created the font.

## Version

This function is available since SDL_ttf 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
