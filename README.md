# NEC IR

This is a package containing A basic implementation of the IR NEC protocol using the Toit RMT standard library.

Encode, transmit, receive, and decode IR pulses using the standard RMT library and the #[NEC IR protocol](https://www.digikey.com/en/maker/tutorials/2021/understanding-the-basics-of-infrared-communications#:~:text=The%20NEC%20IR%20transmission%20protocol&text=The%20standard%20NEC%20protocol%20uses,distinguish%20between%20HIGH%20and%20LOW.&text=Binary%20values%20are%20encoded%20as,a%201.687%20ms%20low%20period).

The NEC IR protocol lets you send/receive just two bytes: `address` and `command`.

*Note:* The code in this package isn't well tested (other than sending various numbers back and forth), so expect bugs and most likely less than ideal performance. It'd be great to have a robust IR package for Toit (that supports other protocols too) - if you find any bugs or have suggestsions, please create an issue or a pull-request!

## Setup

To transmit: Connect an IR LED (with a suitable resistor) to a GPIO pin on your ESP32.
To receive: Connect an IR receiver with the signal pin connected to a GPIO pin on your ESP32. Most receivers have 3 pins: 3.3V, signal, and ground.

*Tip:* For testing purposes you can just hook up the receiver and the transmitter on the same board using different GPIO pins.

## Usage

The library provides two classes `Transmitter` and `Receiver`.
Both constructors expect a `gpio.Pin` as the first argument. The pin is configured in the class constructor.

Use `Transmitter.send --address=10 --command=100` to send data.
Use `Receiver.read` to listen for IR signals. This method returns a `ByteArray` with two bytes when a signal is successfully received and decoded.

## Debugging
You can enable verbose debug level logging by passing in a `log.Log` instance to the `--logger` argument on `Transmitter` and `Reciever`. You can also change the default logger level - see example below.

## Example
Connect your IR LED (positive lead) to GPIO 17 and the signal pin of your IR receiver to pin 18.

```
import gpio
import ..src.transmitter
import ..src.receiver
import log

main:
  log.set-default (log.default.with-level log.INFO-LEVEL)
  tx-pin := gpio.Pin.out 17
  tx := Transmitter tx-pin

  rx-pin := gpio.Pin.out 18
  rx := Receiver rx-pin

  while 1:
    rx.start-reading
    tx.send 10 100
    rx.read
    sleep --ms=2000
```