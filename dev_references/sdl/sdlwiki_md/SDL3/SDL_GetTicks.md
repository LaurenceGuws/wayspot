# SDL_GetTicks

Get the number of milliseconds that have elapsed since the SDL library
initialization.

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint64 SDL_GetTicks(void);
```

</div>

## Return Value

([Uint64](Uint64.html)) Returns an unsigned 64‑bit integer that
represents the number of milliseconds that have elapsed since the SDL
library was initialized (typically via a call to
[SDL_Init](SDL_Init.html)).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
int variable;
bool quit = false;
unsigned int lastTime = 0, currentTime;
while (!quit) {
  // do stuff
  // ...

  // Print a report once per second
  currentTime = SDL_GetTicks();
  if (currentTime > lastTime + 1000) {
    printf("Report: %d\n", variable);
    lastTime = currentTime;
  }
}
```

</div>

## See Also

- [SDL_GetTicksNS](SDL_GetTicksNS.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTimer](CategoryTimer.html)
