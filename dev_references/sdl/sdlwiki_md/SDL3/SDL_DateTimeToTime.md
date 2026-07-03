# SDL_DateTimeToTime

Converts a calendar time to an [SDL_Time](SDL_Time.html) in nanoseconds
since the epoch.

## Header File

Defined in
[\<SDL3/SDL_time.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_time.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_DateTimeToTime(const SDL_DateTime *dt, SDL_Time *ticks);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_DateTime](SDL_DateTime.html) \* | **dt** | the source [SDL_DateTime](SDL_DateTime.html). |
| [SDL_Time](SDL_Time.html) \* | **ticks** | the resulting [SDL_Time](SDL_Time.html). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function ignores the day_of_week member of the
[SDL_DateTime](SDL_DateTime.html) struct, so it may remain unset.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTime](CategoryTime.html)
