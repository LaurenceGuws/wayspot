###### (This function is part of SDL_net, a separate library from SDL.)

# NET_RefAddress

Add a reference to an [NET_Address](NET_Address.html).

## Header File

Defined in
[\<SDL3_net/SDL_net.h\>](https://github.com/libsdl-org/SDL_net/blob/main/include/SDL3_net/SDL_net.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
NET_Address* NET_RefAddress(NET_Address *address);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [NET_Address](NET_Address.html) \* | **address** | The [NET_Address](NET_Address.html) to add a reference to. |

## Return Value

([NET_Address](NET_Address.html) \*) Returns the same address that was
passed as a parameter.

## Remarks

Since several pieces of the library might share a single
[NET_Address](NET_Address.html), including a background thread that's
working on resolving, these objects are referenced counted. This allows
everything that's using it to declare they still want it, and drop their
reference to the address when they are done with it. The object's
resources are freed when the last reference is dropped.

This function adds a reference to an [NET_Address](NET_Address.html),
increasing its reference count by one.

The documentation will tell you when the app has to explicitly unref an
address. For example, [NET_ResolveHostname](NET_ResolveHostname.html)()
creates addresses that are already referenced, so the caller needs to
unref it when done.

Generally you only have to explicit ref an address when you have
different parts of your own app that will be sharing an address. In
normal usage, you only have to unref things you've created once (like
you might free() something), but you are free to add extra refs if it
makes sense.

This returns the same address passed as a parameter, which makes it easy
to ref and assign in one step:

<div id="cb2" class="sourceCode">

``` sourceCode
myAddr = NET_RefAddress(yourAddr);
```

</div>

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_net 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLNet](CategorySDLNet.html)
