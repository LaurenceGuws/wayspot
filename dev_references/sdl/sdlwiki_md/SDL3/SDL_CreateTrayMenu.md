# SDL_CreateTrayMenu

Create a menu for a system tray.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_TrayMenu * SDL_CreateTrayMenu(SDL_Tray *tray);
```

</div>

## Function Parameters

|                              |          |                               |
|------------------------------|----------|-------------------------------|
| [SDL_Tray](SDL_Tray.html) \* | **tray** | the tray to bind the menu to. |

## Return Value

([SDL_TrayMenu](SDL_TrayMenu.html) \*) Returns the newly created menu.

## Remarks

This should be called at most once per tray icon.

This function does the same thing as
[SDL_CreateTraySubmenu](SDL_CreateTraySubmenu.html)(), except that it
takes a [SDL_Tray](SDL_Tray.html) instead of a
[SDL_TrayEntry](SDL_TrayEntry.html).

A menu does not need to be destroyed; it will be destroyed with the
tray.

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateTray](SDL_CreateTray.html)
- [SDL_GetTrayMenu](SDL_GetTrayMenu.html)
- [SDL_GetTrayMenuParentTray](SDL_GetTrayMenuParentTray.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
