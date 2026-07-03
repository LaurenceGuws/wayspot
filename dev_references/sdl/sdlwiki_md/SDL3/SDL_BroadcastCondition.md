# SDL_BroadcastCondition

Restart all threads that are waiting on the condition variable.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_BroadcastCondition(SDL_Condition *cond);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Condition](SDL_Condition.html) \* | **cond** | the condition variable to signal. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
// BEWARE: This code example was migrated from the SDL2 Wiki, by only updating the names.

bool condition = false;
SDL_Mutex *lock;
SDL_Condition *cond;
lock = SDL_CreateMutex();
cond = SDL_CreateCondition();

Thread_A:
    SDL_LockMutex(lock);
    while (!condition) {
        SDL_WaitCondition(cond, lock);
    }
    SDL_UnlockMutex(lock);
Thread_B:
    SDL_LockMutex(lock);
    while (!condition) {
        SDL_WaitCondition(cond, lock);
    }
    SDL_UnlockMutex(lock);
Thread_C:
    SDL_LockMutex(lock);
    /* ... */
    condition = true;
    /* ... */
    SDL_BroadcastCondition(cond);
    SDL_UnlockMutex(lock);

SDL_DestroyCondition(cond);
SDL_DestroyMutex(lock);
```

</div>

## See Also

- [SDL_SignalCondition](SDL_SignalCondition.html)
- [SDL_WaitCondition](SDL_WaitCondition.html)
- [SDL_WaitConditionTimeout](SDL_WaitConditionTimeout.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
