# SDL_CreateTextureFromSurface

Create a texture from an existing surface.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Texture * SDL_CreateTextureFromSurface(SDL_Renderer *renderer, SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure containing pixel data used to fill the texture. |

## Return Value

([SDL_Texture](SDL_Texture.html) \*) Returns the created texture or NULL
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

The surface is not modified or freed by this function.

The [SDL_TextureAccess](SDL_TextureAccess.html) hint for the created
texture is [`SDL_TEXTUREACCESS_STATIC`](SDL_TEXTUREACCESS_STATIC.html).

The pixel format of the created texture may be different from the pixel
format of the surface, and can be queried using the
[SDL_PROP_TEXTURE_FORMAT_NUMBER](SDL_PROP_TEXTURE_FORMAT_NUMBER.html)
property.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_Renderer *renderer;

SDL_Surface *surface = SDL_CreateSurface(640, 480, SDL_PIXELFORMAT_RGBA8888);

if (surface == NULL) {
    SDL_Log("CreateRGBSurface failed: %s", SDL_GetError());
    exit(1);
}

SDL_Texture *texture = SDL_CreateTextureFromSurface(renderer, surface);

if (texture == NULL) {
    SDL_Log("CreateTextureFromSurface failed: %s", SDL_GetError());
    exit(1);
}

SDL_DestroySurface(surface);
surface = NULL;

// Use the texture in rendering, then destroy it when you're done using it.

SDL_DestroyTexture(texture);
```

</div>

## See Also

- [SDL_CreateTexture](SDL_CreateTexture.html)
- [SDL_CreateTextureWithProperties](SDL_CreateTextureWithProperties.html)
- [SDL_DestroyTexture](SDL_DestroyTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
