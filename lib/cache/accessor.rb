module Cache
  module Accessor
    def self.included(a_module)
      a_module.module_eval do
        extend ClassMethods
      end
    end

    module ClassMethods
      def fetch(keys, options = {}, &block)
        case keys
        when Array
          keys = keys.collect { |key| cache_key(key) }
          hits = repository.get_multi(keys)
          if (missed_keys = keys - hits.keys).any?
            missed_values = block.call(*missed_keys)
            hits.merge!(Hash[*missed_keys.zip(Array(missed_values)).flatten])
          end
          hits
        else
          repository.get(cache_key(keys), options[:raw]) || (block ? block.call : nil)
        end
      end

      def get(keys, options = {:ttl => 1.day}, &block)
        case keys
        when Array
          fetch(keys, options, &block)
        else
          fetch(keys, options) do
            if block_given?
              add(keys, result = yield, options[:ttl])
              result
            end
          end
        end
      end

      def add(key, value, ttl)
        repository.add(cache_key(key), value, ttl)
      end

      def set(key, value, ttl = 0)
        repository.set(cache_key(key), value, ttl)
      end

      def incr(key, delta = 1)
        repository.incr(cache_key(key), delta) || begin
          repository.set(cache_key(key), 0)
          repository.incr(cache_key(key), x = yield)
        end
      end

      def decr(key, delta = 1)
        repository.decr(cache_key(key), delta) || begin
          repository.set(cache_key(key), 0)
          repository.incr(cache_key(key), yield)
        end
      end

      def expire(key)
        repository.delete(cache_key(key))
      end

      def cache_key(postfix)
        "#{name}/#{postfix.gsub(' ', '+')}"
      end
    end
  end
end
