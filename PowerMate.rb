#!/usr/bin/env ruby
#
# Ruby interface for Griffin PowerMate.

require 'usb'

class PowerMate
  def << self
    VENDOR_ID = 0x077d
    PRODUCT_ID_NEW = 0x0410
    PRODUCT_ID_OLD = 0x04AA
    
    SET_STATIC_BRIGHTNESS  = 0x01
    SET_PULSE_ASLEEP       = 0x02
    SET_PULSE_AWAKE        = 0x03
    SET_PULSE_MODE         = 0x04

    def find_any
    end

    def find_all
    end
  end

  def initialize(device)
    @device = device
  end

  def connect
    if block_given?
      yield self
    else
      @handle = device.open unless connected?
    end
  end

  def disconnect
    device.close if connected?
    @handle = nil
  end
    
  def connected?
    @handle == nil
  end

  def brightness=(value)
    value = 0 if value < 0
    value = 255 if value > 255
    @brightness = value
  end

  def pulse(speed)
    speed = 0 if speed < 0
    speed = 511 if speed > 511
    @pulse_speed = speed
  end
  
  def pulse_asleep=(value)
    @pulse_asleep = value ? true : false
  end
  
  def pulse_awake=(value)
    @pulse_awake = value ? true : false
  end
  
  def sync_state
  end

  attr_reader :device, :brightness, :pulse_speed, :pulse_awake, :pulse_asleep

  private

  def send_ctrl_msg(code, value, data = '', timeout = 0)
    handle.send_control_message() if connected?
  end
end