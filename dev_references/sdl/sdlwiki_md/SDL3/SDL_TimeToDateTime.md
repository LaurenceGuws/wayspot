# SDL_TimeToDateTime

Converts an [SDL_Time](SDL_Time.html) in nanoseconds since the epoch to
a calendar time in the [SDL_DateTime](SDL_DateTime.html) format.

## Header File

Defined in
[\<SDL3/SDL_time.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_time.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_TimeToDateTime(SDL_Time ticks, SDL_DateTime *dt, bool localTime);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Time](SDL_Time.html) | **ticks** | the [SDL_Time](SDL_Time.html) to be converted. |
| [SDL_DateTime](SDL_DateTime.html) \* | **dt** | the resulting [SDL_DateTime](SDL_DateTime.html). |
| bool | **localTime** | the resulting [SDL_DateTime](SDL_DateTime.html) will be expressed in local time if true, otherwise it will be in Universal Coordinated Time (UTC). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTime](CategoryTime.html)
