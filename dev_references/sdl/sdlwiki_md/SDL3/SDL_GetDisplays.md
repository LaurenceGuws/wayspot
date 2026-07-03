# SDL_GetDisplays

Get a list of currently connected displays.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_DisplayID * SDL_GetDisplays(int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int \* | **count** | a pointer filled in with the number of displays returned, may be NULL. |

## Return Value

([SDL_DisplayID](SDL_DisplayID.html) \*) Returns a 0 terminated array of
display instance IDs or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
// Example program
// Use SDL3 to check how many displays there are

#include <SDL3/SDL_log.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_video.h>

int
main(int argc, char** argv)
{
  if (!SDL_Init(SDL_INIT_VIDEO)) {
    SDL_Log("Unable to initialize SDL: %s", SDL_GetError());
    return 0;
  }

  int num_displays;
  SDL_DisplayID *displays = SDL_GetDisplays(&num_displays);
  SDL_Log("Found %d display(s)", num_displays);

  SDL_free(displays);

  return 0;
}
```

</div>

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
