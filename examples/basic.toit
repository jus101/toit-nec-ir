import gpio
import nec-ir
import log

main:
  log.set-default (log.default.with-level log.INFO-LEVEL)
  tx-pin := gpio.Pin.out 17
  tx := nec-ir.Transmitter tx-pin

  rx-pin := gpio.Pin.out 18
  rx := nec-ir.Receiver rx-pin

  while 1:
    rx.start-reading
    tx.send 10 100
    rx.read
    sleep --ms=2000