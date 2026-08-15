module DailyFeed
  Result = Data.define(:needs_attention, :later_today, :coming_up) do
    def items
      needs_attention + later_today + coming_up
    end

    def empty?
      items.empty?
    end

    def find(item_key)
      items.find { |item| item.key == item_key }
    end
  end
end
