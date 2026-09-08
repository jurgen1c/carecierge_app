class FormHeadingComponent < ApplicationViewComponent
  option :title

  style do
    base { %w[font-semibold text-ink] }
    variants do
      page do
        yes { %w[text-2xl] }
        no { %w[text-base] }
      end
    end
  end

  def page?
    !helpers.turbo_frame_request? && !helpers.request.format.turbo_stream?
  end

  def before_render
    helpers.content_for(:title, title) if page?
  end
end
