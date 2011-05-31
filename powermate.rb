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

  REQUEST_TYPE = 0x41
  REQUEST = 0x01

  EV_KEY = 0x01
  EV_REL = 0x02
  EV_ABS = 0x03
  EV_MSC = 0x04
  EV_LED = 0x11
  MSC_PULSELED = 0x01

  class << self
    def find_device
      USB.devices.each do |device|
        if device.idVendor == VENDOR_ID and
            (device.idProduct == PRODUCT_ID_NEW or
             device.idProduct == PRODUCT_ID_OLD)
          return device
        end
      end
    end
  end

  def initialize(device = nil)
    @device = device || PowerMate::find_device
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

  def brightness=(value)
    value = 0 if value < 0
    value = 255 if value > 255
    @brightness = value
    send_control_msg(SET_STATIC_BRIGHTNESS, @brightness)
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

  def pulse_speed=(speed, table=0)
    speed = 0 if speed < 0
    speed = 510 if speed > 510
    @pulse_speed = speed

    op, arg = extract_pulse_params(@pulse_speed)
    send_control_msg((pulse_table << 8) | SET_PULSE_MODE, (arg << 8) | op)
  end

  def pulse_asleep=(value)
    @pulse_asleep = value ? true : false
    send_control_msg(SET_PULSE_ASLEEP, pulse_asleep ? 1 : 0)
  end
  
  def pulse_awake=(value)
    @pulse_awake = value ? true : false
    send_control_msg(SET_PULSE_AWAKE, pulse_awake ? 1 : 0)
  end
  
  attr_reader :handle, :device, :auto_sync, :brightness,
              :pulse_table, :pulse_speed, :pulse_awake, :pulse_asleep

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

  def send_control_msg(value, index, bytes='', timeout=0)
    if connected?
      puts("send #{value}, #{index}")
      handle.usb_control_msg(REQUEST_TYPE, REQUEST, value, index, bytes, timeout)
    end
  end
  
  EVENT_SIZE = 16
  def handle_input_event
    if connected?
      buffer = '0' * 16
      ep = device.endpoints[0].bEndpointAddress
      p ep
      nbytes = handle.usb_bulk_read(ep, buffer, 0)
      p buffer.size
      p nbytes
      p buffer
      if nbytes > 0
        rawevent = buffer.unpack("l!l!s!s!i")
        p rawevent
      end
    end
  end
  
  public :handle_input_event
end
