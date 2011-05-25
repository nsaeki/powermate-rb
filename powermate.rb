#!/usr/bin/env ruby
# coding: utf-8
# Ruby interface for Griffin PowerMate.

require 'usb'

class PowerMate
  VENDOR_ID = 0x077d
  PRODUCT_ID_NEW = 0x0410
  PRODUCT_ID_OLD = 0x04AA
  
  SET_STATIC_BRIGHTNESS  = 0x01
  SET_PULSE_ASLEEP       = 0x02
  SET_PULSE_AWAKE        = 0x03
  SET_PULSE_MODE         = 0x04

  class << self
    def find_any
      USB.devices.each do |device|
        if device.idVendor == VENDOR_ID and
            (device.idProduct == PRODUCT_ID_NEW or
             devices.idProduct == PRODUCT_ID_OLD)
          return new(device)
        end
      end
    end

    def find_all
    end
  end

  def initialize(device)
    @device = device
  end

  def connect
    if block_given?
      device.open do |handle|
        @handle = handle
        yield self
      end
    else
      @handle = device.open unless connected?
    end
  end

  def disconnect
    device.close if connected?
    @handle = nil
  end
    
  def connected?
    @handle != nil
  end

  def brightness=(value)
    value = 0 if value < 0
    value = 255 if value > 255
    @brightness = value
    send_control_msg(SET_STATIC_BRIGHTNESS, @brightness)
  end

  def pulse(speed=255)
    speed = 0 if speed < 0
    speed = 510 if speed > 510
    @pulse_speed = speed

    case pulse_speed
    when 0..254
      op = 0
      arg = 255 - pulse_speed
    when 255
      op = 1
      arg = 0
    when 256..510
      op = 2
      arg = pulse_speed - 255
    end
    pulse_table = 0             # 0,1,2 valid
    #send_control_msg((pulse_table << 8) | SET_PULSE_MODE, (arg << 8) | op)
  end
  
  def pulse_asleep=(value)
    @pulse_asleep = value ? true : false
    #send_control_msg(SET_PULSE_ASLEEP, pulse_asleep ? 1 : 0)
  end
  
  def pulse_awake=(value)
    @pulse_awake = value ? true : false
    #send_control_msg(SET_PULSE_AWAKE, pulse_awake ? 1 : 0)
  end
  
  attr_reader :handle, :device, :brightness, :pulse_speed, :pulse_awake, :pulse_asleep

  private

  def sync_state
    # usb_control_msg(int, int, int, int, int, int)
    # |--------|--------||--------|--------||--------|--------||--------|--------|
    #    0x41               0x01               type              value    
    # type, value bits.
    #    blank   awake(1) asleep(1)  pulse_mode(2) speed(8)  brightness(8)
    #    23-21   20       19         18-17         16-8      7-0
    type = value = 0
    #send_control_msg((@pulse_awake ? 1 : 0) << 4, 0)
    send_control_msg(type, value, bytes, timeout)
  end

  def send_control_msg(type, value, bytes='', timeout=-1)
    if connected?
      puts("send #{type}, #{value}")
      handle.usb_control_msg(0x41, 0x01, type, value, bytes, timeout)
    end
  end
end
