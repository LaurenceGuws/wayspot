# SDL_SetTrayEntryEnabled

Sets whether or not an entry is enabled.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetTrayEntryEnabled(SDL_TrayEntry *entry, bool enabled);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TrayEntry](SDL_TrayEntry.html) \* | **entry** | the entry to be updated. |
| bool | **enabled** | true if the entry should be enabled; false otherwise. |

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTrayEntries](SDL_GetTrayEntries.html)
- [SDL_InsertTrayEntryAt](SDL_InsertTrayEntryAt.html)
- [SDL_GetTrayEntryEnabled](SDL_GetTrayEntryEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
