# Platforms

## Supported Platforms

SDL3 has been known to work on the following platforms at some point:

- [Android](README-android.html)
- [Emscripten](README-emscripten.html) (Web browsers)
- [FreeBSD](README-bsd.html)
- [Haiku OS](README-haiku.html)
- [iOS](README-ios.html)
- [Linux](README-linux.html)
- [macOS](README-macos.html) (10.14 and later)
- [NetBSD](README-bsd.html)
- [Nintendo Switch](README-switch.html) (Separate NDA-only fork)
- [Nintendo 3DS](README-n3ds.html) (Homebrew)
- [Nokia N-Gage](README-ngage.html)
- [OpenBSD](README-bsd.html)
- [PlayStation 2](README-ps2.html) (Homebrew)
- [PlayStation 4](README-ps4.html) (Separate NDA-only fork)
- [PlayStation 5](README-ps5.html) (Separate NDA-only fork)
- [PlayStation Portable](README-psp.html) (Homebrew)
- [PlayStation Vita](README-vita.html) (Homebrew)
- [RISC OS](README-riscos.html)
- [SteamOS](README-steamos.html)
- [tvOS](README-ios.html)
- [visionOS](README-ios.html)
- [Windows](README-windows.html) (XP and later)
- [Windows GDK](README-gdk.html)
- [Xbox](README-gdk.html)

Note that the SDL maintainers do not test on all these platforms; if a
less-common system breaks, [please let us
know](https://github.com/libsdl-org/SDL/issues/new) and send patches if
you can.

If you'd like to port SDL to a new platform, feel free to get in touch!
[A guide to porting
SDL2](https://discourse.libsdl.org/t/port-sdl-2-0-to-bios/25453/2) was
written a while ago, and most of it still applies to SDL3.

## Unsupported Platforms

If your favorite system is listed below, we aren't working on it.
However, if you send reasonable patches and are willing to support the
port in the long term, we are happy to take a look!

All of these still work with [SDL2](../SDL2/FrontPage.html), which is an
incompatible API, but an option if you need to support these platforms
still.

- QNX
- Google Stadia
- NaCL
- OS/2
- WinPhone
- WinRT/UWP

## General notes for Unix platforms

Some aspects of SDL functionality are common to all Unix-based
platforms.

### <span id="setuid"></span>Privileged processes (setuid, setgid, setcap)

SDL is not designed to be used in programs with elevated privileges,
such as setuid (`chmod u+s`) or setgid (`chmod g+s`) executables, or
executables with file-based capabilities (`setcap cap_sys_nice+ep` or
similar). It does not make any attempt to avoid trusting environment
variables or other aspects of the inherited execution environment.
Programs running with elevated privileges in an attacker-controlled
execution environment should not call SDL functions.
