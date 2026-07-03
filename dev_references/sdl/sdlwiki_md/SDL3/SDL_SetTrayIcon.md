# SDL_SetTrayIcon

Updates the system tray icon's icon.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetTrayIcon(SDL_Tray *tray, SDL_Surface *icon);
```

</div>

## Function Parameters

|                                    |          |                              |
|------------------------------------|----------|------------------------------|
| [SDL_Tray](SDL_Tray.html) \*       | **tray** | the tray icon to be updated. |
| [SDL_Surface](SDL_Surface.html) \* | **icon** | the new icon. May be NULL.   |

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateTray](SDL_CreateTray.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
