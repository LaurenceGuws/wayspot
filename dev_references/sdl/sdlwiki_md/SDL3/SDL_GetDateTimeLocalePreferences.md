# SDL_GetDateTimeLocalePreferences

Gets the current preferred date and time format for the system locale.

## Header File

Defined in
[\<SDL3/SDL_time.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_time.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetDateTimeLocalePreferences(SDL_DateFormat *dateFormat, SDL_TimeFormat *timeFormat);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_DateFormat](SDL_DateFormat.html) \* | **dateFormat** | a pointer to the [SDL_DateFormat](SDL_DateFormat.html) to hold the returned date format, may be NULL. |
| [SDL_TimeFormat](SDL_TimeFormat.html) \* | **timeFormat** | a pointer to the [SDL_TimeFormat](SDL_TimeFormat.html) to hold the returned time format, may be NULL. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This might be a "slow" call that has to query the operating system. It's
best to ask for this once and save the results. However, the preferred
formats can change, usually because the user has changed a system
preference outside of your program.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTime](CategoryTime.html)
