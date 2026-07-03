###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetTextEngine

Get the text engine used by a text object.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_TextEngine * TTF_GetTextEngine(TTF_Text *text);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Text](TTF_Text.html) \* | **text** | the [TTF_Text](TTF_Text.html) to query. |

## Return Value

([TTF_TextEngine](TTF_TextEngine.html) \*) Returns the
[TTF_TextEngine](TTF_TextEngine.html) used by the text on success or
NULL on failure; call SDL_GetError() for more information.

## Thread Safety

This function should be called on the thread that created the text.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_SetTextEngine](TTF_SetTextEngine.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
