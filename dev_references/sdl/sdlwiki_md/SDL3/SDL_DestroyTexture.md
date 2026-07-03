# SDL_DestroyTexture

Destroy the specified texture.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyTexture(SDL_Texture *texture);
```

</div>

## Function Parameters

|                                    |             |                         |
|------------------------------------|-------------|-------------------------|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to destroy. |

## Remarks

Passing NULL or an otherwise invalid texture will set the SDL error
message to "Invalid texture".

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateTexture](SDL_CreateTexture.html)
- [SDL_CreateTextureFromSurface](SDL_CreateTextureFromSurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
