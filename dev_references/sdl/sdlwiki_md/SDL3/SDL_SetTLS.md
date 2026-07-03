# SDL_SetTLS

Set the current thread's value associated with a thread local storage
ID.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetTLS(SDL_TLSID *id, const void *value, SDL_TLSDestructorCallback destructor);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TLSID](SDL_TLSID.html) \* | **id** | a pointer to the thread local storage ID, may not be NULL. |
| const void \* | **value** | the value to associate with the ID for the current thread. |
| [SDL_TLSDestructorCallback](SDL_TLSDestructorCallback.html) | **destructor** | a function called when the thread exits, to free the value, may be NULL. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

If the thread local storage ID is not initialized (the value is 0), a
new ID will be created in a thread-safe way, so all calls using a
pointer to the same ID will refer to the same local storage.

Note that replacing a value from a previous call to this function on the
same thread does *not* call the previous value's destructor!

`destructor` can be NULL; it is assumed that `value` does not need to be
cleaned up if so.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTLS](SDL_GetTLS.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryThread](CategoryThread.html)
