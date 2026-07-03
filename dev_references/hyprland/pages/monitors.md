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

<a href="https://wiki.hypr.land/Configuring/Basics/"
class="hx:inline-block hx:rounded-sm hx:hextra-focus-visible-inset">Basics</a>

</div>

<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6dy0zLjUgaHg6c2hyaW5rLTAgaHg6cnRsOi1yb3RhdGUtMTgwIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik05IDVsNyA3LTcgNyIgLz48L3N2Zz4="
class="hx:w-3.5 hx:shrink-0 hx:rtl:-rotate-180" />

<div class="hx:whitespace-nowrap hx:transition-colors hx:font-medium hx:text-gray-700 hx:contrast-more:font-bold hx:contrast-more:text-current hx:dark:text-gray-100 hx:contrast-more:dark:text-current">

Monitors

</div>

</div>

<div class="content">

<div class="hx:flex hx:flex-col hx:sm:flex-row hx:items-start hx:sm:items-center hx:sm:justify-between hx:gap-4 hx:mb-4">

# Monitors

</div>

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

Looking for the old hyprlang syntax? Check the
<a href="https://wiki.hypr.land/0.54.0/" target="_blank"
rel="noopener">0.54 wiki pages</a>. Since Hyprland 0.55, hyprlang is
deprecated in favor of lua.

</div>

</div>

</div>

## General<span id="general" class="hx:absolute hx:-mt-20"></span> <a href="index.html#general" class="subheading-anchor"
aria-label="Permalink for this section"></a>

The general config of a monitor looks like this:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({
  output = "...",
  mode = "...",
  position = "...",
  scale = ...,
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

A common example:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({
  output = "DP-1",
  mode = "1920x1080@144",
  position = "0x0",
  scale = 1,
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

This will make the monitor on `DP-1` a `1920x1080` display, at 144Hz,
`0x0` off from the top left corner, with a scale of 1 (unscaled).

To list all available monitors (active and inactive):

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hyprctl monitors all
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

Monitors are positioned on a virtual “layout”. The `position` is the
position, in pixels, of said display in the layout. (calculated from the
top-left corner)

For example:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "DP-1", mode = "1920x1080", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080", position = "1920x0", scale = 1 })
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

will tell Hyprland to put DP-1 on the *left* of DP-2, while

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "DP-1", mode = "1920x1080", position = "1920x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080", position = "0x0", scale = 1 })
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

will tell Hyprland to put DP-1 on the *right*.

The `position` may contain *negative* values, so the above example could
also be written as

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "DP-1", mode = "1920x1080", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080", position = "-1920x0", scale = 1 })
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

Hyprland uses an inverse Y cartesian system. Thus, a negative y
coordinate places a monitor higher, and a positive y coordinate will
place it lower.

For example:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "DP-1", mode = "1920x1080", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080", position = "0x-1080", scale = 1 })
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

will tell Hyprland to put DP-2 *above* DP-1, while

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "DP-1", mode = "1920x1080", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080", position = "0x1080", scale = 1 })
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

will tell Hyprland to put DP-2 *below*.

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

The position is calculated with the scaled (and transformed) resolution,
meaning if you want your 4K monitor with scale 2 to the left of your
1080p one, you’d use the position `1920x0` for the second screen (3840 /
2). If the monitor is also rotated 90 degrees (vertical), you’d use
`1080x0`.

</div>

</div>

</div>

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

No monitors can overlap. This means that if your set positions make any
monitors overlap, you will get a warning.

</div>

</div>

</div>

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

“Invalid scale” warnings will pop up if your scale does not create valid
logical pixels. A valid scale must divide your resolution cleanly
(without decimals). For example 1920x1080 / 1.5 = 1280x720 -\> OK, but
when / 1.4 -\> 1371.4286x771.42857 -\> not ok.

</div>

</div>

</div>

Leaving the `output` empty will define a fallback rule to use when no
other rules match.

There are a few special values for the `mode` field:

- `preferred` - use the display’s preferred size and refresh rate.
- `highres` - use the highest supported resolution.
- `highrr` - use the highest supported refresh rate.
- `maxwidth` - use the widest supported resolution.

`position` also has a few special values:

- `auto` - let Hyprland decide on a position. By default, it places each
  new monitor to the right of existing ones, using the monitor’s top
  left corner as the root point.
- `auto-right/left/up/down` - place the monitor to the right/left, above
  or below other monitors, also based on each monitor’s top left corner
  as the root.
- `auto-center-right/left/up/down` - place the monitor to the
  right/left, above or below other monitors, but calculate placement
  from each monitor’s center rather than its top left corner.

***Please Note:*** While specifying a monitor direction for your first
monitor is allowed, this does nothing and it will be positioned at
(0,0). Also, the direction is always from the center out, so you can
specify `auto-up` then `auto-left`, but the left monitors will just be
left of the origin and above the origin. You can also specify duplicate
directions and monitors will continue to go in that direction.

You can also use `auto` as a scale to let Hyprland decide on a scale for
you. These depend on the PPI of the monitor.

Recommended rule for quickly plugging in random monitors:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
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

This will make any monitor that was not specified with an explicit rule
automatically placed on the right of the other(s), with its preferred
resolution.

For more specific rules, you can also use the output’s description (see
`hyprctl monitors` for more details). If the output of
`hyprctl monitors` looks like the following:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
Monitor eDP-1 (ID 0):
        1920x1080@60.00100 at 0x0
        description: Chimei Innolux Corporation 0x150C (eDP-1)
        make: Chimei Innolux Corporation
        model: 0x150C
        [...]
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

then the `description` value up to, but not including the portname
`(eDP-1)` can be used as the `output` field with a `desc:` prefix:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "desc:Chimei Innolux Corporation 0x150C", mode = "preferred", position = "auto", scale = 1.5 })
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

Remember to remove the `(portname)`!

### Custom modelines<span id="custom-modelines" class="hx:absolute hx:-mt-20"></span> <a href="index.html#custom-modelines" class="subheading-anchor"
aria-label="Permalink for this section"></a>

You can set up a custom modeline by passing a modeline string as the
`mode` field:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({
  output = "DP-1",
  mode = "modeline 1071.101 3840 3848 3880 3920 2160 2263 2271 2277 +hsync -vsync",
  position = "0x0",
  scale = 1,
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

### Disabling a monitor<span id="disabling-a-monitor" class="hx:absolute hx:-mt-20"></span> <a href="index.html#disabling-a-monitor" class="subheading-anchor"
aria-label="Permalink for this section"></a>

To disable a monitor, set `disabled = true`:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "name", disabled = true })
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

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

Disabling a monitor will literally remove it from the layout, moving all
windows and workspaces to any remaining ones. If you want to disable
your monitor in a screensaver style (just turn off the monitor) use the
`dpms`
[dispatcher](https://wiki.hypr.land/Configuring/Basics/Dispatchers).

</div>

</div>

</div>

## Custom reserved area<span id="custom-reserved-area" class="hx:absolute hx:-mt-20"></span> <a href="index.html#custom-reserved-area" class="subheading-anchor"
aria-label="Permalink for this section"></a>

A reserved area is an area that remains unoccupied by tiled windows. If
your workflow requires a custom reserved area, you can add it with the
`reserved_area` field. It accepts either a single integer (all sides) or
a table with individual sides:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
-- all sides
hl.monitor({ output = "name", reserved_area = 10 })

-- individual sides
hl.monitor({ output = "name", reserved_area = { top = 10, bottom = 10, left = 0, right = 0 } })
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

This stacks on top of the calculated reserved area (e.g. bars), but you
may only use one of these rules per monitor in the config.

## Fields<span id="fields" class="hx:absolute hx:-mt-20"></span> <a href="index.html#fields" class="subheading-anchor"
aria-label="Permalink for this section"></a>

All fields beyond `output` are optional and fall back to sensible
defaults.

| Field | Type | Default | Description |
|----|----|----|----|
| output | string | required | Output name or `desc:...` description prefix |
| mode | string | preferred | Resolution and refresh rate, e.g. `1920x1080@144` |
| position | string | auto | Position in the virtual layout, e.g. `1920x0` |
| scale | string / float | auto | Scale factor, e.g. `1.5` |
| disabled | boolean | false | Removes the monitor from the layout |
| transform | integer | 0 | Rotation/flip transform (0–7) |
| mirror | string |  | Output name to mirror |
| bitdepth | integer | 8 | Bit depth (8 or 10) |
| cm | string | srgb | Color management preset |
| sdr_eotf | string | default | SDR transfer function (default, gamma22, srgb) |
| sdrbrightness | float | 1.0 | SDR brightness in HDR mode |
| sdrsaturation | float | 1.0 | SDR saturation in HDR mode |
| vrr | integer | 0 | VRR mode |
| icc | string |  | Absolute path to an ICC profile |
| reserved_area | integer or table | 0 | Reserved area - integer for all sides, or table with top/right/bottom/left |
| supports_wide_color | integer | 0 | Force wide color gamut (-1 = off, 0 = auto, 1 = on) |
| supports_hdr | integer | 0 | Force HDR support (-1 = off, 0 = auto, 1 = on) |
| sdr_min_luminance | float | 0.2 | SDR minimum luminance for SDR→HDR mapping |
| sdr_max_luminance | integer | 80 | SDR maximum luminance |
| min_luminance | float | -1 | Monitor minimum luminance |
| max_luminance | integer | -1 | Monitor maximum possible luminance |
| max_avg_luminance | integer | -1 | Monitor maximum average luminance |

### Mirrored displays<span id="mirrored-displays" class="hx:absolute hx:-mt-20"></span> <a href="index.html#mirrored-displays" class="subheading-anchor"
aria-label="Permalink for this section"></a>

If you want to mirror a display, use the `mirror` field:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "0x0", scale = 1, mirror = "DP-2" })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "DP-1" })
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

Please remember that mirroring displays will not “re-render” everything
for your second monitor, so if mirroring a 1080p screen onto a 4K one,
the resolution will still be 1080p on the 4K display. This also means
squishing and stretching will occur on aspect ratios that differ (e.g
16:9 and 16:10).

### 10 bit support<span id="10-bit-support" class="hx:absolute hx:-mt-20"></span> <a href="index.html#10-bit-support" class="subheading-anchor"
aria-label="Permalink for this section"></a>

If you want to enable 10 bit support for your display, set
`bitdepth = 10`:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "eDP-1", mode = "2880x1800@90", position = "0x0", scale = 1, bitdepth = 10 })
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

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

Colors registered in Hyprland (e.g. the border color) do *not* support
10 bit.  
Some applications do *not* support screen capture with 10 bit enabled.

</div>

</div>

</div>

### Color management presets<span id="color-management-presets" class="hx:absolute hx:-mt-20"></span> <a href="index.html#color-management-presets" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Use the `cm` field to change the default sRGB output preset:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "eDP-1", mode = "2880x1800@90", position = "0x0", scale = 1, bitdepth = 10, cm = "wide" })
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

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
auto    - srgb for 8bpc, wide for 10bpc if supported (recommended)
srgb    - sRGB primaries (default)
dcip3   - DCI P3 primaries
dp3     - Apple P3 primaries
adobe   - Adobe RGB primaries
wide    - wide color gamut, BT2020 primaries
edid    - primaries from edid (known to be inaccurate)
hdr     - wide color gamut and HDR PQ transfer function (experimental)
hdredid - same as hdr with edid primaries (experimental)
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

Fullscreen HDR is possible without the `hdr` cm setting if
`render:cm_auto_hdr` is enabled.

Use `sdrbrightness` and `sdrsaturation` to control SDR brightness and
saturation in HDR mode. The default for both values is `1.0`. Typical
brightness value should be in the `1.0 ... 2.0` range.

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({
  output = "eDP-1",
  mode = "2880x1800@90",
  position = "0x0",
  scale = 1,
  bitdepth = 10,
  cm = "hdr",
  sdrbrightness = 1.2,
  sdrsaturation = 0.98,
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

The default transfer function assumed to be in use on an SDR display for
sRGB content is defined by `sdr_eotf`. The default (`"default"`) follows
`render:cm_sdr_eotf`. This can be changed to piecewise sRGB with
`"srgb"`, or Gamma 2.2 with `"gamma22"`.

### ICC Profiles<span id="icc-profiles" class="hx:absolute hx:-mt-20"></span> <a href="index.html#icc-profiles" class="subheading-anchor"
aria-label="Permalink for this section"></a>

You can load an ICC profile via the `icc` field (path must be absolute):

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "eDP-1", icc = "/path/to/icc.icm" })
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

Please note:

- Path needs to be absolute.
- Having an ICC applied will automatically force `sdr_eotf` to `sRGB`
  for that monitor (for color accuracy).
- Having an ICC applied overrides the CM preset.
- ICCs are fundamentally incompatible with HDR gaming. Funky stuff may
  happen.

### VRR<span id="vrr" class="hx:absolute hx:-mt-20"></span> <a href="index.html#vrr" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Per-display VRR can be configured with the `vrr` field, where the value
is the mode from the [variables
page](https://wiki.hypr.land/Configuring/Basics/Variables).

## Rotating<span id="rotating" class="hx:absolute hx:-mt-20"></span> <a href="index.html#rotating" class="subheading-anchor"
aria-label="Permalink for this section"></a>

If you want to rotate a monitor, use the `transform` field:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.monitor({ output = "eDP-1", mode = "2880x1800@90", position = "0x0", scale = 1, transform = 1 })
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

Transform list:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
0 -> normal (no transforms)
1 -> 90 degrees
2 -> 180 degrees
3 -> 270 degrees
4 -> flipped
5 -> flipped + 90 degrees
6 -> flipped + 180 degrees
7 -> flipped + 270 degrees
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

## Default workspace<span id="default-workspace" class="hx:absolute hx:-mt-20"></span> <a href="index.html#default-workspace" class="subheading-anchor"
aria-label="Permalink for this section"></a>

See [Workspace
Rules](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules).

### Binding workspaces to a monitor<span id="binding-workspaces-to-a-monitor" class="hx:absolute hx:-mt-20"></span> <a href="index.html#binding-workspaces-to-a-monitor"
class="subheading-anchor" aria-label="Permalink for this section"></a>

See [Workspace
Rules](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules).

</div>

<div class="hx:mt-12 hx:mb-8 hx:block hx:text-xs hx:text-gray-500 hx:ltr:text-right hx:rtl:text-left hx:dark:text-gray-400">

Last updated on July 3, 2026

</div>

<div class="hx:mb-8 hx:flex hx:items-center hx:border-t hx:pt-8 hx:border-gray-200 hx:dark:border-neutral-800 hx:contrast-more:border-neutral-400 hx:dark:contrast-more:border-neutral-400 hx:print:hidden">

<a href="https://wiki.hypr.land/Configuring/Basics/Variables/"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:pr-4 hx:rtl:pl-4"
title="Variables"><img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpsdHI6cm90YXRlLTE4MCIgZmlsbD0ibm9uZSIgdmlld2JveD0iMCAwIDI0IDI0IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBhcmlhLWhpZGRlbj0idHJ1ZSI+PHBhdGggc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBkPSJNOSA1bDcgNy03IDciIC8+PC9zdmc+"
class="hx:inline hx:h-5 hx:shrink-0 hx:ltr:rotate-180" />Variables</a><a href="../Binds/index.html"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:ml-auto hx:ltr:pl-4 hx:ltr:text-right hx:rtl:mr-auto hx:rtl:pr-4 hx:rtl:text-left"
title="Binds">Binds<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpydGw6LXJvdGF0ZS0xODAiIGZpbGw9Im5vbmUiIHZpZXdib3g9IjAgMCAyNCAyNCIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgYXJpYS1oaWRkZW49InRydWUiPjxwYXRoIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIgZD0iTTkgNWw3IDctNyA3IiAvPjwvc3ZnPg=="
class="hx:inline hx:h-5 hx:shrink-0 hx:rtl:-rotate-180" /></a>

</div>

</div>
