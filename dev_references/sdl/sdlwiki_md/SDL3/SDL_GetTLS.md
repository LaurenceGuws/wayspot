# SDL_GetTLS

Get the current thread's value associated with a thread local storage
ID.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void * SDL_GetTLS(SDL_TLSID *id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TLSID](SDL_TLSID.html) \* | **id** | a pointer to the thread local storage ID, may not be NULL. |

## Return Value

(void \*) Returns the value associated with the ID for the current
thread or NULL if no value has been set; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetTLS](SDL_SetTLS.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryThread](CategoryThread.html)
