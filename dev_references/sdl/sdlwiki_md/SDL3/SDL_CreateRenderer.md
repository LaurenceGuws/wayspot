# SDL_CreateRenderer

Create a 2D rendering context for a window.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Renderer * SDL_CreateRenderer(SDL_Window *window, const char *name);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window where rendering is displayed. |
| const char \* | **name** | the name of the rendering driver to initialize, or NULL to let SDL choose one. |

## Return Value

([SDL_Renderer](SDL_Renderer.html) \*) Returns a valid rendering context
or NULL if there was an error; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

If you want a specific renderer, you can specify its name here. A list
of available renderers can be obtained by calling
[SDL_GetRenderDriver](SDL_GetRenderDriver.html)() multiple times, with
indices from 0 to
[SDL_GetNumRenderDrivers](SDL_GetNumRenderDrivers.html)()-1. If you
don't need a specific renderer, specify NULL and SDL will attempt to
choose the best option for you, based on what is available on the user's
system.

If `name` is a comma-separated list, SDL will try each name, in the
order listed, until one succeeds or all of them fail.

By default the rendering size matches the window size in pixels, but you
can call
[SDL_SetRenderLogicalPresentation](SDL_SetRenderLogicalPresentation.html)()
to change the content size and scaling options.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

int main(int argc, char *argv[])
{
    SDL_Window *win = NULL;
    SDL_Renderer *renderer = NULL;
    SDL_Texture *bitmapTex = NULL;
    SDL_Surface *bitmapSurface = NULL;
    int width = 320, height = 240;
    bool loopShouldStop = false;

    SDL_Init(SDL_INIT_VIDEO);

    win = SDL_CreateWindow("Hello World", width, height, 0);

    renderer = SDL_CreateRenderer(win, NULL);

    bitmapSurface = SDL_LoadBMP("img/hello.bmp");
    bitmapTex = SDL_CreateTextureFromSurface(renderer, bitmapSurface);
    SDL_DestroySurface(bitmapSurface);

    while (!loopShouldStop)
    {
        SDL_Event event;
        while (SDL_PollEvent(&event))
        {
            switch (event.type)
            {
                case SDL_EVENT_QUIT:
                    loopShouldStop = true;
                    break;
            }
        }

        SDL_RenderClear(renderer);
        SDL_RenderTexture(renderer, bitmapTex, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    SDL_DestroyTexture(bitmapTex);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(win);

    SDL_Quit();

    return 0;
}
```

</div>

## See Also

- [SDL_CreateRendererWithProperties](SDL_CreateRendererWithProperties.html)
- [SDL_CreateSoftwareRenderer](SDL_CreateSoftwareRenderer.html)
- [SDL_DestroyRenderer](SDL_DestroyRenderer.html)
- [SDL_GetNumRenderDrivers](SDL_GetNumRenderDrivers.html)
- [SDL_GetRenderDriver](SDL_GetRenderDriver.html)
- [SDL_GetRendererName](SDL_GetRendererName.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
