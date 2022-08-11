# Changelog

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
