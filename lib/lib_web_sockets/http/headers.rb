module LibWebSockets
  module HTTP

    class Headers

      include Enumerable

      def initialize
        @elements = []
        @values = {}
      end

      def self.[](headers)
        h = new
        if headers.kind_of? Hash
          headers.each_pair {|n,v| h.add n, v}
        elsif headers.kind_of? Array
          headers.each {|(n,v)| h.add n, v}
        el
          raise TypeError, "can't convert #{headers} into #{name}"
        end
        h
      end

      def add(name, value)
        value = value.to_s
        @elements << [name, value]
        key = name.downcase
        @values[key] = @values[key] ? @values[key]+","+value : value
      end

      def get(name)
        @values[name.downcase]
      end
      alias_method :[], :get

      def set(name, value)
        key = name.downcase
        @elements.reject! {|(n, v)| n.downcase == key}
        add name, value
      end
      alias_method :[]=, :set

      def has_key?(key)
        return false unless key.kind_of? String
        @values.has_key? key.downcase
      end

      # for Enumerable
      def each(&block)
        @elements.each &block
      end

      def to_s
        s = ""
        @elements.each do |(name, value)|
          s << "#{name}: #{value}\r\n"
        end
        s
      end

    end

  end
end