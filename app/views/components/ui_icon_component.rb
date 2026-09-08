class UiIconComponent < ApplicationViewComponent
  option :name

  PATHS = {
    today: "M3 10 12 3l9 7v11h-6v-7H9v7H3Z",
    people: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M16 4a4 4 0 0 1 0 8M22 21v-2a4 4 0 0 0-3-3.87M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
    reminders: "M9 3h6M12 7v5l3 2M21 13a9 9 0 1 1-18 0 9 9 0 0 1 18 0",
    plans: "M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2M7 14h3M14 14h3M7 18h3",
    shared: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0M20 7v6M17 10h6",
    reviews: "m5 12 4 4L19 6M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11",
    explore: "m16 8-3 5-5 3 3-5ZM22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0",
    settings: "M4 6h16M4 12h16M4 18h16M8 3v6M16 9v6M10 15v6",
    activity: "M3 12h4l3-8 4 16 3-8h4",
    privacy: "m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6ZM9 12l2 2 4-4",
    search: "m21 21-5-5M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0",
    plus: "M12 5v14M5 12h14",
    arrow: "M5 12h14m-6-6 6 6-6 6",
    menu: "M4 6h16M4 12h16M4 18h16",
    chevron: "m6 9 6 6 6-6"
  }.freeze

  style { base { %w[size-5 shrink-0] } }

  def path
    PATHS.fetch(name.to_sym)
  end
end
