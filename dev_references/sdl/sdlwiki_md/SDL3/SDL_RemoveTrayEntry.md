# SDL_RemoveTrayEntry

Removes a tray entry.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_RemoveTrayEntry(SDL_TrayEntry *entry);
```

</div>

## Function Parameters

|                                        |           |                          |
|----------------------------------------|-----------|--------------------------|
| [SDL_TrayEntry](SDL_TrayEntry.html) \* | **entry** | The entry to be deleted. |

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTrayEntries](SDL_GetTrayEntries.html)
- [SDL_InsertTrayEntryAt](SDL_InsertTrayEntryAt.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
