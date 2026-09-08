class FormRevealComponent < ApplicationViewComponent
  option :label
  option :expanded, default: -> { false }

  style { base { %w[form-reveal] } }
end
