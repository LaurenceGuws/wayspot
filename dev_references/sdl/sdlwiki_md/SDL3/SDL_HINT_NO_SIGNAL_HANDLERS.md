# SDL_HINT_NO_SIGNAL_HANDLERS

Tell SDL not to catch the SIGINT or SIGTERM signals on POSIX platforms.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_NO_SIGNAL_HANDLERS "SDL_NO_SIGNAL_HANDLERS"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": SDL will install a SIGINT and SIGTERM handler, and when it
  catches a signal, convert it into an
  [SDL_EVENT_QUIT](SDL_EVENT_QUIT.html) event. (default)
- "1": SDL will not install a signal handler at all.

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
