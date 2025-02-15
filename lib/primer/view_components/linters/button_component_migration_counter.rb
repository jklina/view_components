# frozen_string_literal: true

require_relative "base_linter"
require_relative "autocorrectable"
require_relative "argument_mappers/button"

module ERBLint
  module Linters
    # Counts the number of times a HTML button is used instead of the component.
    class ButtonComponentMigrationCounter < BaseLinter
      include Autocorrectable

      TAGS = Primer::ViewComponents::Constants.get(
        component: "Primer::BaseButton",
        constant: "TAG_OPTIONS"
      ).freeze

      # CloseButton component has preference when this class is seen in conjuction with `btn`.
      DISALLOWED_CLASSES = %w[close-button].freeze
      CLASSES = %w[btn btn-link].freeze
      MESSAGE = "We are migrating buttons to use [Primer::ButtonComponent](https://primer.style/view-components/components/button), please try to use that instead of raw HTML."
      ARGUMENT_MAPPER = ArgumentMappers::Button
      COMPONENT = "Primer::ButtonComponent"
    end
  end
end
