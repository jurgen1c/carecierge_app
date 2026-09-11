require "rails_helper"

RSpec.describe "Relationship concierge", type: :request do
  let(:user) { create(:user, onboarding_skipped_at: Time.current) }

  it "renders an important date with its computed title when no custom title was saved" do
    profile = create(:relationship_profile, user:)
    date = create(:important_date, relationship_profile: profile, date_type: "birthday", title: nil)
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Find the birthday", locale: "en", context: Concierge::Context.capture(user:, conversation:))
    token = turn.claim!
    result = Concierge::Execute.call(turn:, token:, name: "dates.search", arguments: {})
    expect(result.fetch("records").sole.fetch("title")).to eq(date.display_title)
    turn.finish!(token:, response: "The birthday is saved.")
    sign_in user
    get concierge_conversation_path(conversation)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(date.display_title)
  end

  it "rejects foreign and malformed person-choice action IDs" do
    conversation = ConciergeConversation.create!(user:)
    other = ConciergeConversation.create!(user: create(:user))
    turn = other.turns.create!(request_key: SecureRandom.uuid, content: "Which Ana?", locale: "en")
    action = turn.actions.create!(name: "people.clarify", fingerprint: "a" * 64, state: "succeeded", result: { "records" => [] })
    sign_in user
    post concierge_conversation_concierge_clarifications_path(conversation), params: { action_id: action.id, relationship_profile_id: SecureRandom.uuid }
    expect(response).to have_http_status(:not_found)
    post concierge_conversation_concierge_clarifications_path(conversation), params: { action_id: [ action.id ], relationship_profile_id: [] }
    expect(response).to have_http_status(:not_found)
    expect(conversation.turns).to be_empty
  end

  it "paginates owned conversation history and preserves Spanish navigation" do
    Timecop.freeze do
      31.times do |index|
        ConciergeConversation.create!(user:, title: "Conversation #{index}", updated_at: index.minutes.ago)
      end
      ConciergeConversation.create!(user: create(:user), title: "Other owner's conversation")
      sign_in user
      get concierge_conversations_path(locale: "es")
      expect(response.body).not_to include("Conversation 30", "Other owner's conversation")
      document = Nokogiri::HTML(response.body)
      older = document.at_css('a[data-concierge-pagination="history-older"]')
      expect(older).to be_present
      get older["href"]
      expect(response.body).to include("Conversation 30", "Enviar")
      expect(response.body).not_to include("Conversation 29", "Other owner's conversation")
    end
  end

  it "paginates older messages, keeps polling on that page, and recovers invalid page inputs" do
    conversation = ConciergeConversation.create!(user:)
    Timecop.freeze do
      31.times do |index|
        conversation.turns.create!(request_key: SecureRandom.uuid, content: "Message number #{index}!", locale: "en",
          state: "completed", created_at: index.minutes.ago)
      end
      sign_in user
      get concierge_conversation_path(conversation)
      expect(response.body).to include("Message number 0!")
      expect(response.body).not_to include("Message number 30!")
      document = Nokogiri::HTML(response.body)
      older = document.at_css('a[data-concierge-pagination="turn-older"]')
      expect(older).to be_present
      get older["href"]
      expect(response.body).to include("Message number 30!")
      expect(response.body).not_to include("Message number 29!")
      document = Nokogiri::HTML(response.body)
      poll_url = document.at_css('[data-concierge-chat-url-value]')["data-concierge-chat-url-value"]
      get poll_url, headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("Message number 30!")
      expect(response.body).not_to include("Message number 0!")
      get concierge_conversation_path(conversation), params: { turn_page: [ "invalid" ], history_page: "999999" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Message number 0!")
    end
  end

  it "renders saved quote amounts and booking times with bilingual manual-record receipts" do
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    profile = create(:relationship_profile, user:)
    plan = create(:event_plan, user:, relationship_profile: profile)
    vendor = create(:vendor, user:)
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Record the arrangements", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "quotes.create", arguments: { event_plan_id: plan.id, vendor_id: vendor.id,
      amount_cents: 123456, currency: "CRC", scope_details: "Dinner for six" })
    Concierge::Execute.call(turn:, token:, name: "bookings.create", arguments: { event_plan_id: plan.id, title: "Birthday dinner", provider_name: vendor.name, starts_at: "2026-10-10T19:00:00-06:00" })
    turn.finish!(token:, response: "The manual records are saved.")
    sign_in user
    %w[en es].each do |locale|
      get concierge_conversation_path(conversation, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("concierge.manual_record", locale:), "CRC", "19:00", "-06:00")
      expect(response.body).not_to include("Translation missing")
    end
  end

  it "keeps a referenced vendor when a confirmed deletion cannot satisfy domain rules" do
    vendor = create(:vendor, user:)
    create(:vendor_quote, user:, vendor:)
    conversation = ConciergeConversation.create!(user:)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Delete this vendor", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    Concierge::Execute.call(turn:, token: turn.claim!, name: "vendors.destroy", arguments: { id: vendor.id })
    action = turn.actions.sole
    sign_in user
    patch concierge_conversation_concierge_action_path(conversation, action), params: { decision: "approve", fingerprint: action.fingerprint }
    expect(response).to redirect_to(concierge_conversation_path(conversation))
    expect(vendor.reload).to be_persisted
    expect(action.reload.state).to eq("awaiting_approval")
    follow_redirect!
    expect(response.body).to include(I18n.t("concierge.errors.invalid_arguments"))
  end

  it "requires authentication" do
    get "/concierge"
    expect(response).to redirect_to(new_user_session_path)
  end

  it "offers an empty conversation in the shared shell without creating records on a read" do
    sign_in user
    expect { get "/concierge" }.not_to change(ConciergeConversation, :count)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Who’s on your mind?", "app-sidebar", "concierge_message_content")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body).to include('name="turbo-cache-control" content="no-cache"')
  end

  it "creates and enqueues a real Spanish conversation without accepting an owner ID" do
    sign_in user
    expect do
      post "/concierge", params: { locale: "es", concierge_message: { content: "Recuerda que Ana prefiere té", request_key: SecureRandom.uuid }, user_id: create(:user).id }
    end.to have_enqueued_job(ConciergeResponseJob)

    conversation = user.concierge_conversations.sole
    expect(conversation.turns.sole.locale).to eq("es")
    expect(response).to redirect_to(concierge_conversation_path(conversation, locale: "es"))
    follow_redirect!
    expect(response.body).to include("Recuerda que Ana prefiere té", "Enviar")
  end

  it "hides another owner's history and decision endpoints" do
    other_conversation = ConciergeConversation.create!(user: create(:user), title: "Private history")
    sign_in user
    get concierge_conversation_path(other_conversation)
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("Private history")
  end

  it "serves incremental Turbo updates through an authenticated request" do
    conversation = ConciergeConversation.create!(user:)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Hello", locale: "en")
    token = turn.claim!
    turn.append_response!(token:, text: "Working with Ana")
    sign_in user
    get transcript_concierge_conversation_path(conversation), headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('target="concierge_transcript"', "Working with Ana")
  end

  it "renders a recoverable validation error without a job or blank conversation" do
    sign_in user
    expect do
      post "/concierge", params: { concierge_message: { content: "", request_key: SecureRandom.uuid } }
    end.not_to have_enqueued_job(ConciergeResponseJob)
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.concierge_conversations.reload).to be_empty
  end

  it "makes the concierge the normal landing for established accounts and the signed-in root" do
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    expect(response).to redirect_to(concierge_conversations_path)
    get root_path
    expect(response).to redirect_to(concierge_conversations_path)
  end

  %w[en es].each do |locale|
    it "restores the HTML conversation after signing in from an expired #{locale} polling request" do
      conversation = ConciergeConversation.create!(user:)
      get transcript_concierge_conversation_path(conversation, locale:, turn_page: 2), headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:redirect)
      post user_session_path(locale:), params: { user: { email: user.email, password: user.password } }
      destination = locale == "en" ? concierge_conversation_path(conversation) : concierge_conversation_path(conversation, locale:)
      expect(response).to redirect_to(destination)
      follow_redirect!
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include('id="concierge_transcript"')
    end
  end

  it "deduplicates repeated first-message submissions across new conversations" do
    sign_in user
    input = { concierge_message: { content: "Remember Ana likes tea", request_key: SecureRandom.uuid } }
    post "/concierge", params: input
    post "/concierge", params: input
    expect(user.concierge_conversations.count).to eq(1)
    expect(user.concierge_conversations.sole.turns.count).to eq(1)
  end

  it "preserves an unsent draft when another message is still running" do
    conversation = ConciergeConversation.create!(user:)
    conversation.turns.create!(request_key: SecureRandom.uuid, content: "First request", locale: "en")
    sign_in user
    post concierge_conversation_concierge_turns_path(conversation), params: {
      concierge_message: { content: "Keep this unsent thought", request_key: SecureRandom.uuid }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Keep this unsent thought", "Finish the current request")
    expect(conversation.turns.count).to eq(1)
  end

  it "offers recovery for a queue entry whose worker never started" do
    conversation = ConciergeConversation.create!(user:)
    Timecop.freeze do
      conversation.turns.create!(request_key: SecureRandom.uuid, content: "Hello", locale: "en")
      Timecop.travel(6.minutes.from_now) do
        sign_in user
        get concierge_conversation_path(conversation)
        expect(response.body).to include('data-busy="false"', "Try again")
      end
    end
  end

  it "hides an obsolete decision preview when its source was changed" do
    profile = create(:relationship_profile, user:)
    memory = profile.memory_records.create!(title: "Old detail", body: "Previously visible information")
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Remove that memory", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "memories.destroy", arguments: { id: memory.id })
    memory.update!(body: "New information")
    sign_in user
    get concierge_conversation_path(conversation)
    expect(response.body).not_to include("Previously visible information")
    expect(response.body).to include(I18n.t("concierge.errors.request_conflict"))
  end

  it "requires an explicit decision to erase a conversation while preserving saved relationship records" do
    profile = create(:relationship_profile, user:)
    memory = profile.memory_records.create!(title: "Saved separately", body: "Keep this")
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    sign_in user
    delete concierge_conversation_path(conversation)
    expect(response).to have_http_status(:unprocessable_content)
    expect(conversation.reload).to be_persisted
    delete concierge_conversation_path(conversation), params: { confirm_delete: "1" }
    expect(response).to redirect_to(concierge_conversations_path)
    expect(ConciergeConversation.exists?(conversation.id)).to be(false)
    expect(memory.reload).to be_persisted
  end
end
