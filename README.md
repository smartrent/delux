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

This library is primarily intended for devices with 1 to 10 LEDs. It's
currently not for Neopixels and other "smart" LEDs that are more typically
found in larger numbers, but could be used for a similar purpose.

Before diving in, some terminology is needed:

* LED - one light emitting element. This doesn't have to be an LED, but the
  Linux kernel must think that it is and show a directory for it under
  `/sys/class/leds/`.
* Indicator - a group of 1, 2, or 3 LEDs that a user would perceive as one.
  This could be a lone green LED, or a red, green and blue LED in one package,
  or any combination.
* Program - a one-time or repeating set of instructions for controlling an
  indicator.
* Pattern - a low-level sequence of brightness and duration tuples for
  controlling one LED
* Slot - a holder for a program. Slots are ordered so a program put in a higher
  priority slot will take precedence over one in a lower priority slot. For
  example, if there's a UI feedback slot and a network status slot, programs
  running in the UI feedback slot could take precedence.

To give a flavor of how `delux` works, here's an example that configures
`delux` with one green LED and then blinks it at 2 Hz:

```elixir
iex> Delux.start_link(indicators: %{default: %{green: "led0"}})
iex> Delux.render(Delux.Effects.blink(:green, 2))
iex> Delux.info()
green at 2 Hz
```

This starts Delux with one indicator, `:default`, that has a green LED known to
Linux as `"led0"`. The `Delux.Effects.blink/2` function creates a 2 Hz blinking
program for Delux to render. With nothing else specified, `Delux.render/1` runs
the program on the default indicator in the default slot.

<!-- MODULEDOC -->

## Built-in indicator programs

`delux` comes with helper functions for creating LED programs. It's also
possible to create your own. Here are the built-in ones:

| Function                    | Description  |
| --------------------------- | ------------ |
| `Delux.Effects.off/0`       | Turn an indicator off |
| `Delux.Effects.on/2`        | Set the indicator to the specified color (within reason, that is. You can't make a green LED red, for example.) |
| `Delux.Effects.blink/3`     | Blink a color on and off at a fixed rate |
| `Delux.Effects.number_blink/3` | Blink the indicator the specified number of times |
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
If you just have one indicator, call it `:default`. That will make `delux`'s
API more convenient.

Step 2 is to decide what slots make sense for your application. Only one
program per indicator can be run at a time. Every time that you set a program
on an indicator, it replaces any running programs for that indicator in that
slot. The default list of slots probably suffice to start:

* `:status` - The lowest priority slot. This is for general device status like
  whether networking is working and if the device is initializing and connected
  to the back end.
* `:notification` - This is a medium priority slot. Use it to show transient
  things like an alert that requires operator attention to clear.
* `:user_feedback` - This is the highest priority slot and for showing feedback
  to a user. For example, it could blink the LED when user pushes a button so
  they know that the device is doing something.

Clearing the program in a slot makes `delux` render the program on the next
lower priority slot or if there's no program, then the indicator is turned off.

> #### Tip {: .tip}
>
> If you find yourself creating state machines in your code to control the
> indicators, try adding one or more slots as an alternative.

Once you feel good about the indicators and slots, it's time to configure
`delux`.

## Configuration

After adding `delux` to your mix dependencies, you can either add `Delux` to a
supervision tree of your choice or add a `:delux` configuration to your
application environment (`config.exs`). The tradeoff is that having `Delux`
start itself by specifying an application config can be really convenient, but
adding `Delux` to your supervision tree allows runtime configuration and more
control over failure recovery.

Starting with the supervision tree approach, here's an example child
specification:

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

Other options include setting the list of slots and giving the `Delux` GenServer
a name. If you don't give the `Delux` GenServer a name, it will register itself
as a singleton and you won't have to pass the server name or pid to any of the
API calls.

If you'd like Delux to start itself automatically, add the configuration to your
`config.exs` or a file that it includes. Here's an example:

```elixir
config :delux,
   indicators: %{
     default: %{red: "led0:red", green: "led0:green", blue: "led0:blue"},
     indicator2: %{red: "led1"}
   }}
```

## Use

For sake of example, let's start the `Delux` GenServer the manual way by calling
`start_link/1` directly. Modify the LED names to whatever you have.

```elixir
iex> Delux.start_link(indicators: %{
     default: %{red: "led0:red", green: "led0:green", blue: "led0:blue"},
     indicator2: %{red: "led1"}
   })
```

After you have a `Delux` GenServer and running, call `Delux.render/1` to turn on
the default indicator in the default slot:

```elixir
iex> Delux.render(Delux.Effects.on(:white))
:ok
```

Even if you don't have an RGB indicator, passing `:white` should turn on all of
the LEDs that you do have.

If you have two indicators and want them to blink back and forth, you can try
this:

```elixir
iex> Delux.render(%{
    default: Delux.Effects.cycle([:black, :white], 1),
    indicator2: Delux.Effects.cycle([:white, :black], 1)
  })
:ok
```

Finally, pass a second parameter to `Delux.render/2` to assign the programs to
another slot.

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
integer depends on the maximum brightness value for an LED. This is often just
1 since Linux can only turn the LED off and on. Sometimes Linux can set the LED
to multiple levels and in those cases, the maximum value will be greater than 1
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

## Timing precision

The Linux kernel's `HZ` configuration sets the granularity at which Delux can
render patterns. For example, if `HZ=100`, the timing resolution is 10 ms. The
kernel also adds a start delay for any pattern. Delux can compensate for both
effects to more accurately render programs. This is ultimately limited to the
timer resolution so if the system only supports 10 ms resolution, that's the
best that Delux can do.

Delux can't automatically detect the `HZ` setting so it must be told via the
`:backend` options:

```elixir
Delux.start_link(backend: [hz: 100], indicators: %{default: %{green: "led0"}})
```

If you need better resolution, you'l need to update the Linux kernel
configuration with `CONFIG_HZ=1000` and rebuild. Be sure to update the `:hz`
value passed to `Delux` so that the compensation is calculated correctly.

To verify timing, connect a logic analyzer to an LED controlled by Delux and
run this:

```elixir
Delux.render(Delux.Effects.timing_test(:on))
```

See `Delux.Effects.timing_test/2` for details on what you should see.

## Linux kernel configuration

`delux` works in all official Nerves systems. If not using Nerves, you will
need to have `CONFIG_LEDS_TRIGGER_PATTERN=y` enabled your Linux kernel
configuration.

The second step to using Linux's LED subsystem is to configure LEDs in the
device tree. You can't just use an arbitrary GPIO to turn on the LED like you
can with `Circuits.GPIO`. Linux needs to know about the GPIO. It's also
possible to hook up PWMs and LED drivers. See the [LED
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
