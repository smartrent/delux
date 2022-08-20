# 💡 delux 💡

[![CircleCI](https://circleci.com/gh/smartrent/delux.svg?style=svg)](https://circleci.com/gh/smartrent/delux)
[![Hex version](https://img.shields.io/hexpm/v/delux.svg "Hex version")](https://hex.pm/packages/delux)

_de lux_ | _Latin (roughly) for "of the light"_

<!-- MODULEDOC -->
Use LEDs for your user interface

`delux` simplifies creating and running LED blink patterns for use as part of a
user interface for an embedded hardware. This library provides:

* Low overhead LED control via Linux's Sysclass interface - blink sequences
  get compiled down so that they can be run inside the Linux kernel.
* Built-in LED effects for common use cases like blinking, cycling LED colors,
  etc.
* Prioritization of LED effects
* Support for many physical LED configurations
* Nice textual descriptions of what the LED is doing to support remote debug

This library is primarily intended for devices with 1 to 10 LEDs. It's currently
not for Neopixels and other "smart" LEDs that are more typically found in larger
numbers, but could be used for a similar purpose.

Before diving in, some terminology is needed:

* LED - one light emitting element. This doesn't have to be an LED, but the
  Linux kernel must think that it is and show a directory for it under
  `/sys/class/leds/`.
* Indicator - a group of 1, 2, or 3 LEDs that a user would perceive as one. This
  could be a lone green LED, or a red, green and blue LED in one package, or any
  combination.
* Program - a one-time or repeating set of instructions for controlling an
  indicator.
* Pattern - a low-level sequence of brightness and duration tuples for
  controlling one LED
* Program priority - a user-provided name that determines which program is run
  when multiple are scheduled. For example, a program that gives the user
  feedback for pressing a button could take precedence over a program showing
  network connection status

To give a flavor of how `delux` works, here's an example that configures `delux`
with one green LED and then blinks it at 2 Hz:

```elixir
iex> {:ok, pid} = Delux.start_link(indicators: %{default: %{green: "led0"}})
iex> Delux.render(pid, Delux.Effects.blink(:green, 2))
iex> Delux.info(pid)
green at 2 Hz
```

This starts Delux with one indicator, `:default`, that has a green LED known to
Linux as `"led0"`. The `Delux.Effects.blink/3` function creates a 2 Hz blinking
program for Delux to render. With nothing else specified, `Delux.render/2` runs
the program on the default indicator at the default priority.

<!-- MODULEDOC -->

## Built-in indicator programs

`delux` comes with helper functions for creating LED programs. It's also
possible to create your own. Here are the built-in ones:

| Function                    | Description  |
| --------------------------- | ------------ |
| `Delux.Effects.off/0`       | Turn an indicator off |
| `Delux.Effects.on/2`        | Set the indicator to the specified color (within reason, that is. You can't make a green LED red, for example.) |
| `Delux.Effects.blink/3`     | Blink a color on and off at a fixed rate |
| `Delux.Effects.blip/3`      | Show two colors quickly in succession. E.g., use to show feedback from pressing a button. |
| `Delux.Effects.cycle/3`     | Cycle through a set of colors at a fixed rate |
| `Delux.Effects.waveform/2`  | Synthesize an LED pattern from a function |
| `Delux.Morse.encode/3`      | Send a string in Morse code |

## Before you use `delux`

It's worthwhile thinking about how you want your device's LEDs to behave before
writing any code.

The first step is to figure out what LEDs are available and how to group them
into indicators. To see what's available, list the directories in
`/sys/class/leds`. If something is missing, you'll likely need to adjust the
device tree configuration and make it appear. That's discussed somewhat below,
but this is device-specific, so you'll need to look elsewhere for precise
guides. After you've found the LEDs, group them and give them indicator names.
If you just have one indicator, call it `:default`. That will make `delux`'s API
more convenient.

Step 2 is to decide what priorities make sense for your application. Only one
program per indicator can be run at a time. Every time that you set a program on
an indicator, it replaces any running programs for that indicator at that
priority. The default priorities probably suffice to start:

* `:status` - The lowest priority. This is for general device status like
  whether networking is working and if the device is initializing and connected
  to the back end.
* `:notification` - This is a medium priority. Use it to show transient things
  like an alert that requires operator attention to clear.
* `:user_feedback` - This is the highest priority and for showing feedback to a
  user. For example, it could blink the LED when user pushes a button so they
  know that the device is doing something.

Clearing the program at one priority makes `delux` render the program on the
next lower priority or if there's no program, then the indicator is turned off.

Sometimes adding priorities can remove the need to write state machine code.

Once you feel good about the indicators and priority levels, it's time to
configure `delux`.

## Configuration

After adding `delux` to your mix dependencies, add `Delux` to a supervision
tree of your choice. The childspec looks like:

```elixir
  {Delux,
   name: MyIndicators,
   indicators: %{
     default: %{red: "led0:red", green: "led0:green", blue: "led0:blue"},
     indicator2: %{red: "led1"}
   }}
```

The above configuration shows two indicators. The first is called `:default` and
is an RGB indicator. The second is a lone red LED that's used as `:indicator2`.
As mentioned before, if you only have one indicator, call it `:default`.

Other options include setting the list of priorities and giving the `Delux`
GenServer a name. Those are optional.

## Use

After you have a `Delux` GenServer and running, call `Delux.render/2` to turn on
the default indicator on the default priority:

```elixir
iex> Delux.render(MyIndicators, Delux.Effects.on(:white))
:ok
```

Even if you don't have an RGB indicator, passing `:white` should turn on all of
the LEDs that you do have.

If you have two indicators and want them to blink back and forth, you can try
this:

```elixir
iex> Delux.render(MyIndicators, %{
    default: Delux.Effects.cycle([:black, :white], 1),
    indicator2: Delux.Effects.cycle([:white, :black], 1)
  })
:ok
```

Finally, pass a third parameter to `Delux.render/3` to assign the programs to
another priority.

## Creating your own programs

Indicator programs are a collection of LED patterns and metadata as defined by
the `Delux.Program` struct. The helper functions in `Delux.Effects` and
`Delux.Morse` create these and can be used as examples.

The core of the program is an `Delux.Pattern`. There are three patterns per
program for each of the color channels.

Each pattern is a list of `{value, duration}` tuples where `value` is a number
from 0 to 1 and duration is an integer number of milliseconds. While `delux`
internally holds a number from 0 (off) to 1 (full on) for the LED's value at
that point in time, this gets scaled to an integer when sent to Linux. This
integer depends on the maximum brightness value for an LED. This is often just 1
since Linux can only turn the LED off and on. Sometimes Linux can set the LED to
multiple levels and in those cases, the maximum value will be greater than 1
(often 255). You don't need to worry about scaling other than to be aware that
fractional values will be rounded when sent to Linux and this will mess up
colors.

Linux interpolates the LED value over the duration between pairs of tuples. A
common idiom is to have 0 duration tuples to turn off interpolation. For
example, `[{1, 100}, {1, 0}, {0, 100}, {0, 0}]` turns the LED on for 100 ms and
then off for 100 ms without any interpolation.

See Linux's LED pattern trigger documentation at
[leds-trigger-pattern.txt](https://elixir.bootlin.com/linux/v5.19/source/Documentation/devicetree/bindings/leds/leds-trigger-pattern.txt)
for more info.

## Linux kernel configuration

`delux` works in all official Nerves systems. If not using Nerves, you will need
to have `CONFIG_LEDS_TRIGGER_PATTERN=y` enabled your Linux kernel configuration.

The second step to using Linux's LED subsystem is to configure LEDs in the
device tree. You can't just use an arbitrary GPIO to turn on the LED like you
can with `Circuits.GPIO`. Linux needs to know about the GPIO. It's also possible
to hook up PWMs and LED drivers. See the [LED
drivers](https://elixir.bootlin.com/linux/latest/source/drivers/leds) for
options.

> #### Tip {: .tip}
>
> If you're using a BeagleBone, check out
> [Udo Schneider's blog post on device tree overlays](https://pubray.com/udo-schneider/custom-device-tree-overlays-for-beagle-bone-black-running-nerves)

The following is an example device tree configuration for telling Linux about
GPIO-connected LEDs. It is platform-specific so you can't just copy/paste it.
It sets up two RGB LEDs and makes one blink early in the boot process.

```dts
/ {
        leds {
                pinctrl-names = "default";
                pinctrl-0 = <&pinctrl_leds>;
                compatible = "gpio-leds";

                led1_red {
                        label = "led1:red";
                        gpios = <&pio 0 7 GPIO_ACTIVE_LOW>;
                };
                led1_green {
                        label = "led1:green";
                        gpios = <&pio 4 15 GPIO_ACTIVE_LOW>;
                };
                led1_blue {
                        label = "led1:blue";
                        gpios = <&pio 4 4 GPIO_ACTIVE_LOW>;

                        /* Blink LED at 2 Hz (250 ms on, off) */
                        linux,default-trigger = "timer";
                        default-state = "on";
                        led-pattern = <250 250>;
                };
                led2_red {
                        label = "led2:red";
                        gpios = <&pio 4 5 GPIO_ACTIVE_LOW>;
                };
                led2_green {
                        label = "led2:green";
                        gpios = <&pio 4 14 GPIO_ACTIVE_LOW>;
                };
                led2_blue {
                        label = "led2:blue";
                        gpios = <&pio 4 7 GPIO_ACTIVE_LOW>;
                };
        };
};
```

### Morse code

Sending Morse code accurately requires a higher kernel timer resolution than
what may ship in the stock Nerves system for your target. It is recommended to
set `CONFIG_HZ_1000=y`.

## License

```text
Copyright (C) 2022 SmartRent

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
```
