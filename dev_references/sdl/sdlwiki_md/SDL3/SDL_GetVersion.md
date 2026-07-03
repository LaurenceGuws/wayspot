# SDL_GetVersion

Get the version of SDL that is linked against your program.

## Header File

Defined in
[\<SDL3/SDL_version.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_version.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetVersion(void);
```

</div>

## Return Value

(int) Returns the version of the linked library.

## Remarks

If you are linking to SDL dynamically, then it is possible that the
current version will be different than the version you compiled against.
This function returns the current version, while
[SDL_VERSION](SDL_VERSION.html) is the version you compiled with.

This function may be called safely at any time, even before
[SDL_Init](SDL_Init.html)().

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
const int compiled = SDL_VERSION;  /* hardcoded number from SDL headers */
const int linked = SDL_GetVersion();  /* reported by linked SDL library */

SDL_Log("We compiled against SDL version %d.%d.%d ...\n",
        SDL_VERSIONNUM_MAJOR(compiled),
        SDL_VERSIONNUM_MINOR(compiled),
        SDL_VERSIONNUM_MICRO(compiled));

SDL_Log("But we are linking against SDL version %d.%d.%d.\n",
        SDL_VERSIONNUM_MAJOR(linked),
        SDL_VERSIONNUM_MINOR(linked),
        SDL_VERSIONNUM_MICRO(linked));
```

</div>

## See Also

- [SDL_GetRevision](SDL_GetRevision.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVersion](CategoryVersion.html)
