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
             device.idProduct == PRODUCT_ID_OLD)
          return new(device)
        end
      end
    end

    def find_all
      throw StandardError("Not implemented.")
    end
  end

  def initialize(device)
    @device = device
    @auto_sync = true

    # set initial state arbitary because current device
    # status is unable to be retrieved.
    @brightness = 255
    @pulse_table = 0
    @pulse_speed = 255
    @pulse_asleep = false
    @pulse_awake = false
  end

  def connect
    if block_given?
      begin
        device.open do |handle|
          @handle = handle
          yield self
        end
      ensure
        @handle = nil
      end
    else
      @handle = device.open unless connected?
    end
  end

  def disconnect
    handle.usb_close if connected?
    @handle = nil
  end
    
  def connected?
    @handle != nil
  end

  def auto_sync=(value)
    @auto_sync = value ? true : false
  end

  def brightness=(value)
    value = 0 if value < 0
    value = 255 if value > 255
    @brightness = value
    #send_control_msg(SET_STATIC_BRIGHTNESS, @brightness)
  end

  def pulse
    @pulse_speed = 255
    @pulse_awake = true
  end
  
  def pulse_table=(table)
    table = 0 if table < 0
    table = 2 if table > 2
    @pulse_table = table
  end

  def pulse_speed=(speed)
    speed = 0 if speed < 0
    speed = 510 if speed > 510
    @pulse_speed = speed
    #op, arg = extract_pulse_params(@pulse_speed)
    #send_control_msg(SET_PULSE_MODE, (arg << 8) | op)
  end

  def pulse_asleep=(value)
    @pulse_asleep = value ? true : false
    #send_control_msg(SET_PULSE_ASLEEP, pulse_asleep ? 1 : 0)
  end
  
  def pulse_awake=(value)
    @pulse_awake = value ? true : false
    #send_control_msg(SET_PULSE_AWAKE, pulse_awake ? 1 : 0)
  end
  
  def sync_state
    # packs state in value and index.
    # usb_control_msg(0x41, 0x01, value, index, ...)
    # |--------|--------||--------|--------||--------|--------||--------|--------|
    #        0x41               0x01               value              index    
    # value / index bits are
    #              value                      |    index
    #    awake(1) asleep(1)  pulse_mode(2)  speed(9)  brightness(8)
    #      20       19         18-17         16-8        7-0
    asleep = pulse_asleep ? 1 : 0
    awake = pulse_awake ? 1 : 0
    data = brightness | (pulse_speed << 8) | (pulse_table << 17) |
           (asleep << 19) | (awake << 20)
    value = data >> 16
    index = data & 0xff
    send_control_msg(value, index)
  end

  attr_reader :handle, :device, :auto_sync, :brightness,
              :pulse_table, :pulse_speed, :pulse_awake, :pulse_asleep

  def self.auto_sync_functions(*methods)
    methods.each do |m|
      original = "__original_#{m}"
      alias_method original, m
      private original
      define_method(m) do |*args|
        send(original, *args)
        sync_state if auto_sync
      end
    end
  end

  auto_sync_functions :brightness=, :pulse_table=, :pulse_table=,
                      :pulse_awake=, :pulse_asleep=, :pulse
  
  def send_control_msg(value, index, bytes='', timeout=-1)
    if connected?
      puts("send #{value}, #{index}")
      handle.usb_control_msg(0x41, 0x01, value, index, bytes, timeout)
    end
  end

  private

  def extract_pulse_params(speed)
    case speed
    when 0..254
      op = 0
      arg = 255 - speed
    when 255
      op = 1
      arg = 0
    when 256..510
      op = 2
      arg = speed - 255
    end
    return op, arg
  end
end
