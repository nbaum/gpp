require 'strscan'

module GPP
  class Processor < StringScanner

    attr_reader :path, :trace

    def initialize (in_, out, path, offset, defs = {}, trace = [])
      super(in_)
      @out = out
      @defs = defs.to_h
      @path = path
      @offset = offset
      @trace = trace
    end

    def loopcat (into = "")
      loop do
        val = yield
        break unless val
        into << val
      end
      into
    end

    def scan_block
      loopcat do
        if scan(/{/)
          "{" + scan_block + "}"
        elsif scan(/}/)
          nil
        else
          scan(/[^{}]+/)
        end
      end
    end

    def scan_string
      loopcat do
        if scan(/"/)
          nil
        else
          scan(/\\?.|[^"\\]/)
        end
      end
    end

    def indent_block (block, indent)
      block.gsub(/^\n/, "").gsub(/\n$/, "").gsub("\n", "\n#{indent}")
    end

    def undent_block (block)
      indent = block[/\A\n[ \t]+/]
      indent ? block.gsub(/#{indent}/, "\n") : block
    end

    def scan_arg (bare = /\S+/)
      if scan(/{/)
        undent_block(scan_block())
      elsif scan(/"/)
        scan_string()
      else
        scan(bare)
      end
    end

    def scan_args
      if scan(/\(/)
        scan(/[ \t]+/)
        loopcat [scan_arg(/[^,)]*/)] do
          if scan(/\)/)
            nil
          elsif scan(/,/)
            scan(/[ \t]+/)
            scan_arg(/[^,)]*/)
          end
        end
      else
        loopcat [] do
          if scan(/(?=\n)/)
            nil
          else
            scan(/[ \t]+/)
            scan_arg
          end
        end
      end
    end

    def run (string, args, path, line)
      trace = self.trace + [tracer]
      if args == nil
        self.class.new(string, s = "", path, line, @defs, trace).scan_all
      else
        self.class.new(string, s = "", path, line, @defs.merge(args.to_h), trace).scan_all
      end
      s
    end

    Definition = Struct.new(:type, :args, :body, :path, :line)

    def run_macro (id)
      rpos = pos - id.length - 2
      w = string[(string.rindex("\n", rpos) || 0) + 1..rpos][/[ \t]+/]
      res = if d = @defs[id]
        case d.type
        when :var
          run(d.body, {}, d.path, d.line)
        when :fun
          args = scan_args.map{|arg| Definition.new(:var, {}, run(arg, {}, path, line), path, line)}
          if d.args[-1] == "..."
            la = d.args.length - 1
            args[la..-1] = Definition.new(:var, {}, args[la..-1].map(&:body).join(" "), args[la].path, args[la].line)
          end
          if args.length != d.args.length
            error "wrong argument count for #{id}: expected #{d.args.length} but got #{args.length}"
          end
          run(d.body, d.args.zip(args), d.path, d.line)
        end
      else
        error "undefined macro: #{id}"
      end
      indent_block(res, w)
    end

    def scan_define
      line = self.line
      name, *args, body = scan_args
      if args == []
        @defs[name] = Definition.new(:var, nil, body, @path, line)
      else
        @defs[name] = Definition.new(:fun, args, body, @path, line)
      end
    end

    def scan_import ()
      args = scan_args
      args.each do |arg|
        run File.read(arg), nil, arg, 1
      end
    end

    def scan_all
      while !eos?
        @out << (scan(/[^#@]+/) || "")
        if scan(/#define\b/)
          scan_define
          scan(/\s+/)
        elsif scan(/#import\b/)
          scan_import
          scan(/\s+/)
        #elsif scan(/#(\w+)/)
        #  error "undefined meta-macro: #{self[1]}"
        elsif scan(/@@/)
          @out << "@"
        elsif scan(/@(\.\.\.|\w+)/)
          @out << (run_macro(self[1]) || "")
        elsif s = scan(/./)
          @out << s
        end
      end
    end

    def line
      @offset + string[0..pos - 1].count("\n")
    end

    def tracer
      [path, line]
    end

    def error (message)
      STDERR.puts "#{message}"
      STDERR.puts " in #{path}:#{line}"
      trace.reverse.each do |path, line|
        STDERR.puts "    #{path}:#{line}"
      end
      exit 1
    end

  end
end
