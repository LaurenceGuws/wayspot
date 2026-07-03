# SDL_CreateWindowAndRenderer

Create a window and default renderer.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CreateWindowAndRenderer(const char *title, int width, int height, SDL_WindowFlags window_flags, SDL_Window **window, SDL_Renderer **renderer);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **title** | the title of the window, in UTF-8 encoding. |
| int | **width** | the width of the window. |
| int | **height** | the height of the window. |
| [SDL_WindowFlags](SDL_WindowFlags.html) | **window_flags** | the flags used to create the window (see [SDL_CreateWindow](SDL_CreateWindow.html)()). |
| [SDL_Window](SDL_Window.html) \*\* | **window** | a pointer filled with the window, or NULL on error. |
| [SDL_Renderer](SDL_Renderer.html) \*\* | **renderer** | a pointer filled with the renderer, or NULL on error. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

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
    SDL_Window *window;
    SDL_Renderer *renderer;
    SDL_Surface *surface;
    SDL_Texture *texture;
    SDL_Event event;

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't initialize SDL: %s", SDL_GetError());
        return 3;
    }

    if (!SDL_CreateWindowAndRenderer("Hello SDL", 320, 240, SDL_WINDOW_RESIZABLE, &window, &renderer)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't create window and renderer: %s", SDL_GetError());
        return 3;
    }

    surface = SDL_LoadBMP("sample.bmp");
    if (!surface) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't create surface from image: %s", SDL_GetError());
        return 3;
    }
    texture = SDL_CreateTextureFromSurface(renderer, surface);
    if (!texture) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't create texture from surface: %s", SDL_GetError());
        return 3;
    }
    SDL_DestroySurface(surface);

    while (1) {
        SDL_PollEvent(&event);
        if (event.type == SDL_EVENT_QUIT) {
            break;
        }
        SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0x00);
        SDL_RenderClear(renderer);
        SDL_RenderTexture(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);

    SDL_Quit();

    return 0;
}
```

</div>

## See Also

- [SDL_CreateRenderer](SDL_CreateRenderer.html)
- [SDL_CreateWindow](SDL_CreateWindow.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
