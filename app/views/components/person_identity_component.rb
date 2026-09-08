class PersonIdentityComponent < ApplicationViewComponent
  option :name
  option :subtitle, optional: true
  option :size, default: -> { :normal }

  style do
    base { %w[person-identity] }
    variants do
      size do
        normal { [] }
        large { %w[person-identity-large] }
      end
    end
  end

  def initials
    name.to_s.split.filter_map { |part| part[/[[:alpha:]]/] }.first(2).join.upcase.presence || "C"
  end
end
