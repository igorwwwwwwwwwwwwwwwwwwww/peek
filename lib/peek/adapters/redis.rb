require 'peek/adapters/base'
require 'redis'
require 'zlib'

module Peek
  module Adapters
    class Redis < Base
      def initialize(options = {})
        @client = options.fetch(:client, ::Redis.new)
        @expires_in = Integer(options.fetch(:expires_in, 60 * 30))
        @compress = options.fetch(:compress, false)
        @compress_threshold = Integer(options.fetch(:compress_threshold, 1024))
      end

      def get(request_id)
        data = @client.get("peek:requests:#{request_id}")

        # detect compressed value -- 0x78 is the CMF set by zlib
        if data && data.size > 0 && data.bytes[0].ord == 0x78
          data = Zlib::Inflate.inflate(data)
        end

        data
      end

      def save(request_id)
        return false if request_id.blank?

        data = Peek.results.to_json
        if @compress && data.bytesize >= @compress_threshold
          data = Zlib::Deflate.deflate(data)
        end

        @client.setex("peek:requests:#{request_id}", @expires_in, data)
      end
    end
  end
end
