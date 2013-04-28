# encoding: utf-8

# before we require all of the subclasses, we need to have Stream defined
module Frappuccino
  class Stream
  end
end

require 'frappuccino/source'
require 'frappuccino/inject'

require 'frappuccino/stream/map'
require 'frappuccino/stream/select'
require 'frappuccino/stream/zip'

def not_implemented(m, message)
  define_method m do |*args, &blk|
    raise NotImplementedError, "##{m} is not supported, because #{message}."
  end
end

module Frappuccino
  class Stream
    include Observable

    def initialize(*sources)
      sources.each do |source|
        source.extend(Frappuccino::Source).add_observer(self)
      end

      @count = 0
    end

    def update(event)
      occur(event)
    end

    def count(*args)
      if args.count != 0
        raise NotImplementedError, "The argument form of #count is not supported, because streams don't save history."
      end

      if block_given?
        raise NotImplementedError, "The block form of #count is not supported, because streams don't save history."
      end

      @count
    end

    not_implemented(:cycle, "it relies on having a end to the Enumerable")
    not_implemented(:all?,  "it needs a stream that terminates.")
    not_implemented(:chunk, "it needs a stream that terminates.")
    not_implemented(:any?,  "it could resolve to ⊥. You probably want #select")
    not_implemented(:find,  "it could resolve to ⊥. You probably want #select")

    alias :detect :find

    def map(&blk)
      Map.new(self, &blk)
    end
    alias :collect :map

    def map_stream(hsh)
      Map.new(self) do |event|
        if hsh.has_key?(event)
          hsh[event]
        else
          hsh[:default]
        end
      end
    end

    def inject(start, &blk)
      Inject.new(self, start, &blk)
    end

    def select(&blk)
      Select.new(self, &blk)
    end

    def zip(stream)
      Zip.new(self, stream)
    end

    def on_value(&blk)
      callbacks << blk
    end

    def self.merge(stream_one, stream_two)
      new(stream_one, stream_two)
    end

    protected

    def occur(value)
      callbacks.each do |callback|
        callback.call(value)
      end

      @count += 1

      changed
      notify_observers(value)
    end

    def callbacks
      @callbacks ||= []
    end
  end
end
