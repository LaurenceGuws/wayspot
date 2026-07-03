###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_DrawSurfaceText

Draw text to an SDL surface.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool TTF_DrawSurfaceText(TTF_Text *text, int x, int y, SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Text](TTF_Text.html) \* | **text** | the text to draw. |
| int | **x** | the x coordinate in pixels, positive from the left edge towards the right. |
| int | **y** | the y coordinate in pixels, positive from the top edge towards the bottom. |
| SDL_Surface \* | **surface** | the surface to draw on. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

`text` must have been created using a
[TTF_TextEngine](TTF_TextEngine.html) from
[TTF_CreateSurfaceTextEngine](TTF_CreateSurfaceTextEngine.html)().

## Thread Safety

This function should be called on the thread that created the text.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_CreateSurfaceTextEngine](TTF_CreateSurfaceTextEngine.html)
- [TTF_CreateText](TTF_CreateText.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
