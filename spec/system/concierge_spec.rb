require "rails_helper"

RSpec.describe "Conversational relationship care", type: :system do
  include ActiveJob::TestHelper

  after { page.current_window.resize_to(1280, 800) }

  %w[preferences notes cadence].each do |kind|
    it "opens the visible profile destination from a #{kind} receipt" do
      user = create(:user, onboarding_completed_at: Time.current)
      profile = create(:relationship_profile, user:)
      record = case kind
      when "preferences" then create(:relationship_preference, relationship_profile: profile, value: "Quiet gardens")
      when "notes" then create(:relationship_note, relationship_profile: profile, body: "A remembered garden visit", private: false)
      else create(:contact_cadence, relationship_profile: profile)
      end
      conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
      turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Read the record", locale: "en",
        context: Concierge::Context.capture(user:, conversation:))
      token = turn.claim!
      Concierge::Execute.call(turn:, token:, name: "#{kind}.read", arguments: kind == "cadence" ? {} : { id: record.id })
      turn.finish!(token:, response: "Here is the saved record.")
      sign_in user
      visit concierge_conversation_path(conversation)
      find(".concierge-source-link").click
      target = case kind
      when "preferences" then "#persona_source_relationship_preference_#{record.id}"
      when "notes" then "#profile-about"
      else "#contact_rhythm_section"
      end
      expect(page).to have_current_path(/#{Regexp.escape(target)}\z/, url: true)
      expect(page).to have_css(target, visible: true)
      expect(page).to have_content("A remembered garden visit") if kind == "notes"
    end
  end

  it "opens the cited completed review instead of another pending review" do
    user = create(:user, onboarding_completed_at: Time.current)
    profile = create(:relationship_profile, user:)
    memory = create(:memory_record, relationship_profile: profile, title: "Reviewed garden preference", source: "ai_inferred", confidence: "inferred")
    ApprovalQueue::Synchronize.call(user:)
    review = user.approval_requests.find_by!(subject: memory)
    ApprovalDecisions::Apply.call(approval_request: review, actor: user, decision: "approve", lock_version: review.lock_version)
    create(:memory_record, relationship_profile: profile, title: "Unrelated pending fact", source: "ai_inferred", confidence: "inferred")
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Read that decision", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "approvals.read", arguments: { id: review.id })
    turn.finish!(token:, response: "The review is complete.")
    sign_in user
    visit concierge_conversation_path(conversation)
    find(".concierge-source-link").click
    expect(page).to have_current_path(approvals_path(id: review.id, status: "completed"))
    expect(page).to have_content("Reviewed garden preference")
    expect(page).to have_no_content("Unrelated pending fact")
  end

  it "lets mobile users scroll expanded private context to its final controls" do
    user = create(:user, onboarding_completed_at: Time.current)
    profile = create(:relationship_profile, user:)
    25.times { |index| profile.relationship_notes.create!(body: "Private context #{index}", private: true) }
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    page.current_window.resize_to(390, 700)
    sign_in user
    visit concierge_conversation_path(conversation)
    find(".concierge-private-context summary").click
    coordinates = page.evaluate_script(<<~JS)
      (() => {
        const bounds = document.querySelector('.concierge-desk').getBoundingClientRect();
        return [Math.round(bounds.left + bounds.width / 2), Math.round(Math.min(bounds.bottom, window.innerHeight) - 20)];
      })()
    JS
    page.driver.browser.page.command("Input.dispatchMouseEvent", type: "mouseWheel", x: coordinates[0], y: coordinates[1], deltaX: 0, deltaY: 2000)
    scrolled = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      const desk = document.querySelector('.concierge-desk');
      let frames = 0;
      function check() {
        if (desk.scrollTop > 0 || frames++ > 120) return done(desk.scrollTop > 0);
        window.requestAnimationFrame(check);
      }
      check();
    JS
    expect(scrolled).to be(true)
    expect(page.evaluate_script(<<~JS)).to be(true)
      (() => {
        const button = document.querySelector('[data-concierge-chat-target=send]').getBoundingClientRect();
        const desk = document.querySelector('.concierge-desk').getBoundingClientRect();
        return button.top >= desk.top && button.bottom <= Math.min(desk.bottom, window.innerHeight);
      })()
    JS
    find(".concierge-private-context label", text: "Private context 19", exact_text: true).click
    expect(page).to have_checked_field("concierge_message[private_note_ids][]", count: 1)
    fill_in "concierge_message_content", with: "Keep this draft while choosing context"
    click_link "Show more private notes"
    expect(page).to have_content("Private context 24")
    expect(page).to have_css("turbo-frame#concierge_private_notes_2 input:focus")
    expect(page).to have_checked_field("concierge_message[private_note_ids][]", count: 1)
    expect(page).to have_field("concierge_message_content", with: "Keep this draft while choosing context")
    find(".concierge-private-context label", text: "Private context 24", exact_text: true).click
    expect(page).to have_checked_field("concierge_message[private_note_ids][]", count: 2)
  end

  %w[en es].each do |locale|
    it "selects work context inside the #{locale} chat and resumes with only the selected work record" do
      page.current_window.resize_to(390, 700) if locale == "es"
      user = create(:user, onboarding_completed_at: Time.current)
      profile = create(:relationship_profile, user:, first_name: "Ana", preferred_name: nil)
      work_note = profile.relationship_notes.create!(category: "Work", body: "Meeting agenda", private: false)
      profile.relationship_notes.create!(category: "Personal", body: "Personal holiday", private: false)
      conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
      original = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Old personal conversation", locale:,
        state: "completed", context: Concierge::Context.capture(user:, conversation:))
      sign_in user
      allow_any_instance_of(Concierge::Agent).to receive(:call) do |_agent, turn:, token:, &stream|
        expect(Concierge::History.messages(turn:)).to be_empty
        result = Concierge::Execute.call(turn:, token:, name: "notes.search", arguments: {})
        expect(result.fetch("records").pluck("id")).to eq([ work_note.id ])
        stream.call("Meeting agenda")
        { content: "Meeting agenda" }
      end
      visit concierge_conversation_path(conversation, locale:)
      find("summary", text: I18n.t("concierge.relationship_context.title", locale:), exact_text: true).click
      click_link I18n.t("concierge.relationship_context.edit", locale:)
      select I18n.t("professional_relationships.modes.professional", locale:), from: I18n.t("professional_relationships.mode", locale:)
      find("summary", text: I18n.t("professional_relationships.edit_context", locale:), exact_text: true).click
      check "professional_source_#{work_note.id}"
      click_button I18n.t("concierge.relationship_context.save", locale:)
      expect(page).to have_content(I18n.t("concierge.relationship_context.saved", locale:))
      expect(page).to have_no_content("Old personal conversation")
      expect(profile.reload).to be_professional
      expect(profile.reload.work_context.selected("relationship_notes").pluck(:id)).to eq([ work_note.id ])
      expect { Concierge::Context.verify!(turn: original) }.to raise_error(Concierge::ContextUnavailable)
      fill_in I18n.t("concierge.message_label", locale:), with: locale == "es" ? "¿Qué debo tratar en la reunión?" : "What should I cover in the meeting?"
      perform_enqueued_jobs(only: ConciergeResponseJob) do
        click_button I18n.t("concierge.send", locale:)
        expect(page).to have_content("Meeting agenda")
      end
      expect(page).to have_no_content("Personal holiday")
      expect(page).to have_no_content("Translation missing")
    end

    it "resolves two people named Ana through an inline #{locale} choice before saving the requested memory" do
      user = create(:user, onboarding_completed_at: Time.current)
      ana = create(:relationship_profile, user:, first_name: "Ana", last_name: "Ruiz", preferred_name: nil)
      other_ana = create(:relationship_profile, user:, first_name: "Ana", last_name: "Vega", preferred_name: nil)
      sign_in user
      allow_any_instance_of(Concierge::Agent).to receive(:call) do |_agent, turn:, token:, &stream|
        if turn.context["relationship_profile_id"]
          expect(turn.context["relationship_profile_id"]).to eq(ana.id)
          Concierge::Execute.call(turn:, token:, name: "memories.create", arguments: {
            title: "Ana", body: locale == "es" ? "Prefiere lugares tranquilos." : "Prefers quiet places." })
          answer = locale == "es" ? "Guardé el recuerdo para Ana Ruiz." : "I saved the memory for Ana Ruiz."
        else
          result = Concierge::Execute.call(turn:, token:, name: "people.search", arguments: { query: "Ana" })
          Concierge::Execute.call(turn:, token:, name: "people.clarify", arguments: { ids: result.fetch("records").pluck("id") })
          answer = locale == "es" ? "¿A cuál Ana te refieres?" : "Which Ana do you mean?"
        end
        stream.call(answer)
        { content: answer }
      end
      visit concierge_conversations_path(locale:)
      fill_in I18n.t("concierge.message_label", locale:), with: locale == "es" ? "Recuerda que Ana prefiere lugares tranquilos." : "Remember that Ana prefers quiet places."
      perform_enqueued_jobs(only: ConciergeResponseJob) do
        click_button I18n.t("concierge.send", locale:)
        expect(page).to have_button(I18n.t("concierge.choose_person", locale:, name: ana.display_name))
      end
      expect(ana.memory_records).to be_empty
      perform_enqueued_jobs(only: ConciergeResponseJob) do
        click_button I18n.t("concierge.choose_person", locale:, name: ana.display_name)
        expect(page).to have_content(locale == "es" ? "Prefiere lugares tranquilos." : "Prefers quiet places.")
      end
      expect(ana.memory_records.count).to eq(1)
      expect(other_ana.memory_records).to be_empty
      expect(page).to have_no_content("Translation missing")
      expect(page).to have_no_css("[data-busy='true']")
    end
  end

  it "saves a memory through chat, streams a receipt, and keeps it available in People in both languages" do
    user = create(:user, onboarding_completed_at: Time.current)
    profile = create(:relationship_profile, user:, first_name: "Ana", preferred_name: nil)
    sign_in user

    allow_any_instance_of(Concierge::Agent).to receive(:call) do |_agent, turn:, token:, &stream|
      spanish = turn.locale == "es"
      Concierge::Execute.call(turn:, token:, name: "memories.create", arguments: {
        "relationship_profile_id" => profile.id,
        "title" => spanish ? "Restaurantes tranquilos" : "Quiet restaurants",
        "body" => spanish ? "Ana prefiere restaurantes tranquilos." : "Ana prefers quiet restaurants."
      })
      answer = spanish ? "Guardé el recuerdo sobre Ana." : "I saved that memory about Ana."
      stream.call(answer)
      { content: answer }
    end

    [ [ :en, 1440, "Remember that Ana prefers quiet restaurants." ], [ :es, 390, "Recuerda que Ana prefiere restaurantes tranquilos." ] ].each do |locale, width, message|
      page.current_window.resize_to(width, 900)
      visit concierge_conversations_path(locale:)
      expect(page).to have_content(I18n.t("concierge.welcome", locale:))
      select profile.display_name, from: I18n.t("concierge.person_context", locale:)
      fill_in I18n.t("concierge.message_label", locale:), with: message
      perform_enqueued_jobs(only: ConciergeResponseJob) do
        click_button I18n.t("concierge.send", locale:)
        expect(page).to have_css(".concierge-receipt", text: I18n.t("concierge.operations.memories.create", locale:), wait: 10)
      end
      expect(page).to have_current_path(concierge_conversation_path(user.concierge_conversations.order(:created_at).last), ignore_query: true)
      expect(page).to have_field(I18n.t("concierge.message_label", locale:), with: "")
      expect(page).to have_button(I18n.t("concierge.send", locale:), disabled: false)
      expect(page).to have_no_css("[data-busy='true']")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      if width == 390
        expect(page.evaluate_script("document.querySelector('#concierge_message_content').getBoundingClientRect().bottom <= window.innerHeight")).to be(true)
        expect(page.evaluate_script("document.querySelector('[data-concierge-chat-target=send]').getBoundingClientRect().bottom <= window.innerHeight")).to be(true)
      end
      page.save_screenshot(Rails.root.join("tmp/capybara/concierge-#{locale}-#{width}.png"), full: false)
      visit relationship_profile_path(profile, locale:)
      expect(page).to have_text(:all, locale == :es ? "Restaurantes tranquilos" : "Quiet restaurants")
    end
    expect(profile.memory_records.count).to eq(2)
  end

  it "preserves the transcript reading position and keyboard focus across polling replacements" do
    user = create(:user, onboarding_completed_at: Time.current)
    conversation = user.concierge_conversations.create!
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Read this long answer", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    token = turn.claim!
    turn.append_response!(token:, text: (1..80).map { |i| "Reading line #{i}." }.join("\n\n"))
    sign_in user
    visit concierge_conversation_path(conversation)
    expect(page).to have_content("Reading line 80.")
    page.execute_script(<<~JS)
      const element = document.querySelector('[data-controller="concierge-chat"]');
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "concierge-chat");
      window.clearTimeout(controller.timer);
      controller.transcriptTarget.scrollTop = 240;
      controller.transcriptTarget.focus({ preventScroll: true });
      window.previousTranscript = controller.transcriptTarget;
      controller.refresh();
    JS
    expect(page).to have_css("#concierge_transcript")
    expect(page.evaluate_async_script(<<~JS)).to be(true)
      const done = arguments[0];
      function check() {
        const current = document.querySelector('#concierge_transcript');
        if (current === window.previousTranscript) { window.requestAnimationFrame(check); return; }
        window.requestAnimationFrame(() => done(Math.abs(current.scrollTop - 240) < 2 && document.activeElement === current));
      }
      check();
    JS
  end

  it "preserves focus on receipt controls while a response is still polling" do
    user = create(:user, onboarding_completed_at: Time.current)
    profile = create(:relationship_profile, user:)
    conversation = user.concierge_conversations.create!(relationship_profile: profile)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Save this memory", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    token = turn.claim!
    result = Concierge::Execute.call(turn:, token:, name: "memories.create", arguments: { title: "Garden", body: "Likes quiet gardens" })
    sign_in user
    visit concierge_conversation_path(conversation)
    expect(page).to have_link("Garden")
    [ ".concierge-source-link", "button[data-action='concierge-chat#useStarter']" ].each do |selector|
      page.execute_script(<<~JS, selector)
        const element = document.querySelector('[data-controller="concierge-chat"]');
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "concierge-chat");
        window.clearTimeout(controller.timer);
        controller.transcriptTarget.querySelector(arguments[0]).focus();
        window.previousTranscript = controller.transcriptTarget;
        controller.refresh();
      JS
      expect(page.evaluate_async_script(<<~JS, selector)).to be(true)
        const selector = arguments[0], done = arguments[1];
        function check() {
          const current = document.querySelector('#concierge_transcript');
          if (current === window.previousTranscript) { window.requestAnimationFrame(check); return; }
          window.requestAnimationFrame(() => done(document.activeElement === current.querySelector(selector)));
        }
        check();
      JS
    end
    expect(profile.memory_records.sole.id).to eq(result.dig("record", "id"))
  end

  it "keeps typing usable and makes starters keyboard accessible at a narrow width" do
    sign_in create(:user, onboarding_skipped_at: Time.current)
    page.current_window.resize_to(320, 844)
    visit concierge_conversations_path
    click_button "Remember something about someone"
    expect(page).to have_field("Your message", with: "Remember that ")
    expect(page.evaluate_script("document.activeElement.id")).to eq("concierge_message_content")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    page.save_screenshot(Rails.root.join("tmp/capybara/concierge-empty-320.png"), full: false)
  end

  it "confirms a draft request inline and shows the completed job result in Spanish" do
    user = create(:user, onboarding_completed_at: Time.current)
    profile = create(:relationship_profile, user:, first_name: "Ana")
    create(:automation_permission, user:, capability: "draft_messages", mode: "ask_every_time")
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Prepara un mensaje para Ana", locale: "es",
      context: Concierge::Context.capture(user:, conversation:))
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "drafts.generate", arguments: { draft_type: "check_in", tone: "warm" })
    turn.finish!(token:, response: "Revisa la solicitud antes de preparar el borrador.")
    allow_any_instance_of(MessageDrafts::OpenAiGenerator).to receive(:generate).and_return("Hola Ana, ¿cómo va tu semana?")
    sign_in user
    visit concierge_conversation_path(conversation, locale: :es)
    perform_enqueued_jobs(only: ConciergeActionJob) do
      click_button I18n.t("concierge.decisions.approve", locale: :es)
      expect(page).to have_content("Hola Ana, ¿cómo va tu semana?", wait: 10)
    end
    expect(page).to have_no_css("[data-busy='true']")
    expect(page).to have_no_content("Translation missing")
    expect(profile.reload.message_draft.current_revision.content).to eq("Hola Ana, ¿cómo va tu semana?")
  end

  it "starts a Spanish correction from a receipt and saves a real memory revision" do
    user = create(:user, onboarding_completed_at: Time.current)
    profile = create(:relationship_profile, user:, first_name: "Ana")
    sign_in user
    allow_any_instance_of(Concierge::Agent).to receive(:call) do |_agent, turn:, token:, &stream|
      memory = profile.memory_records.first
      if memory
        result = Concierge::Execute.call(turn:, token:, name: "memories.update", arguments: {
          relationship_profile_id: profile.id, id: memory.id, body: "Prefiere restaurantes tranquilos con mesas al aire libre." })
      else
        result = Concierge::Execute.call(turn:, token:, name: "memories.create", arguments: {
          relationship_profile_id: profile.id, title: "Restaurantes", body: "Prefiere restaurantes tranquilos." })
      end
      expect(result).to include("status" => "succeeded")
      stream.call("Guardé el detalle sobre Ana.")
      { content: "Guardé el detalle sobre Ana." }
    end
    visit concierge_conversations_path(locale: :es)
    select profile.display_name, from: I18n.t("concierge.person_context", locale: :es)
    fill_in I18n.t("concierge.message_label", locale: :es), with: "Recuerda que Ana prefiere restaurantes tranquilos."
    perform_enqueued_jobs(only: ConciergeResponseJob) do
      click_button I18n.t("concierge.send", locale: :es)
      expect(page).to have_css(".concierge-receipt", text: "Restaurantes")
    end
    find('button[aria-label="Corregir Restaurantes"]').click
    expect(page).to have_field(I18n.t("concierge.message_label", locale: :es), with: "Corrige «Restaurantes»: ")
    expect(page.evaluate_script("document.activeElement.id")).to eq("concierge_message_content")
    fill_in I18n.t("concierge.message_label", locale: :es), with: "Corrige «Restaurantes»: prefiere mesas al aire libre."
    perform_enqueued_jobs(only: ConciergeResponseJob) do
      click_button I18n.t("concierge.send", locale: :es)
      expect(page).to have_content("Prefiere restaurantes tranquilos con mesas al aire libre.")
    end
    expect(profile.memory_records.sole.body).to eq("Prefiere restaurantes tranquilos con mesas al aire libre.")
    expect(profile.memory_records.sole.memory_revisions.count).to eq(1)
  end
end
