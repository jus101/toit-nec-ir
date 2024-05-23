// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import gpio
import rmt
import .nec-ir
import log

class Transmitter:
  pin_      /gpio.Pin
  channel_  /rmt.Channel
  logger_   /log.Logger

  constructor pin/gpio.Pin channel-id/int=1 --logger/log.Logger=(log.default.with_name "ir-nec:tx"):
    pin_ = pin
    pin_.configure --output=true
    channel_ = rmt.Channel --output pin_
      --channel-id=channel-id
      --idle-level=0
      --clk-div=CLK-DIV
      --carrier-frequency-hz=CARRIER-FREQ
      --carrier-duty-percent=CARRIER-DUTY
      --enable-carrier=CARRIER-ENABLE

    logger_ = logger
    

  set-signal-bit_ signals /rmt.Signals index /int bit /int -> rmt.Signals:
    i := index * 2
    signals.set i --level=1 --period=(bit == 0 ? HIGH-PULSE-TICKS : LOW-PULSE-TICKS)
    signals.set i+1 --level=0 --period=(bit == 0 ? HIGH-SPACE-TICKS : LOW-SPACE-TICKS)
    return signals

  set-signal-byte_ signals /rmt.Signals index /int byte /int -> rmt.Signals:
    for i := 0; i < 8; i++:
      bit := (byte >> i & 1)
      set-signal-bit_ signals index+i bit
    return signals

  set-signal-header_ signals /rmt.Signals -> rmt.Signals:
    signals.set 0 --level=1 --period=HEADER-PULSE-TICKS
    signals.set 1 --level=0 --period=HEADER-SPACE-TICKS
    return signals

  set-signal-address_ signals /rmt.Signals address /int -> rmt.Signals:
    set-signal-byte_ signals PACKET-ADDRESS-OFFSET address

    inv-address := address ^ 0xFF
    set-signal-byte_ signals PACKET-INV-ADDRESS-OFFSET inv-address

    return signals
  
  set-signal-command_ signals /rmt.Signals command /int -> rmt.Signals:
    set-signal-byte_ signals PACKET-COMMAND-OFFSET command

    inv-address := command ^ 0xFF
    set-signal-byte_ signals PACKET-INV-COMMAND-OFFSET inv-address
    
    return signals

  set-signal-eom_ signals /rmt.Signals -> rmt.Signals:
    signals.set PACKET-EOM-OFFSET*2 --level=1 --period=EOM-PULSE-TICKS
    return signals
  
  send address/int command/int:
    size /int := (PACKET-SIGNAL-SIZE * 2)
    signals := rmt.Signals size

    logger_.debug "send" --tags={"address":address, "command":command, "signals.size":size}

    set-signal-header_ signals
    set-signal-address_ signals address
    set-signal-command_ signals command
    set-signal-eom_ signals

    channel_.write signals
    
