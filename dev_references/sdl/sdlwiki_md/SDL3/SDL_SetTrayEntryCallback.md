# SDL_SetTrayEntryCallback

Sets a callback to be invoked when the entry is selected.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetTrayEntryCallback(SDL_TrayEntry *entry, SDL_TrayCallback callback, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TrayEntry](SDL_TrayEntry.html) \* | **entry** | the entry to be updated. |
| [SDL_TrayCallback](SDL_TrayCallback.html) | **callback** | a callback to be invoked when the entry is selected. |
| void \* | **userdata** | an optional pointer to pass extra data to the callback when it will be invoked. |

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
