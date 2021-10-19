# frozen_string_literal: true

require "active_support/core_ext/string/indent"
require_relative "helpers/rubocop_helpers"

module ERBLint
  module Linters
    # Migrates from `Primer::BlankslateComponent` to `Primer::Beta::Blankslate`.
    class BlankslateApiMigration < Linter
      include ERBLint::LinterRegistry
      include Helpers::RubocopHelpers

      def run(processed_source)
        processed_source.ast.descendants(:erb).each do |erb_node|
          _, _, code_node = *erb_node
          code = code_node.children.first.strip

          next unless code.include?("Primer::BlankslateComponent")
          # Don't fix custom blankslates
          next if code.end_with?("do")

          line = erb_node.loc.source_line
          indent = line.split("<%=").first.size

          ast = erb_ast(code)
          kwargs = ast.arguments.first.arguments.last

          replacement = build_replacement_blankslate(kwargs, indent)

          add_offense(processed_source.to_source_range(erb_node.loc), "`Primer::BlankslateComponent` is deprecated. `Primer::Beta::Blankslate` should be used instead", replacement)
        end
      end

      def autocorrect(_, offense)
        return unless offense.context

        lambda do |corrector|
          corrector.replace(offense.source_range, offense.context)
        end
      end

      private

      def build_blankslate_arguments(kwargs)
        new_blankslate = {
          arguments: {},
          slots: {
            title: {},
            graphic: {},
            description: {},
            button: {},
            link: {}
          }
        }

        kwargs.pairs.each do |pair|
          source_value = pair.value.source

          case pair.key.value.to_sym
          when :title
            new_blankslate[:slots][:title][:content] = pair.value.value
          when :title_tag
            new_blankslate[:slots][:title][:tag] = source_value
          when :icon
            new_blankslate[:slots][:graphic][:__polymorphic_type] = :icon
            new_blankslate[:slots][:graphic][:icon] = source_value
          when :icon_size
            new_blankslate[:slots][:graphic][:__polymorphic_type] = :icon
            new_blankslate[:slots][:graphic][:size] = source_value
          when :image_src
            new_blankslate[:slots][:graphic][:__polymorphic_type] = :image
            new_blankslate[:slots][:graphic][:src] = source_value
          when :image_alt
            new_blankslate[:slots][:graphic][:__polymorphic_type] = :image
            new_blankslate[:slots][:graphic][:alt] = source_value
          when :description
            new_blankslate[:slots][:description][:content] = pair.value.value
          when :button_text
            new_blankslate[:slots][:button][:content] = pair.value.value
          when :button_url
            new_blankslate[:slots][:button][:href] = source_value
          when :button_classes
            new_blankslate[:slots][:button][:classes] = source_value
          when :link_text
            new_blankslate[:slots][:link][:content] = pair.value.value
          when :link_url
            new_blankslate[:slots][:link][:href] = source_value
          else
            new_blankslate[:arguments][pair.key.source] = source_value
          end
        end

        new_blankslate
      end

      def build_replacement_blankslate(kwargs, indent)
        data = build_blankslate_arguments(kwargs)
        component_args = args_to_s(data[:arguments])

        # No slots
        return "<%= Primer::Beta::Blankslate.new#{component_args} %>" unless data[:slots].values.any?(&:present?)

        slots = data[:slots].map do |slot, slot_data|
          next if slot_data.empty?

          slot_args = args_to_s(slot_data.except(:content))
          content = slot_data[:content]

          if content
            <<~HTML.indent(2)
              <% c.#{slot}#{slot_args} do %>
                #{content}
              <% end %>
            HTML
          else
            "  <% c.#{slot}#{slot_args} %>"
          end
        end.compact.join("\n").chomp

        # Body needs to match the file indentation.
        body = <<~HTML.indent(indent).chomp
          #{slots}
          <% end %>
        HTML

        # The render call will always be aligned.
        "<%= Primer::Beta::Blankslate.new#{component_args} do |c| %>\n#{body}"
      end

      def args_to_s(args)
        string_args = args.except(:__polymorphic_type).map { |k, v| "#{k}: #{v}" }.join(", ")

        string_args = ":#{args[:__polymorphic_type]}, #{string_args}" if args[:__polymorphic_type]

        return string_args if string_args.blank?

        "(#{string_args})"
      end
    end
  end
end
