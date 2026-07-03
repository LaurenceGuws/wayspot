# SDL_Vertex

Vertex structure.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_Vertex
{
    SDL_FPoint position;        /**< Vertex position, in SDL_Renderer coordinates  */
    SDL_FColor color;           /**< Vertex color */
    SDL_FPoint tex_coord;       /**< Normalized texture coordinates, if needed */
} SDL_Vertex;
```

</div>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryRender](CategoryRender.html)
