# SDL_GetTrayMenuParentEntry

Gets the entry for which the menu is a submenu, if the current menu is a
submenu.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_TrayEntry * SDL_GetTrayMenuParentEntry(SDL_TrayMenu *menu);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TrayMenu](SDL_TrayMenu.html) \* | **menu** | the menu for which to get the parent entry. |

## Return Value

([SDL_TrayEntry](SDL_TrayEntry.html) \*) Returns the parent entry, or
NULL if this menu is not a submenu.

## Remarks

Either this function or
[SDL_GetTrayMenuParentTray](SDL_GetTrayMenuParentTray.html)() will
return non-NULL for any given menu.

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateTraySubmenu](SDL_CreateTraySubmenu.html)
- [SDL_GetTrayMenuParentTray](SDL_GetTrayMenuParentTray.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
