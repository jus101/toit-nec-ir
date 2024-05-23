// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import gpio
import rmt
import .nec-ir
import log

class Receiver:
  pin_      /gpio.Pin
  channel_  /rmt.Channel
  logger_   /log.Logger

  constructor pin/gpio.Pin channel-id/int=5 --logger/log.Logger=(log.default.with_name "ir-nec:rx"):
    pin_ = pin
    pin_.configure --input=true
    channel_ = rmt.Channel --input pin_
      --channel-id=channel-id
      --clk-div=CLK-DIV
      --idle-threshold=IDLE-THRESHOLD-TICKS
      --filter-ticks-threshold=FILTER-TICKS-THRESHOLD
      --enable-filter=true
      --buffer-size=RX-BUFFER-SIZE

    logger_ = logger
    
  validate-header_ signals/rmt.Signals -> bool:
    pulse := signals.period 0
    space := signals.period 1

    return
      (signals.level 0) == 0
        and (HEADER-PULSE-TICKS - RX-TOLERANCE-TICKS) < pulse
        and (HEADER-PULSE-TICKS + RX-TOLERANCE-TICKS) > pulse
        and (signals.level 1) == 1
        and (HEADER-SPACE-TICKS - RX-TOLERANCE-TICKS) < space
        and (HEADER-SPACE-TICKS + RX-TOLERANCE-TICKS) > space

  match_ val/int --to/int --tolerance /int=RX-TOLERANCE-TICKS -> bool:
    return (to - tolerance) < val 
      and (to + tolerance) > val

  read-bit_ signals /rmt.Signals offset /int -> int?:
    index := offset * 2
    pulse-level := signals.level index
    pulse-period := signals.period index
    space-level := signals.level index+1
    space-period := signals.period index+1

    if pulse-level != 0:
      logger_.debug "read-bit_: Unexpected bit level (1)" --tags={"offset":offset}
      return null
    
    is-high-pulse := match_ pulse-period --to=HIGH-PULSE-TICKS
    is-high-space := match_ space-period --to=HIGH-SPACE-TICKS
    is-low-pulse := match_ pulse-period --to=LOW-PULSE-TICKS
    is-low-space := match_ space-period --to=LOW-SPACE-TICKS

    if is-high-pulse and is-high-space: return 0
    if is-low-pulse and is-low-space: return 1

    return null

  read-byte_ signals /rmt.Signals offset /int --invert /bool=false -> int?:
    val := 0
    for i := 7; i >= 0; i--:
      bit := read-bit_ signals offset+i
      if bit == null: return null
      val = (val << 1) | bit;
    if invert: val = val ^ 0xFF
    return val
  
  parse_ signals /rmt.Signals -> ByteArray?:
    if signals.size < PACKET-SIGNAL-SIZE * 2:
      logger_.debug "parse_: signal size less than expected packet size" --tags={"signals.size":signals.size, "PACKET-SIGNAL-SIZE":PACKET-SIGNAL-SIZE*2}
      return null

    if not validate-header_ signals:
      logger_.debug "parse_: Invalid signal header"
      return null

    address := read-byte_ signals PACKET-ADDRESS-OFFSET
    command := read-byte_ signals PACKET-COMMAND-OFFSET
    inv-address := read-byte_ signals PACKET-INV-ADDRESS-OFFSET --invert=true
    inv-command := read-byte_ signals PACKET-INV-COMMAND-OFFSET --invert=true

    if address == inv-address and command == inv-command:
      logger_.info "parse_: success" --tags={"address":address, "command":command}
      return #[address, command]
    else:
      logger_.warn "parse_: fail" --tags={
        "address":address,
        "inv-address":inv-address,
        "command":command,
        "inv-command":inv-command
      }
      
    return null
  
  start-reading:
    channel_.start-reading

  read -> ByteArray?:
    logger_.debug "read: start"
    signals := channel_.read
    channel_.stop-reading
    logger_.debug "read: stop"
    return parse_ signals
    
