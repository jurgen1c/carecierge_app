require 'rails_helper'

RSpec.describe 'Private message excerpts', type: :system do
  it 'keeps source, consent and local editing readable across screen sizes' do
    user = create(:user)
    connection = MessagingConnection.create!(user:)
    context = connection.imported_message_contexts.create!(source_key: 'one', external_id: 'abc123', thread_id: 'def456', subject: 'Lunch next weekend', snippet: 'Would Saturday work for a catch-up?', reply_draft: 'Saturday sounds lovely. What time works for you?')
    sign_in user
    visit messaging_connection_path
    expect(page).to have_css('h1', text: 'Email and messages')
    expect(page).to have_link('Open source in Gmail', href: context.source_url)
    expect(page).to have_unchecked_field("draft-consent-#{context.id}")
    [ [ 1440, 1000, 'desktop' ], [ 768, 1024, 'tablet' ], [ 390, 844, 'mobile' ] ].each do |width, height, label|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= document.documentElement.clientWidth')).to be(true)
      save_screenshot("messaging-#{label}.png", full: true) if ENV['CAPTURE_MESSAGING_UI'] == 'true'
    end
    fill_in "reply-#{context.id}", with: 'Saturday at noon?'
    click_button 'Save draft'
    expect(page).to have_text('Your reply draft was saved. Nothing was sent.')
    click_button 'Delete excerpt and draft'
    expect(page).to have_text('The imported excerpt and its reply draft were deleted.')
    expect(page).not_to have_text('Lunch next weekend')
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
