# SDL_GetDisplayName

Get the name of a display in UTF-8 encoding.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetDisplayName(SDL_DisplayID displayID);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_DisplayID](SDL_DisplayID.html) | **displayID** | the instance ID of the display to query. |

## Return Value

(const char \*) Returns the name of a display or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
// Example program
// Use SDL3 to log the name of every display found

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

  for(int i = 0; i < num_displays; i++) {
    SDL_Log("Found display named '%s'", SDL_GetDisplayName(displays[i]));
  }

  SDL_free(displays);

  return 0;
}
```

</div>

## See Also

- [SDL_GetDisplays](SDL_GetDisplays.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
