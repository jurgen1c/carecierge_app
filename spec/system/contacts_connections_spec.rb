require 'rails_helper'

RSpec.describe 'Contacts review', type: :system do
  it 'supports readable review choices on desktop, tablet and mobile' do
    user = create(:user)
    connection = ContactsConnection.create!(user:, access_token: 'access')
    connection.imported_contacts.create!(provider_key: 'one', external_id: 'people/1', data: { 'first_name' => 'Elena', 'last_name' => 'Ruiz', 'email' => 'elena@example.com', 'phone' => '+1 555 0100', 'birthday' => '1990-05-04' })
    sign_in user
    visit contacts_connection_path
    expect(page).to have_css('h1', text: 'Contacts')
    expect(page).to have_select('What would you like to do?', options: [ 'Skip for now', 'Create profile' ])
    expect(page).to have_button('Disconnect Google Contacts')
    [ [ 1440, 1000, 'desktop' ], [ 768, 1024, 'tablet' ], [ 390, 844, 'mobile' ] ].each do |width, height, label|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= document.documentElement.clientWidth')).to be(true)
      save_screenshot("contacts-#{label}.png", full: true) if ENV['CAPTURE_CONTACTS_UI'] == 'true'
    end
    select 'Skip for now', from: 'What would you like to do?'
    click_button 'Save choice'
    expect(page).to have_text('Your choice was saved.')
    expect(page).to have_text('Skipped')
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
