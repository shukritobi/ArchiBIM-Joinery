# frozen_string_literal: true
require 'zlib'

module SSDigitalLab
  module ArchiBIMJoinery
    # Plain Ruby, stored ZIP format. No external gem, shell or installed archiver.
    module ReportZip
      extend self
      MAX32=0xffff_ffff

      def encode(entries)
        raise ArgumentError,'Expected a ZIP entry hash' unless entries.is_a?(Hash)
        raise ArgumentError,'Too many diagnostic files' if entries.size>65_535
        local=''.b;central=''.b
        entries.each do |name,value|
          filename=name.to_s.encode('UTF-8').b
          payload=value.to_s.b
          raise ArgumentError,'Unsafe ZIP entry name' if
            filename.empty? || filename.include?('..') || filename.start_with?('/') ||
            filename.include?("\\") || filename.include?("\0")
          raise ArgumentError,'ZIP entries exceed 4GB (ZIP64 unsupported)' if
            payload.bytesize>MAX32 || filename.bytesize>65_535 || local.bytesize>MAX32
          crc=Zlib.crc32(payload)
          size=payload.bytesize
          offset=local.bytesize
          local << [0x04034b50,20,0x800,0,0,0,crc,size,size,filename.bytesize,0].
            pack('VvvvvvVVVvv')
          local << filename << payload
          central << [0x02014b50,20,20,0x800,0,0,0,crc,size,size,
                      filename.bytesize,0,0,0,0,0,offset].
            pack('VvvvvvvVVVvvvvvVV')
          central << filename
        end
        count=entries.size
        central_offset=local.bytesize
        raise ArgumentError,'ZIP archive too large' if central_offset+central.bytesize>MAX32
        local << central
        local << [0x06054b50,0,0,count,count,
                  central.bytesize,central_offset,0].pack('VvvvvVVv')
      end
    end
  end
end
