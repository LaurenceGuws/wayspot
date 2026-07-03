###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_GetTextProperties

Get the properties associated with a text object.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertiesID TTF_GetTextProperties(TTF_Text *text);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [TTF_Text](TTF_Text.html) \* | **text** | the [TTF_Text](TTF_Text.html) to query. |

## Return Value

(SDL_PropertiesID) Returns a valid property ID on success or 0 on
failure; call SDL_GetError() for more information.

## Thread Safety

This function should be called on the thread that created the text.

## Version

This function is available since SDL_ttf 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
