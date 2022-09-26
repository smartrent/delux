# Changelog

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
