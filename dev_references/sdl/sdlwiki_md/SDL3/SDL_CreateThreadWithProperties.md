# SDL_CreateThreadWithProperties

Create a new thread with with the specified properties.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Thread * SDL_CreateThreadWithProperties(SDL_PropertiesID props);
```

</div>

## Function Parameters

|                                           |           |                        |
|-------------------------------------------|-----------|------------------------|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to use. |

## Return Value

([SDL_Thread](SDL_Thread.html) \*) Returns an opaque pointer to the new
thread object on success, NULL if the new thread could not be created;
call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

These are the supported properties:

- [`SDL_PROP_THREAD_CREATE_ENTRY_FUNCTION_POINTER`](SDL_PROP_THREAD_CREATE_ENTRY_FUNCTION_POINTER.html):
  an [SDL_ThreadFunction](SDL_ThreadFunction.html) value that will be
  called at the start of the new thread's life. Required.
- [`SDL_PROP_THREAD_CREATE_NAME_STRING`](SDL_PROP_THREAD_CREATE_NAME_STRING.html):
  the name of the new thread, which might be available to debuggers.
  Optional, defaults to NULL.
- [`SDL_PROP_THREAD_CREATE_USERDATA_POINTER`](SDL_PROP_THREAD_CREATE_USERDATA_POINTER.html):
  an arbitrary app-defined pointer, which is passed to the entry
  function on the new thread, as its only parameter. Optional, defaults
  to NULL.
- [`SDL_PROP_THREAD_CREATE_STACKSIZE_NUMBER`](SDL_PROP_THREAD_CREATE_STACKSIZE_NUMBER.html):
  the size, in bytes, of the new thread's stack. Optional, defaults to 0
  (system-defined default).

SDL makes an attempt to report
[`SDL_PROP_THREAD_CREATE_NAME_STRING`](SDL_PROP_THREAD_CREATE_NAME_STRING.html)
to the system, so that debuggers can display it. Not all platforms
support this.

Thread naming is a little complicated: Most systems have very small
limits for the string length (Haiku has 32 bytes, Linux currently has
16, Visual C++ 6.0 has *nine*!), and possibly other arbitrary rules.
You'll have to see what happens with your system's debugger. The name
should be UTF-8 (but using the naming limits of C identifiers is a
better bet). There are no requirements for thread naming conventions, so
long as the string is null-terminated UTF-8, but these guidelines are
helpful in choosing a name:

<https://stackoverflow.com/questions/149932/naming-conventions-for-threads>

If a system imposes requirements, SDL will try to munge the string for
it (truncate, etc), but the original string contents will be available
from [SDL_GetThreadName](SDL_GetThreadName.html)().

The size (in bytes) of the new stack can be specified with
[`SDL_PROP_THREAD_CREATE_STACKSIZE_NUMBER`](SDL_PROP_THREAD_CREATE_STACKSIZE_NUMBER.html).
Zero means "use the system default" which might be wildly different
between platforms. x86 Linux generally defaults to eight megabytes, an
embedded device might be a few kilobytes instead. You generally need to
specify a stack that is a multiple of the system's page size (in many
cases, this is 4 kilobytes, but check your system documentation).

Note that this "function" is actually a macro that calls an internal
function with two extra parameters not listed here; they are hidden
through preprocessor macros and are needed to support various C runtimes
at the point of the function call. Language bindings that aren't using
the C headers will need to deal with this.

The actual symbol in SDL is
[`SDL_CreateThreadWithPropertiesRuntime`](SDL_CreateThreadWithPropertiesRuntime.html),
so there is no symbol clash, but trying to load an SDL shared library
and look for
"[SDL_CreateThreadWithProperties](SDL_CreateThreadWithProperties.html)"
will fail.

Usually, apps should just call this function the same way on every
platform and let the macros hide the details.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateThread](SDL_CreateThread.html)
- [SDL_WaitThread](SDL_WaitThread.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryThread](CategoryThread.html)
