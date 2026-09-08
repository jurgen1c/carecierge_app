require "rails_helper"

RSpec.describe "Relationship workspace experience", type: :system do
  let(:now) { Time.zone.local(2026, 9, 7, 16) }
  let(:user) { create(:user, email: "workspace@example.test", onboarding_completed_at: now) }

  around { |example| Timecop.freeze(now, &example) }
  after { page.current_window.resize_to(1280, 800) }

  it "keeps a busy day, a larger circle, and person essentials usable in both languages at every target width" do
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    names = %w[Maya Diego Elena Rosa Gabriel Lucía Camila Mateo Sofía Andrés Valeria Isabel]
    profiles = 28.times.map do |index|
      create(:relationship_profile, user:, first_name: names[index % names.size], last_name: "Rivera #{index + 1}", preferred_name: nil)
    end
    profile = profiles.first
    profile.update!(preferred_name: "Maya")
    profiles.last.update!(preferred_name: "María de los Ángeles Fernández-Solís y su familia")
    create(:interaction, relationship_profile: profile, occurred_at: now - 35.days, notes: "A walk and a good conversation.")
    create(:contact_cadence, relationship_profile: profile, interval_days: 14, created_at: now - 60.days)
    create(:important_date, relationship_profile: profile, title: "Maya's birthday", starts_on: now.to_date + 5.days)
    create(:relationship_note, relationship_profile: profile, private: true, body: "Keep this personal detail out of the directory.")
    create(:gift, relationship_profile: profile, name: "A book of garden walks", status: "idea")
    3.times do |index|
      create(:reminder, user:, relationship_profile: profiles[index], title: "Check in with #{names[index]}", scheduled_at: now - (index + 1).hours)
    end
    create(:reminder, user:, relationship_profile: profile, title: "Call after work", scheduled_at: now + 2.hours)
    create(:reminder, user:, relationship_profile: profile, title: "Arrange coffee next week", scheduled_at: now + 3.days)
    7.times { |index| create(:event_plan, user:, relationship_profile: profiles[index], title: "Time with #{names[index]}", starts_on: now.to_date + index.days) }
    create(:approval_request, user:, subject: create(:extracted_memory, relationship_profile: profile))
    create(:reminder, title: "Another owner's private reminder", scheduled_at: now - 1.hour)
    sign_in user

    [ 320, 390, 768, 1024, 1440, 1920, 2560 ].each do |width|
      page.current_window.resize_to(width, width < 768 ? 844 : 1080)
      %i[en es].each do |locale|
        visit dashboard_path(locale:)
        verify_shell(locale)
        expect(page).to have_css("[data-feed-item]", text: "Check in with Maya")
        expect(page).to have_text(I18n.t("today.moments.preview", count: 4, total: 7, locale:))
        expect(page).to have_text(I18n.t("today.reviews.waiting", count: 1, locale:))
        expect(page).to have_text(I18n.t("today.check_ins.title", locale:))
        expect(page).not_to have_text("Another owner's private reminder")
        expect(page.html).not_to include("Keep this personal detail out of the directory.")
        expect(page).to have_css(".today-ideas [data-feed-item]", text: "A book of garden walks")
        capture("busy-today", width, locale)

        visit relationship_profiles_path(locale:)
        verify_shell(locale)
        expect(page).to have_css("[data-person]", count: 24)
        if width == 390
          expect(page.evaluate_script("document.querySelector('[data-person]').getBoundingClientRect().top")).to be < 650
        end
        expect(page.html).not_to include("Keep this personal detail out of the directory.")
        capture("busy-people", width, locale)

        visit relationship_profile_path(profile, locale:)
        verify_shell(locale)
        expect(page).to have_css(".profile-primary-actions a", count: 3)
        expect(page).to have_no_css("[data-profile-section][open]")
        expect(page).to have_text("Maya's birthday")
        expect(page).to have_css("#profile_overview time")
        capture("busy-profile", width, locale)
      end
    end
  end

  it "supports keyboard navigation, locale persistence, inline validation and a recorded interaction" do
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    sign_in user
    page.current_window.resize_to(390, 844)
    visit dashboard_path
    press_key(".app-menu-trigger", :Enter)
    expect(page).to have_css(".app-mobile-header details[open]")
    find(".app-mobile-navigation a[lang='es']").click
    expect(page).to have_css("html[lang='es']")
    press_key(".app-menu-trigger", :Enter)
    find(".app-mobile-navigation [data-nav-key='people']").click
    expect(page).to have_current_path(relationship_profiles_path(locale: :es))
    click_link "Maya", match: :first
    expect(page).to have_css("html[lang='es']")
    press_key("#profile-moments > summary", :Enter)
    within("#contact_rhythm_section") { click_link I18n.t("contact_rhythm.interactions.log", locale: :es), match: :first }
    within("turbo-frame#new_interaction") do
      expect(page).to have_css("h2")
      click_button I18n.t("contact_rhythm.form.create", locale: :es)
      expect(page).to have_css("[role='alert']")
      select I18n.t("contact_rhythm.interaction_types.call", locale: :es), from: "interaction_interaction_type"
      click_button I18n.t("contact_rhythm.form.create", locale: :es)
    end
    expect(page).to have_text(I18n.t("interactions.create.notice", locale: :es))
    expect(page).to have_css("#profile_overview time")
    expect(profile.interactions.count).to eq(1)
    expect(page).to have_css("main h1", count: 1)
    press_key(".app-menu-trigger", :Enter)
    press_key(".app-menu-trigger", :Escape)
    expect(page).to have_no_css(".app-mobile-header details[open]")
    expect(page.evaluate_script("document.activeElement.matches('.app-menu-trigger')")).to be(true)
    capture("spanish-interaction", 390, :es)
  end

  it "keeps quiet accounts helpful without invented activity" do
    sign_in user
    page.current_window.resize_to(390, 844)
    %i[en es].each do |locale|
      visit dashboard_path(locale:)
      verify_shell(locale)
      expect(page).to have_text(I18n.t("today.agenda.quiet_title", locale:))
      expect(page).to have_no_css("[data-feed-item]")
      capture("quiet-today", 390, locale)
      visit relationship_profiles_path(locale:)
      expect(page).to have_text(I18n.t("people.empty_title", locale:))
      capture("empty-people", 390, locale)
    end
  end

  it "completes the primary profile actions inline in both languages" do
    profile = create(:relationship_profile, user:)
    sign_in user

    %i[en es].each do |locale|
      visit relationship_profile_path(profile, locale:)
      within(".profile-primary-actions") { click_link I18n.t("profile_workspace.record", locale:) }
      within("turbo-frame#new_interaction") do
        select I18n.t("contact_rhythm.interaction_types.call", locale:), from: "interaction_interaction_type"
        click_button I18n.t("contact_rhythm.form.create", locale:)
      end
      expect(page).to have_text(I18n.t("interactions.create.notice", locale:))
      expect(page).to have_no_css("form select[name='interaction[interaction_type]']")
      expect(page).to have_css("#profile_overview time")
      expect(page).to have_current_path(relationship_profile_path(profile, locale:))

      within("#upcoming_important_dates") { click_link I18n.t("profile_workspace.add_date", locale:) }
      within("turbo-frame#new_important_date") do
        fill_in "important_date_starts_on", with: (now.to_date + 5.days).iso8601
        fill_in "important_date_title", with: "A day together #{locale}"
        click_button I18n.t("important_dates.form.create", locale:)
      end
      expect(page).to have_text(I18n.t("important_dates.create.notice", locale:))
      expect(page).to have_no_css("form input[name='important_date[starts_on]']")
      expect(page).to have_css("#upcoming_important_dates", text: "A day together #{locale}")
    end
    expect(profile.interactions.count).to eq(2)
    expect(profile.important_dates.count).to eq(2)
  end

  it "closes the mobile menu when keyboard focus leaves in either direction" do
    sign_in user
    [ 390, 768 ].each do |width|
      page.current_window.resize_to(width, 844)
      %i[en es].each do |locale|
        visit dashboard_path(locale:)
        press_key(".app-menu-trigger", :Enter)
        press_key(".app-mobile-navigation .app-nav-signout", :Tab)
        expect(page).to have_no_css(".app-mobile-menu[open]")
        expect(page.evaluate_script("document.activeElement.closest('main') !== null")).to be(true)
        press_key(".app-menu-trigger", :Enter)
        page.driver.browser.keyboard.type([ :Shift, :Tab ])
        expect(page).to have_no_css(".app-mobile-menu[open]")
        expect(page.evaluate_script("document.activeElement.matches('.app-mobile-header > .app-brand')")).to be(true)
      end
    end
  end

  private

  def press_key(selector, key)
    find(selector)
    page.execute_script("document.querySelector(arguments[0]).focus()", selector)
    page.driver.browser.keyboard.type(key)
  end

  def verify_shell(locale)
    expect(page).to have_css("html[lang='#{locale}']")
    expect(page).to have_css("main", count: 1)
    expect(page).to have_css("main h1", count: 1)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
    selector = page.evaluate_script("innerWidth") >= 1024 ? ".app-sidebar" : ".app-menu-trigger"
    expect(page).to have_css(selector)
    expect(page).not_to have_text("Translation missing")
  end

  def capture(name, width, locale)
    return unless ENV["CAPTURE_WORKSPACE_UI"] == "true"

    destination = Rails.root.join("tmp/ui-improvements/states")
    FileUtils.mkdir_p(destination)
    save_screenshot(destination.join("#{name}-#{width}-#{locale}.png"), full: false)
  end
end
