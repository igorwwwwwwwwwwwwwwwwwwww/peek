require 'test_helper'
require 'peek/adapters/redis'

describe Peek::Adapters::Redis do
  class DummyView < Peek::Views::View
    def parse_options
      @value = @options[:value] || 'value'
    end

    def results
      { key: @value }
    end
  end

  before do
    @redis = ::Redis.new
    @request_id = 'dummy_request_id'
    @redis_key = "peek:requests:#{@request_id}"

    Peek.reset
    @redis.del(@redis_key)
  end

  describe "get" do
    before do
      @adapter = Peek::Adapters::Redis.new({ client: @redis })
    end

    it "should return nil by default" do
      assert_nil @adapter.get(@request_id)
    end

    it "should return an empty result from an empty save" do
      @adapter.save(@request_id)
      assert_equal '{"context":{},"data":{}}', @adapter.get(@request_id)
    end

    it "should return an dummy result" do
      Peek.into DummyView
      @adapter.save(@request_id)
      assert_equal '{"context":{},"data":{"dummy-view":{"key":"value"}}}', @adapter.get(@request_id)
    end
  end

  describe "compress" do
    before do
      @adapter = Peek::Adapters::Redis.new({ client: @redis, compress: true })
    end

    it "should leave small values uncompressed" do
      Peek.into DummyView
      @adapter.save(@request_id)
      assert_equal '{"context":{},"data":{"dummy-view":{"key":"value"}}}', @adapter.get(@request_id)

      assert_equal '{"context":{},"data":{"dummy-view":{"key":"value"}}}', @redis.get(@redis_key)
    end

    it "should compress large values" do
      large_value = 'value:'*1024
      expected = {context:{}, data: {'dummy-view' => {key: large_value}}}

      Peek.into DummyView, value: large_value
      @adapter.save(@request_id)
      assert_equal expected.to_json, @adapter.get(@request_id)

      assert @redis.get(@redis_key)
      assert @redis.get(@redis_key).bytesize < 1024
      assert_equal 0x78, @redis.get(@redis_key).bytes[0].ord
    end

    it "should decompress compressed values even if compression is false" do
      large_value = 'value:'*1024
      expected = {context:{}, data: {'dummy-view' => {key: large_value}}}

      Peek.into DummyView, value: large_value
      @adapter.save(@request_id)
      assert_equal expected.to_json, @adapter.get(@request_id)

      assert @redis.get(@redis_key)
      assert @redis.get(@redis_key).bytesize < 1024
      assert_equal 0x78, @redis.get(@redis_key).bytes[0].ord

      @adapter = Peek::Adapters::Redis.new({ client: @redis, compress: false })
      assert_equal expected.to_json, @adapter.get(@request_id)
    end
  end
end
