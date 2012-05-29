module LibWebSockets
  module HTTP

    class Headers

      include Enumerable

      def initialize
        @elements = []
        @values = {}
      end

      def self.[](headers)
        case headers
        when Headers
          headers.dup
        when Hash, Arry
          headers.each_with_object(new) {|h,(n,v)| h[n]=v}
        else
          raise TypeError, "can't convert #{headers} into #{name}"
        end
      end

      def add(name, value)
        value = value.to_s
        @elements << [name, value]
        key = name.downcase
        @values[key] = @values[key] ? @values[key]+","+value : value
        self
      end

      def get(name)
        @values[name.downcase]
      end
      alias_method :[], :get

      def set(name, value)
        key = name.downcase
        @elements.reject! {|(n, v)| n.downcase == key}
        add name, value
        value
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