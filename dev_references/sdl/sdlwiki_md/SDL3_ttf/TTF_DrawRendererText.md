###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_DrawRendererText

Draw text to an SDL renderer.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool TTF_DrawRendererText(TTF_Text *text, float x, float y);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Text](TTF_Text.html) \* | **text** | the text to draw. |
| float | **x** | the x coordinate in pixels, positive from the left edge towards the right. |
| float | **y** | the y coordinate in pixels, positive from the top edge towards the bottom. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

`text` must have been created using a
[TTF_TextEngine](TTF_TextEngine.html) from
[TTF_CreateRendererTextEngine](TTF_CreateRendererTextEngine.html)(), and
will draw using the renderer passed to that function.

## Thread Safety

This function should be called on the thread that created the text.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_CreateRendererTextEngine](TTF_CreateRendererTextEngine.html)
- [TTF_CreateText](TTF_CreateText.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
