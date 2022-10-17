# Changelog

## v0.4.1 - 2022-10-17

* Changes
  * Added support for starting Delux as an OTP application. This is triggered by
    supplying an application configuration (see README.md). Please see
    documentation for tradeoffs.
  * Added support for specifying an initial configuration. The indicators no
    longer are forced to start in the off state.
  * Support looping Morse code sequences

## v0.4.0 - 2022-10-14

This is a big update that improves program playback timing to compensate for
the Linux kernel's HZ configuration and implementation of LED pattern triggers.
This affects all programs, but you probably won't notice it unless you're
creating Morse code patterns or measuring LED output with a logic analyzer.

* Backwards incompatible changes
  * "Priority" is now called "slot". If you have custom priorities defined in
    your configurations, you will need to change them to `slot`. This change
    was made to make the use of this feature easier to explain. I.e. programs
    are put in slots, one program per slot per indicator, slots have an order.

* Changes
  * Added `:backend` parameters and specifically the `:hz` parameter to support
    better playback timing. If unset, HZ=1000 is assumed. This results in
    almost the same timings as earlier versions. See the README for more
    information.
  * Added `Delux.Effects.number_blink/3` for blinking out a number. This is for
    things like error codes - like error 1, 2, 3, etc.
  * Added `Delux.Effects.timing_test/2` to debug timing precision issues with a
    logic analyzer.
  * Removed unnecessary writes to the filesystem when using multiple
    indicators. This fixes an issue where a change on one indicator restarts a
    program on a second indicator.
  * Reorganized the backend code to support future alternative backends. This is
    currently unplanned work, but it's now easier to think about adding a way to
    run Delux using Circuits.GPIO or a simulated LED.

## v0.3.1 - 2022-09-26

* Changes
  * Support dimming arbitrary patterns to off. The dimming feature still doesn't
    dim all patterns, but dimming to off works for everything now.

## v0.3.0 - 2022-09-07

* Changes
  * Favor singleton use of Delux with default arguments to `render/3` and
    `info/2`. Now that Delux is being used more frequently as a singleton, this
    makes the API more convenient. This is backwards incompatible if you had
    been taking advantage of default arguments, but you should get compile-time
    and dialyzer errors. If you do name your Delux GenServers, you'll have to
    specify all arguments to `render/3` and `info/2`.
  * Improve argument error messages by reporting what the valid options are in
    addition to what you passed.

## v0.2.0 - 2022-08-26

* Changes
  * Register the Delux GenServer with a default name so that pids or names don't
    need to be passed to all APIs. Since Delux is almost always used as a
    singleton, this simplifies the API.

## v0.1.3 - 2022-08-11

* Changes
  * Fix typespecs to remove warnings found by Dialyzer
  * Update `Delux.Effects.waveform/3` to support color atom names and check RGB
    tuples for range. The latter fixes errors that get detected later on and are
    more confusing to figure out.

## v0.1.2 - 2022-08-11

* Changes
  * Improve `Delux.Effects.waveform/3` so that it's easier to use and produces
    shorter patterns. It now has examples in the docs and unit tests.

## v0.1.1 - 2022-08-10

* Changes
  * Adjust timed pattern playback to minimize trimming LED programs.
    Unfortunately, LED programs still get cut off at the end with this release.
    If you're using Morse code, you'll see this. We plan on fixing this
    completely in a future release.
  * Support empty LED setups to simplify configuration of multi-target projects
    and unit tests.

## v0.1.0 - 2022-08-08

Initial release
