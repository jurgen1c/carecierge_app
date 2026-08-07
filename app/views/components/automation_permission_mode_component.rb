class AutomationPermissionModeComponent < ApplicationViewComponent
  option :name
  option :id_prefix
  option :label
  option :selected_mode
  option :allowed_modes

  style do
    base { %w[grid gap-2] }
    variants do
      columns do
        two { %w[grid-cols-2] }
        three { %w[sm:grid-cols-3] }
      end
    end
    defaults { { columns: :three } }
  end

  style :option do
    base do
      %w[
        flex min-h-11 cursor-pointer items-center justify-center rounded-lg border border-stone-300
        bg-white px-3 py-2 text-center text-xs font-semibold text-stone-700 transition
        hover:bg-stone-50 peer-checked:border-emerald-700 peer-checked:bg-emerald-50
        peer-checked:text-emerald-950 peer-focus-visible:outline peer-focus-visible:outline-2
        peer-focus-visible:outline-offset-2 peer-focus-visible:outline-emerald-700
      ]
    end
  end

  def column_count
    allowed_modes.size == 2 ? :two : :three
  end
end
