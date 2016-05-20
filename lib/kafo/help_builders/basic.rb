# encoding: UTF-8

module Kafo
  module HelpBuilders
    class Basic < Base
      def add_module(name, items)
        data = by_parameter_groups(except_resets(items))
        add_list(module_header(name), data['Basic'])
      end

      private

      def except_resets(items)
        items.select { |i| !i.help.first.strip.start_with?('--reset-') || !i.help.last.strip.end_with?('to the default value') }
      end
    end
  end
end
