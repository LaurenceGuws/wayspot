# SDL_GetDayOfYear

Get the day of year for a calendar date.

## Header File

Defined in
[\<SDL3/SDL_time.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_time.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetDayOfYear(int year, int month, int day);
```

</div>

## Function Parameters

|     |           |                                  |
|-----|-----------|----------------------------------|
| int | **year**  | the year component of the date.  |
| int | **month** | the month component of the date. |
| int | **day**   | the day component of the date.   |

## Return Value

(int) Returns the day of year \[0-365\] if the date is valid or -1 on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTime](CategoryTime.html)
