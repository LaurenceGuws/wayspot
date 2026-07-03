# SDL_CreateSemaphore

Create a semaphore.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Semaphore * SDL_CreateSemaphore(Uint32 initial_value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Uint32](Uint32.html) | **initial_value** | the starting value of the semaphore. |

## Return Value

([SDL_Semaphore](SDL_Semaphore.html) \*) Returns a new semaphore or NULL
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

This function creates a new semaphore and initializes it with the value
`initial_value`. Each wait operation on the semaphore will atomically
decrement the semaphore value and potentially block if the semaphore
value is 0. Each post operation will atomically increment the semaphore
value and wake waiting threads and allow them to retry the wait
operation.

## Version

This function is available since SDL 3.2.0.

## Code Examples

Typical use of semaphores:

<div id="cb2" class="sourceCode">

``` sourceCode
void add_data_to_queue(void);
void get_data_from_queue(void);
int data_available(void);
void wait_for_threads(void);

SDL_AtomicInt done;
SDL_Semaphore *sem;

SDL_SetAtomicInt(&done, 0);
sem = SDL_CreateSemaphore(0);


Thread_A:
    while (!SDL_GetAtomicInt(&done)) {
        add_data_to_queue();
        SDL_SignalSemaphore(sem);
    }

Thread_B:
    while (!SDL_GetAtomicInt(&done)) {
        SDL_WaitSemaphore(sem);
        if (data_available()) {
            get_data_from_queue();
        }
    }


SDL_SetAtomicInt(&done, 1);
SDL_SignalSemaphore(sem);
wait_for_threads();
SDL_DestroySemaphore(sem);
```

</div>

## See Also

- [SDL_DestroySemaphore](SDL_DestroySemaphore.html)
- [SDL_SignalSemaphore](SDL_SignalSemaphore.html)
- [SDL_TryWaitSemaphore](SDL_TryWaitSemaphore.html)
- [SDL_GetSemaphoreValue](SDL_GetSemaphoreValue.html)
- [SDL_WaitSemaphore](SDL_WaitSemaphore.html)
- [SDL_WaitSemaphoreTimeout](SDL_WaitSemaphoreTimeout.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
