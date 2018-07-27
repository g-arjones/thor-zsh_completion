class Thor
  module ZshCompletion
    class Generator
      SUBCOMMAND_FUNCTION_TEMPLATE = ERB.new(File.read("#{File.dirname(__FILE__)}/template/subcommand_function.erb"), nil, "-")
      attr_reader :thor, :name

      def initialize(thor, name)
        @thor = thor
        @name = name
      end

      def generate
        main = {
          name: "__#{name}",
          description: nil,
          options: [],
          subcommands: subcommand_metadata(thor)
        }

        subcommand_by_name(main, 'which')[:completer] = '_path_commands'
        subcommand_by_name(main, 'exec')[:completer] = '_path_commands'
        subcommand_by_name(main, 'cache')[:completer] = '_files'
        subcommand_by_name(main, 'bootstrap')[:completer] = ':'
        subcommand_by_name(main, 'envsh')[:completer] = ':'
        subcommand_by_name(main, 'manifest')[:completer] = '_files'
        subcommand_by_name(main, 'reconfigure')[:completer] = ':'
        subcommand_by_name(main, 'query')[:completer] = ':'
        subcommand_by_name(main, 'switch-config')[:completer] = ':'

        subcommand_by_name(main, 'global', 'register')[:completer] = ':'
        subcommand_by_name(main, 'global', 'status')[:completer] = ':'

        subcommand_by_name(main, 'plugin', 'install')[:completer] = ':'
        subcommand_by_name(main, 'plugin', 'list')[:completer] = ':'
        subcommand_by_name(main, 'plugin', 'remove')[:completer] = ':'

        subcommand_by_name(main, 'reset')[:completer] = ':'
        subcommand_by_name(main, 'log')[:completer] = ':'
        # TODO: reset subcommand needs a custom completer, leaving disabled for now
        # TODO: log subcommand needs a custom completer, leaving disabled for now
        # TODO: investigate how to handle 'plugin' subcommands completion, leaving disabled for now

        populate_help_subcommands(main)

        erb = File.read("#{File.dirname(__FILE__)}/template/main.erb")
        ERB.new(erb, nil, "-").result(binding)
      end

      def subcommand_by_name(metadata, *name)
        subcommand = metadata
        name.each do |subcommand_name|
          subcommand = subcommand[:subcommands].find { |s| s[:name] == subcommand_name }
        end
        subcommand
      end

      def populate_help_subcommands(metadata)
        help_subcommand = subcommand_by_name(metadata, 'help')
        if help_subcommand
          help_subcommand[:options] = []
          help_subcommand[:completer] = ':'
        end
        metadata[:subcommands].each do |subcommand|
          next if subcommand[:name] == 'help'
          populate_help_subcommands(subcommand)
          next unless help_subcommand
          help_subcommand[:subcommands] << { name: subcommand[:name],
                                             aliases: [],
                                             description: subcommand[:description],
                                             options: [],
                                             subcommands: [] }
        end
      end


      private
      def render_subcommand_function(subcommand, options = {})
        prefix = options[:prefix] || []

        source = []

        prefix = (prefix + [subcommand[:name]])
        function_name = prefix.join("_")
        depth = prefix.size + 1

        source << SUBCOMMAND_FUNCTION_TEMPLATE.result(binding)

        subcommand[:subcommands].each do |subcommand|
          source << render_subcommand_function(subcommand, prefix: prefix)
        end
        source.join("\n").strip + "\n"
      end

      def subcommand_metadata(thor)
        result = []
        thor.all_commands.select { |_, t| !t.hidden? }.each do |(name, command)|
          aliases = thor.map.select{|_, original_name|
            name == original_name
          }.map(&:first)
          result << generate_command_information(thor, name, command, aliases)
        end
        result
      end

      def generate_command_information(thor, name, command, aliases)
        if subcommand_class = thor.subcommand_classes[name]
          subcommands = subcommand_metadata(subcommand_class)
        else
          subcommands = []
        end

        completer = '_autoproj_installed_packages' if subcommands.empty?
        info = { name: hyphenate(name),
          aliases: aliases.map{|a| hyphenate(a) },
          usage: command.usage,
          description: command.description,
          options: thor.class_options.select{|_, o| !o.hide}.map{|_, o| option_metadata(o) } +
                   command.options.select{|_, o| !o.hide}.map{|(_, o)| option_metadata(o) },
          subcommands: subcommands,
          completer: completer
        }

        # disable options for subcommands that have subcommands
        info[:options] = [] unless subcommands.empty?
        info
      end

      def option_metadata(option)
        names = ["--#{hyphenate(option.name)}"]
        names += ["--no-#{hyphenate(option.name)}"] if option.boolean?
        names += option.aliases.map{|a| "-#{hyphenate(a)}" }

        { names: names,
          description: option.description,
        }
      end

      def quote(s)
        escaped = s.gsub(/'/, "''")
        %('#{escaped}')
      end

      def bracket(s)
        %([#{s}])
      end

      def escape_option_names(names)
        if names.size == 1
          names.first
        else
          "{" + names.join(",") + "}"
        end
      end

      def hyphenate(s)
        s.to_s.gsub("_", "-")
      end
    end
  end
end
