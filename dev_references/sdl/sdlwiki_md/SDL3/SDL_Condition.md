# SDL_Condition

A means to block multiple threads until a condition is satisfied.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_Condition SDL_Condition;
```

</div>

## Remarks

Condition variables, paired with an [SDL_Mutex](SDL_Mutex.html), let an
app halt multiple threads until a condition has occurred, at which time
the app can release one or all waiting threads.

Wikipedia has a thorough explanation of the concept:

<https://en.wikipedia.org/wiki/Condition_variable>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryMutex](CategoryMutex.html)
