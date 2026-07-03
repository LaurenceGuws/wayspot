<div id="content"
class="hx:w-full hx:min-w-0 hextra-max-content-width hx:px-6 hx:pt-4 hx:md:px-12"
role="main">

<div class="hx:mt-1.5 hx:flex hx:items-center hx:gap-1 hx:overflow-hidden hx:text-sm hx:text-gray-500 hx:dark:text-gray-400 hx:contrast-more:text-current">

<div class="hx:whitespace-nowrap hx:transition-colors hx:min-w-[24px] hx:overflow-hidden hx:text-ellipsis hx:hover:text-gray-900 hx:dark:hover:text-gray-100">

<a href="https://wiki.hypr.land/Configuring/"
class="hx:inline-block hx:rounded-sm hx:hextra-focus-visible-inset">Configuring</a>

</div>

<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6dy0zLjUgaHg6c2hyaW5rLTAgaHg6cnRsOi1yb3RhdGUtMTgwIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik05IDVsNyA3LTcgNyIgLz48L3N2Zz4="
class="hx:w-3.5 hx:shrink-0 hx:rtl:-rotate-180" />

<div class="hx:whitespace-nowrap hx:transition-colors hx:min-w-[24px] hx:overflow-hidden hx:text-ellipsis hx:hover:text-gray-900 hx:dark:hover:text-gray-100">

<a href="https://wiki.hypr.land/Configuring/Advanced-and-Cool/"
class="hx:inline-block hx:rounded-sm hx:hextra-focus-visible-inset">Advanced
and Cool</a>

</div>

<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6dy0zLjUgaHg6c2hyaW5rLTAgaHg6cnRsOi1yb3RhdGUtMTgwIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik05IDVsNyA3LTcgNyIgLz48L3N2Zz4="
class="hx:w-3.5 hx:shrink-0 hx:rtl:-rotate-180" />

<div class="hx:whitespace-nowrap hx:transition-colors hx:font-medium hx:text-gray-700 hx:contrast-more:font-bold hx:contrast-more:text-current hx:dark:text-gray-100 hx:contrast-more:dark:text-current">

Using hyprctl

</div>

</div>

<div class="content">

<div class="hx:flex hx:flex-col hx:sm:flex-row hx:items-start hx:sm:items-center hx:sm:justify-between hx:gap-4 hx:mb-4">

# Using hyprctl

</div>

`hyprctl` is a utility for controlling some parts of the compositor from
a CLI or a script. It should automatically be installed along with
Hyprland.

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

*hyprctl* calls will be dispatched by the compositor *synchronously*,
meaning any spam of the utility will cause slowdowns. It’s recommended
to use `--batch` for many control calls, and limiting the amount of info
calls.

For live event handling, see the
[events](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Expanding-functionality/#events).

</div>

</div>

</div>

## Commands<span id="commands" class="hx:absolute hx:-mt-20"></span> <a href="index.html#commands" class="subheading-anchor"
aria-label="Permalink for this section"></a>

### eval<span id="eval" class="hx:absolute hx:-mt-20"></span> <a href="index.html#eval" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Issue a lua string to execute dynamically, returns “ok” or any error
raised.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "3" }))'
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

### repl<span id="repl" class="hx:absolute hx:-mt-20"></span> <a href="index.html#repl" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Start an interactive Lua REPL session or issue a lua string and print
the result through tostring. Similar to `lua` interactive mode. Exit
with Ctrl+D.

Usage:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl repl        # start REPL session
hyprctl repl [code] # execute code and print the result
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

Examples:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
» hyprctl repl 'hl.get_active_window().class'
foot

» hyprctl repl
> for i,w in pairs(hl.get_windows()) do print(i, w.class) end
1       foot
2       firefox
3       codium
> hl.notification.create({ text = "Hello World", timeout = 2000})
HL.Notification(0x563c0a1ebe70)
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

### dispatch<span id="dispatch" class="hx:absolute hx:-mt-20"></span> <a href="index.html#dispatch" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Dispatch is a shorthand for `eval 'hl.dispatch(...)'`:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl dispatch 'hl.dsp.focus({ workspace = "3" })'
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

See [Dispatchers](https://wiki.hypr.land/Configuring/Basics/Dispatchers)
for a list of dispatchers.

### reload<span id="reload" class="hx:absolute hx:-mt-20"></span> <a href="index.html#reload" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Issue a `reload` to force reload the config. `reload full-reset` will
recreate the entire config context, allowing switching to/from
lua/hyprlang. `full-reset` should not be used unless really necessary.

### kill<span id="kill" class="hx:absolute hx:-mt-20"></span> <a href="index.html#kill" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Issue a `kill` to get into a kill mode, where you can kill an app by
clicking on it. You can exit it with ESCAPE.

Kind of like xkill.

### setcursor<span id="setcursor" class="hx:absolute hx:-mt-20"></span> <a href="index.html#setcursor" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Sets the cursor theme and reloads the cursor manager. Will set the theme
for everything except GTK, because GTK.

Please note that since 0.37.0, this only accepts hyprcursor themes. For
legacy xcursor themes, use the `XCURSOR_THEME` and `XCURSOR_SIZE` env
vars.

params: theme and size

e.g.:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl setcursor Bibata-Modern-Classic 24
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

### output<span id="output" class="hx:absolute hx:-mt-20"></span> <a href="index.html#output" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Allows you to add and remove fake outputs to your preferred backend.

Usage:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl output create [backend] (name)
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

or

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl output remove [name]
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

Where `[backend]` is the name of the backend and `(name)` is an optional
name for the output. If `(name)` is not specified, the default naming
scheme will be used (`HEADLESS-2`, `WL-1`, etc.)

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

`create` and `remove` can also be `add` or `destroy`, respectively.

</div>

</div>

</div>

Available backends:

- `wayland`: Creates an output as a Wayland window. This will only work
  if you’re already running Hyprland with the Wayland backend.
- `headless`: Creates a headless monitor output. If you’re running a
  VNC/RDP/ Sunshine server, you should use this.
- `auto`: Picks a backend for you. For example, if you’re running
  Hyprland from the TTY, `headless` will be chosen.

For example, to create a headless output named “test”:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl output create headless test
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

And to remove it:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl output remove test
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

### switchxkblayout<span id="switchxkblayout" class="hx:absolute hx:-mt-20"></span> <a href="index.html#switchxkblayout" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Sets the xkb layout index for a keyboard.

For example, if you set:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.device({
  name = "my-epic-keyboard-v1",
  kb_layout = "us,pl,de"
})
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

You can use this command to switch between them.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl switchxkblayout [DEVICE] [CMD]
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

where `CMD` is either `next` for next, `prev` for previous, or `ID` for
a specific one (in the above case, `us`: 0, `pl`: 1, `de`: 2). You can
find the `DEVICE` using `hyprctl devices` command.

`DEVICE` can also be `current` or `all`, self-explanatory. Current is
the `main` keyboard from `devices`.

Example command for a typical keyboard:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl switchxkblayout at-translated-set-2-keyboard next
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

If you want a single variant i.e. pl/dvorak on one layout but us/qwerty
on the other, xkb parameters can still be blank, however the amount of
comma-separated parameters have to match. Alternatively, a single
parameter can be specified for it to apply to all three.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.config({
  input = {
    kb_layout = "pl,us,ru",
     kb_variant = "dvorak,,",
     kb_options = "caps:ctrl_modifier"
  }
})
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

</div>

</div>

</div>

### seterror<span id="seterror" class="hx:absolute hx:-mt-20"></span> <a href="index.html#seterror" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Sets the hyprctl error string. Will reset when Hyprland’s config is
reloaded.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl seterror 'rgba(66ee66ff)' hello world this is my problem
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

To disable:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl seterror disable
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

### getprop<span id="getprop" class="hx:absolute hx:-mt-20"></span> <a href="index.html#getprop" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Gets a property value of a window.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl getprop [window] [property]
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

Where `window` is as described
[here](https://wiki.hypr.land/Configuring/Basics/Dispatchers#parameter-explanation),
and `property` is any which can be set with
[setprop](../../Basics/Dispatchers/index.html#set_prop).

#### Notes<span id="notes" class="hx:absolute hx:-mt-20"></span> <a href="index.html#notes" class="subheading-anchor"
aria-label="Permalink for this section"></a>

- If `animationstyle` is unset, `(unset)` is returned.
- `min_size` defaults to `20 20`.
- `max_size` defaults to `inf inf` or `[null,null]` in JSON.

### notify<span id="notify" class="hx:absolute hx:-mt-20"></span> <a href="index.html#notify" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Sends a notification using the built-in Hyprland notification system.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl notify [ICON] [TIME_MS] [COLOR] [MESSAGE]
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

For example:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl notify -1 10000 "rgb(ff1ea3)" "Hello everyone!"
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

Icon of `-1` means “No icon”

Color of `0` means “Default color for icon”

Icon list:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
WARNING = 0
INFO = 1
HINT = 2
ERROR = 3
CONFUSED = 4
OK = 5
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

Optionally, you can specify a font size of the notification like so:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl notify -1 10000 "rgb(ff0000)" "fontsize:35 This text is big"
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

The default font-size is 13.

### dismissnotify<span id="dismissnotify" class="hx:absolute hx:-mt-20"></span> <a href="index.html#dismissnotify" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Dismisses all or up to AMOUNT notifications.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl dismissnotify # dismiss all notifications
hyprctl dismissnotify 2 # dismiss the oldest 2 notifications
hyprctl dismissnotify -1 # dismiss all notifications (same as no arguments)
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

## Info<span id="info" class="hx:absolute hx:-mt-20"></span> <a href="index.html#info" class="subheading-anchor"
aria-label="Permalink for this section"></a>

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
version - prints the Hyprland version along with flags, commit and branch of build.
monitors - lists active outputs with their properties, 'monitors all' lists active and inactive outputs
workspaces - lists all workspaces with their properties
activeworkspace - gets the active workspace and its properties
workspacerules - gets the list of defined workspace rules
clients - lists all windows with their properties
devices - lists all connected keyboards and mice
decorations [window] - lists all decorations and their info
binds - lists all registered binds
activewindow - gets the active window name and its properties
layers - lists all the layers
splash - prints the current random splash
getoption [option] - gets the config option status (values)
cursorpos - gets the current cursor position in global layout coordinates
animations - gets the currently configured info about animations and beziers
instances - lists all running instances of Hyprland with their info
layouts - lists all layouts available (including from plugins)
configerrors - lists all current config parsing errors
rollinglog - prints tail of the log. Also supports -f/--follow option
locked - prints whether the current session is locked.
descriptions - returns a JSON with all config options, their descriptions and types.
submap - prints the current submap the keybinds are in
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

For the getoption command, the option name should be written as
`section.option`, e.g.:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl getoption general.border_size

# For nested sections:
hyprctl getoption input.touchpad.disable_while_typing
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

See [Variables](https://wiki.hypr.land/Configuring/Basics/Variables) for
sections and options you can use.

## Batch<span id="batch" class="hx:absolute hx:-mt-20"></span> <a href="index.html#batch" class="subheading-anchor"
aria-label="Permalink for this section"></a>

You can use the legacy `--batch` flag to issue multiple commands
separated with a `;`.

## Flags<span id="flags" class="hx:absolute hx:-mt-20"></span> <a href="index.html#flags" class="subheading-anchor"
aria-label="Permalink for this section"></a>

You can specify flags for the request like this:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl -j monitors
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

flag list:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
j -> output in JSON
i -> select instance (id or index in hyprctl instances)
r -> force state refresh after issuing commands (e.g. layout or rule changes)
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

</div>

<div class="hx:mt-12 hx:mb-8 hx:block hx:text-xs hx:text-gray-500 hx:ltr:text-right hx:rtl:text-left hx:dark:text-gray-400">

Last updated on July 3, 2026

</div>

<div class="hx:mb-8 hx:flex hx:items-center hx:border-t hx:pt-8 hx:border-gray-200 hx:dark:border-neutral-800 hx:contrast-more:border-neutral-400 hx:dark:contrast-more:border-neutral-400 hx:print:hidden">

<a
href="https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:pr-4 hx:rtl:pl-4"
title="Permissions"><img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpsdHI6cm90YXRlLTE4MCIgZmlsbD0ibm9uZSIgdmlld2JveD0iMCAwIDI0IDI0IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBhcmlhLWhpZGRlbj0idHJ1ZSI+PHBhdGggc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBkPSJNOSA1bDcgNy03IDciIC8+PC9zdmc+"
class="hx:inline hx:h-5 hx:shrink-0 hx:ltr:rotate-180" />Permissions</a><a
href="https://wiki.hypr.land/Configuring/Advanced-and-Cool/Notifications/"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:ml-auto hx:ltr:pl-4 hx:ltr:text-right hx:rtl:mr-auto hx:rtl:pr-4 hx:rtl:text-left"
title="Notifications">Notifications<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpydGw6LXJvdGF0ZS0xODAiIGZpbGw9Im5vbmUiIHZpZXdib3g9IjAgMCAyNCAyNCIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgYXJpYS1oaWRkZW49InRydWUiPjxwYXRoIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIgZD0iTTkgNWw3IDctNyA3IiAvPjwvc3ZnPg=="
class="hx:inline hx:h-5 hx:shrink-0 hx:rtl:-rotate-180" /></a>

</div>

</div>
