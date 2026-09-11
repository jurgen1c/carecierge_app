require "rails_helper"

RSpec.describe "Concierge with simulated provider responses", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, onboarding_skipped_at: Time.current) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Ana", preferred_name: nil) }
  let(:conversation) { user.concierge_conversations.create! }
  let(:provider_responses) { ConciergeProviderResponses.new }
  let(:locale) { "en" }

  around { |example| Timecop.freeze(Time.zone.parse("2026-09-08 10:00:00")) { example.run } }

  before do
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    sign_in user
    clear_enqueued_jobs
    config = RubyLLM.config.dup
    config.faraday_adapter = provider_responses.adapter
    config.openai_api_key = "synthetic-test-key"
    config.openai_api_base = config.ollama_api_base = "https://concierge-provider.invalid/v1"
    allow(RubyLLM).to receive(:config).and_return(config)
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:concierge, :provider).and_return(provider)
    allow(Rails.application.credentials).to receive(:dig).with(:concierge, :model).and_return("test-concierge")
    expect(Faraday::Adapter::NetHttp).not_to receive(:new)
  end

  def submit_message(content, expected_state: "completed", request_key: SecureRandom.uuid)
    @message_number = @message_number.to_i + 1
    turn = nil
    # Preserve deterministic dates and distinct chronological turn timestamps.
    Timecop.freeze(Time.current + @message_number.seconds) do
      expect do
        post concierge_conversation_concierge_turns_path(conversation, locale:), params: {
          concierge_message: { content:, request_key: }
        }
      end.to have_enqueued_job(ConciergeResponseJob)
      expect(response).to have_http_status(:see_other)
      perform_enqueued_jobs(only: ConciergeResponseJob)
      turn = conversation.turns.find_by!(request_key:)
      expect(turn.state).to eq(expected_state), "Unexpected turn error: #{turn.error_code}"
    end
    provider_responses.verify!
    turn
  end

  def lookup_person(name: "Ana", person: profile)
    provider_responses.next_response do |payload|
      expect(payload.fetch("stream")).to eq(provider == "openai")
      expect(payload.fetch("store")).to be(false) if provider == "openai"
      provider_responses.tool("people_search", query: name)
    end
    person
  end

  def expect_tools(payload, *names)
    expect(payload.fetch("tools").map { |tool| tool.fetch("function").fetch("name") }).to include(*names)
  end

  def answer_after_result(answer, *fragments)
    provider_responses.next_response do |payload|
      expect(provider_responses.tool_result(payload)).to include(*fragments)
      provider_responses.answer(answer)
    end
  end

  %w[ollama openai].each do |provider_name|
    context "through #{provider_name}" do
      let(:provider) { provider_name }

      it "fails a truncated final reply while retaining a completed memory action and retry controls" do
        conversation.update!(relationship_profile: profile)
        provider_responses.next_response { provider_responses.tool("memories_create", title: "Tea", body: "Enjoys green tea") }
        provider_responses.next_response do
          provider_responses.answer("Saved, and the next step is to").tap do |response|
            response.fetch("choices").first["finish_reason"] = "length"
          end
        end
        turn = submit_message("Remember that Ana enjoys green tea", expected_state: "failed")
        expect(turn.error_code).to eq("provider_unavailable")
        expect(turn.actions.find_by!(name: "memories.create").state).to eq("succeeded")
        expect(profile.memory_records.sole.body).to eq("Enjoys green tea")
        get concierge_conversation_path(conversation)
        expect(response.body).to include(retry_concierge_conversation_concierge_turn_path(conversation, turn))
      end

      it "rejects a truncated tool completion before its apparently valid arguments can mutate records" do
        conversation.update!(relationship_profile: profile)
        provider_responses.next_response do
          provider_responses.tool("memories_create", title: "Tea", body: "Incomplete intention").tap do |response|
            response.fetch("choices").first["finish_reason"] = "length"
          end
        end
        expect { submit_message("Remember something", expected_state: "failed") }.not_to change(MemoryRecord, :count)
        expect(provider_responses.requests.length).to eq(1)
      end

      it "fails a reply when the provider never supplies a completion status" do
        provider_responses.next_response do
          provider_responses.answer("An interrupted answer").tap do |response|
            response.fetch("choices").first["finish_reason"] = nil
          end
        end
        turn = submit_message("Help me get started", expected_state: "failed")
        expect(turn.error_code).to eq("provider_unavailable")
      end

      it "enforces the context budget before any HTTP submission" do
        stub_const("Concierge::Agent::MAX_CONTEXT_CHARACTERS", 100)
        turn = submit_message("Hello", expected_state: "failed")
        expect(turn.error_code).to eq("limit_reached")
        expect(provider_responses.requests).to be_empty
      end

      it "rejects an oversized tool-result history before its next HTTP submission" do
        stub_const("Concierge::Agent::MAX_CONTEXT_CHARACTERS", 10_000)
        20.times { |index| create(:relationship_profile, user:, first_name: "Ana", last_name: "Person #{index}", preferred_name: nil) }
        provider_responses.next_response { provider_responses.tool("people_search", query: "Ana") }
        turn = submit_message("Find Ana", expected_state: "failed")
        expect(turn.error_code).to eq("limit_reached")
        expect(provider_responses.requests.length).to eq(1)
      end

      it "rechecks a revoked tool source before submitting the next HTTP request" do
        profile
        provider_responses.next_response { provider_responses.tool("people_search", query: "Ana") }
        allow_any_instance_of(Concierge::Tool).to receive(:call).and_wrap_original do |original, *arguments|
          original.call(*arguments).tap { profile.update!(first_name: "Changed elsewhere") }
        end
        turn = submit_message("Find Ana", expected_state: "failed")
        expect(turn.error_code).to eq("context_unavailable")
        expect(provider_responses.requests.length).to eq(1)
      end

      it "does not retransmit a revoked result after the provider repeats the same search" do
        conversation.update!(relationship_profile: profile)
        memory = create(:memory_record, relationship_profile: profile, title: "Sensitive fact", body: "Protected detail")
        provider_responses.next_response { provider_responses.tool("memories_search") }
        provider_responses.next_response do |payload|
          expect(provider_responses.tool_result(payload)).to include("Protected detail")
          PrivacyVault::Protect.call(actor: user, protectable: memory)
          provider_responses.tool("memories_search")
        end
        turn = submit_message("Read my memories twice", expected_state: "failed")
        expect(turn.error_code).to eq("context_unavailable")
        expect(provider_responses.requests.length).to eq(2)
        expect(Concierge::History.sources_current?(turn)).to be(false)
        expect(turn.actions.find_by!(name: "memories.search").result.fetch("records").pluck("id")).to include(memory.id)
      end

      it "does not let a different read conceal a source change between tools in one provider response" do
        conversation.update!(relationship_profile: profile)
        memory = create(:memory_record, relationship_profile: profile, body: "Original detail")
        provider_responses.next_response { provider_responses.tool("capabilities", capabilities: [ "memories" ]) }
        provider_responses.next_response do
          response = provider_responses.tool("memories_search")
          second = provider_responses.tool("memories_read", id: memory.id)
          response.fetch("choices").first.fetch("message").fetch("tool_calls").concat(
            second.fetch("choices").first.fetch("message").fetch("tool_calls"))
          response
        end
        allow_any_instance_of(Concierge::Tool).to receive(:call).and_wrap_original do |original, *arguments|
          original.call(*arguments).tap do
            memory.update!(body: "Changed outside this turn") if original.receiver.name == "memories_search"
          end
        end
        turn = submit_message("Read the memory", expected_state: "failed")
        expect(turn.error_code).to eq("context_unavailable")
        expect(provider_responses.requests.length).to eq(2)
        expect(turn.actions.where(name: "memories.read")).to be_empty
      end

      def source_answer
        note = profile.relationship_notes.create!(body: "Tea ceremony preference", private: false)
        Timecop.freeze(3.seconds.ago) do
          earlier = conversation.turns.create!(content: "Read Ana's note", request_key: SecureRandom.uuid, locale:,
            context: Concierge::Context.capture(user:, conversation:))
          token = earlier.claim!
          Concierge::Execute.call(turn: earlier, token:, name: "notes.read", arguments: { relationship_profile_id: profile.id, id: note.id })
          earlier.finish!(token:, response: "The note describes a tea ceremony preference.")
        end
        note
      end

      it "revalidates inherited sources across tool-free follow-ups, rendering, exports and later prompts" do
        note = source_answer
        provider_responses.next_response do |payload|
          expect(payload.fetch("messages").to_json).to include("tea ceremony preference")
          provider_responses.answer("A quiet tea ceremony would suit Ana.")
        end
        first = submit_message("Summarize that")
        second = nil
        7.times do
          provider_responses.next_response { provider_responses.answer("Choose a small tea gathering.") }
          second = submit_message("Make that shorter")
        end
        expect(first.actions).to be_empty
        expect(second.actions).to be_empty
        expect(second.referenced_profile_ids).to eq([ profile.id ])
        expect(Concierge::History.sources_current?(second.reload)).to be(true)

        note.update!(private: true)
        expect(Concierge::History.sources_current?(first.reload)).to be(false)
        expect(Concierge::History.sources_current?(second.reload)).to be(false)
        get transcript_concierge_conversation_path(conversation)
        expect(response.body).not_to include("A quiet tea ceremony", "Choose a small tea gathering")
        exported = DataExports::ConciergeConversations.new(user:).to_a.to_json
        expect(exported).not_to include("A quiet tea ceremony", "Choose a small tea gathering")
        provider_responses.next_response do |payload|
          expect(payload.fetch("messages").to_json).not_to include("tea ceremony", "small tea gathering")
          provider_responses.answer("What would you like to work on?")
        end
        submit_message("Start something else")
      end

      it "discards a tool-free follow-up if its inherited source is revoked during the provider response" do
        note = source_answer
        provider_responses.next_response do
          note.update!(private: true)
          provider_responses.answer("A private tea ceremony summary.")
        end
        turn = submit_message("Summarize that", expected_state: "failed")
        expect(turn).to have_attributes(error_code: "context_unavailable", response: nil)
      end

      %w[en es].each do |language|
        context "in #{language}" do
          let(:locale) { language }
          let(:spanish) { locale == "es" }

          it "looks up a person, saves a real memory, returns its receipt and ignores job redelivery" do
            persisted_chunks = []
            allow_any_instance_of(ConciergeTurn).to receive(:append_response!).and_wrap_original do |original, **arguments|
              original.call(**arguments).tap { persisted_chunks << original.receiver.reload.response }
            end
            lookup_person
            title = spanish ? "Restaurantes" : "Restaurants"
            body = spanish ? "Ana prefiere restaurantes tranquilos." : "Ana prefers quiet restaurants."
            provider_responses.next_response do |payload|
              expect(provider_responses.tool_result(payload)).to include("succeeded", profile.id)
              provider_responses.tool("memories_create", relationship_profile_id: profile.id, title:, body:)
            end
            provider_responses.next_response do |payload|
              result = provider_responses.tool_result(payload)
              expect(result).to include("succeeded", profile.memory_records.sole.id)
              provider_responses.answer(body)
            end

            turn = submit_message(spanish ? "Recuerda que #{body}" : "Remember that #{body}")

            expect(profile.memory_records.sole).to have_attributes(body:, source: "user_confirmed")
            expect(turn).to have_attributes(response: body, input_tokens: 30, output_tokens: 9)
            expect(persisted_chunks).to eq(provider == "openai" ? [ body.first(body.length / 2), body ] : [ body ])
            expect(turn.actions.order(:execution_order).pluck(:name)).to eq(%w[people.search memories.create])
            expect { ConciergeResponseJob.perform_now(turn.id) }.not_to change { provider_responses.requests.length }
            expect(profile.memory_records.count).to eq(1)
            get concierge_conversation_path(conversation, locale:)
            expect(response.body).to include(body, I18n.t("concierge.action_states.succeeded", locale:))
          end

          it "loads recap tools and returns an authorized saved conversation with a source link" do
            title = spanish ? "Nuevo trabajo" : "New job"
            body = spanish ? "Ana empieza el lunes en la biblioteca." : "Ana starts at the library on Monday."
            recap = create(:conversation_recap, relationship_profile: profile, title:, body:)
            lookup_person
            provider_responses.next_response do |payload|
              expect(provider_responses.tool_result(payload)).to include(profile.id)
              provider_responses.tool("capabilities", capabilities: [ "recaps" ])
            end
            provider_responses.next_response do |payload|
              expect_tools(payload, "recaps_search")
              provider_responses.tool("recaps_search", relationship_profile_id: profile.id, query: title)
            end
            answer_after_result(body, "succeeded", recap.id, body)

            submit_message(spanish ? "¿Qué me contó Ana sobre su nuevo trabajo?" : "What did Ana tell me about her new job?")

            get concierge_conversation_path(conversation, locale:)
            document = Nokogiri::HTML(response.body)
            expect(document.text).to include(body)
            expect(document.css("a").map { |link| link["href"] }).to include(
              relationship_profile_path(profile.id, locale: spanish ? locale : nil, anchor: "conversation_recap_#{recap.id}"))
            expect(profile.memory_records).to be_empty
          end

          it "corrects the existing memory through a loaded tool and preserves its revision" do
            memory = profile.memory_records.create!(title: "Restaurants", body: "Quiet restaurants")
            body = spanish ? "Ana prefiere restaurantes al aire libre." : "Ana prefers outdoor restaurants."
            lookup_person
            provider_responses.next_response { provider_responses.tool("capabilities", capabilities: [ "memories" ]) }
            provider_responses.next_response do |payload|
              expect_tools(payload, "memories_search", "memories_update")
              provider_responses.tool("memories_search", relationship_profile_id: profile.id, query: "Restaurants")
            end
            provider_responses.next_response do |payload|
              expect(provider_responses.tool_result(payload)).to include(memory.id, "Quiet restaurants")
              provider_responses.tool("memories_update", relationship_profile_id: profile.id, id: memory.id, body:)
            end
            answer_after_result(body, "succeeded", memory.id, body)

            submit_message(spanish ? "Corrige el recuerdo: #{body}" : "Correct the memory: #{body}")

            expect(profile.memory_records.count).to eq(1)
            expect(memory.reload).to have_attributes(body:, status: "corrected")
            expect(memory.memory_revisions.sole).to have_attributes(previous_body: "Quiet restaurants", revised_body: body)
          end

          it "plans a birthday, continues with current references and creates a reminder only after owner approval" do
            date = create(:important_date, relationship_profile: profile, date_type: "birthday", starts_on: "2026-10-20", recurrence: "yearly")
            user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "ask_every_time")
            title = spanish ? "Cumpleaños de Ana" : "Ana's birthday"
            lookup_person
            provider_responses.next_response { provider_responses.tool("capabilities", capabilities: %w[dates plans]) }
            provider_responses.next_response do |payload|
              expect_tools(payload, "dates_search", "plans_create")
              schema = payload.fetch("tools").find { |tool| tool.dig("function", "name") == "plans_create" }
              expect(schema.dig("function", "parameters", "required")).to include("title", "occasion_type", "relationship_profile_id")
              provider_responses.tool("dates_search", relationship_profile_id: profile.id)
            end
            provider_responses.next_response do |payload|
              expect(provider_responses.tool_result(payload)).to include(date.id, "2026-10-20")
              provider_responses.tool("plans_create", relationship_profile_id: profile.id, title:,
                occasion_type: "birthday", starts_on: "2026-10-20", important_date_id: date.id)
            end
            answer_after_result(title, "succeeded", "EventPlan")
            submit_message(spanish ? "Empieza a planear el cumpleaños de Ana el próximo mes." : "Start planning Ana's birthday next month.")
            plan = user.event_plans.sole
            expect(plan).to have_attributes(starts_on: Date.new(2026, 10, 20), title:)
            expect(plan.source_context.sole.fetch("id")).to eq("important_date:#{date.id}")
            expect(plan.plan_tasks.current).not_to be_empty

            provider_responses.next_response do |payload|
              expect(payload.fetch("messages").to_json).to include(plan.id)
              provider_responses.tool("capabilities", capabilities: [ "plans" ])
            end
            provider_responses.next_response { provider_responses.tool("plans_read", relationship_profile_id: profile.id, id: plan.id) }
            provider_responses.next_response do |payload|
              expect(provider_responses.tool_result(payload)).to include(plan.id)
              provider_responses.tool("plans_update", relationship_profile_id: profile.id, id: plan.id, guest_list: "4")
            end
            question = spanish ? "¿A qué hora quieres el recordatorio?" : "What time should the reminder be?"
            answer_after_result(question, "succeeded", plan.id)
            submit_message(spanish ? "Cuatro personas, y un recordatorio una semana antes." : "Four people, and a reminder a week before.")
            expect(plan.reload.guest_list).to eq("4")
            expect(user.reminders).to be_empty

            provider_responses.next_response do |payload|
              history = payload.fetch("messages").to_json
              expect(history).to include(plan.id, question)
              provider_responses.tool("capabilities", capabilities: [ "reminders" ])
            end
            provider_responses.next_response do |payload|
              expect_tools(payload, "reminders_create")
              provider_responses.tool("reminders_create", relationship_profile_id: profile.id, event_plan_id: plan.id,
                title:, reminder_type: "event_preparation", scheduled_at: "2026-10-13T09:00:00-06:00")
            end
            answer_after_result(spanish ? "Revisa el recordatorio." : "Review the reminder.", "awaiting_approval")
            turn = submit_message(spanish ? "A las 9 de la mañana." : "At 9 in the morning.")
            expect(user.reminders).to be_empty
            action = turn.actions.sole
            expect(action.state).to eq("awaiting_approval")
            patch concierge_conversation_concierge_action_path(conversation, action, locale:),
              params: { decision: "approve", fingerprint: action.fingerprint }
            expect(response).to have_http_status(:see_other)
            expect(user.reminders.sole).to have_attributes(event_plan_id: plan.id,
              scheduled_at: Time.iso8601("2026-10-13T09:00:00-06:00"))
          end

          it "records a Friday promise and resolves its reminder from the preceding turn" do
            dad = create(:relationship_profile, user:, first_name: spanish ? "Papá" : "Dad", preferred_name: nil)
            user.automation_permissions.create!(relationship_profile: dad, capability: "send_reminders", mode: "allow_automatically")
            title = spanish ? "Llamar a Papá" : "Call Dad"
            lookup_person(name: dad.first_name, person: dad)
            provider_responses.next_response { provider_responses.tool("capabilities", capabilities: [ "commitments" ]) }
            provider_responses.next_response do |payload|
              expect_tools(payload, "commitments_create")
              provider_responses.tool("commitments_create", relationship_profile_id: dad.id, title:, due_on: "2026-09-11")
            end
            answer_after_result(spanish ? "¿A qué hora el viernes?" : "What time on Friday?", "succeeded", "2026-09-11")
            submit_message(spanish ? "Prometí llamar a Papá el viernes. Recuérdamelo." : "I promised to call Dad on Friday. Remind me.")
            commitment = dad.commitments.sole

            provider_responses.next_response do |payload|
              expect(payload.fetch("messages").to_json).to include(commitment.id)
              provider_responses.tool("capabilities", capabilities: %w[commitments reminders])
            end
            provider_responses.next_response { provider_responses.tool("commitments_read", relationship_profile_id: dad.id, id: commitment.id) }
            provider_responses.next_response do |payload|
              expect(provider_responses.tool_result(payload)).to include(commitment.id, "2026-09-11")
              provider_responses.tool("reminders_create", relationship_profile_id: dad.id, commitment_id: commitment.id,
                title:, reminder_type: "promise_follow_up", scheduled_at: "2026-09-11T09:00:00-06:00")
            end
            answer_after_result(title, "succeeded", commitment.id)
            submit_message(spanish ? "A las 9 de la mañana." : "At 9 in the morning.")

            expect(user.reminders.sole).to have_attributes(commitment_id: commitment.id,
              scheduled_at: Time.iso8601("2026-09-11T09:00:00-06:00"))
          end

          it "reads current priorities using their real saved sources" do
            title = spanish ? "Preguntar por el trabajo" : "Ask about the job"
            commitment = create(:commitment, relationship_profile: profile, title:, due_on: Date.current - 1)
            provider_responses.next_response { provider_responses.tool("capabilities", capabilities: [ "priorities" ]) }
            provider_responses.next_response do |payload|
              expect_tools(payload, "priorities_search")
              provider_responses.tool("priorities_search")
            end
            answer_after_result(title, "succeeded", commitment.id, title)

            turn = submit_message(spanish ? "¿Qué debería retomar esta semana?" : "What should I follow up on this week?")

            expect(turn.actions.sole.name).to eq("priorities.search")
            expect(commitment.reload).not_to be_completed
          end
        end
      end

      it "returns invalid arguments to the model without writing or creating success receipts" do
        arguments = [ { relationship_profile_id: profile.id, title: "Missing body" },
          { relationship_profile_id: profile.id, title: "Tea", body: "Tea", user_id: user.id },
          [ "Not an argument object" ] ]
        arguments.each_with_index do |values, index|
          provider_responses.next_response do |payload|
            expect(provider_responses.tool_result(payload)).to include("invalid_arguments") if index.positive?
            provider_responses.tool("memories_create", values)
          end
        end
        answer_after_result("Please clarify the memory.", "invalid_arguments")

        turn = submit_message("Remember something about Ana.")

        expect(profile.memory_records).to be_empty
        expect(turn.actions).to be_empty
      end

      it "rejects another owner's records through the real tool boundary" do
        foreign = create(:relationship_profile, first_name: "Private person")
        secret = foreign.memory_records.create!(title: "Private detail", body: "Never disclose this source")
        provider_responses.next_response { provider_responses.tool("people_read", id: foreign.id) }
        provider_responses.next_response do |payload|
          result = provider_responses.tool_result(payload)
          expect(result).to include("unavailable")
          expect(result).not_to include(foreign.first_name, secret.body)
          provider_responses.tool("memories_create", relationship_profile_id: foreign.id, title: "Unwanted", body: "Unwanted")
        end
        answer_after_result("That record is unavailable.", "unavailable")

        turn = submit_message("Remember tea for that person.")

        expect(foreign.memory_records.sole).to eq(secret)
        expect(turn.actions).to be_empty
      end

      it "deduplicates repeated model mutations and repeated browser submissions" do
        values = { relationship_profile_id: profile.id, title: "Tea", body: "Ana likes green tea" }
        provider_responses.next_response { provider_responses.tool("memories_create", values) }
        provider_responses.next_response do |payload|
          expect(provider_responses.tool_result(payload)).to include(profile.memory_records.sole.id)
          provider_responses.tool("memories_create", values)
        end
        answer_after_result("Saved.", "succeeded")
        request_key = SecureRandom.uuid
        content = "Remember Ana likes green tea."
        turn = submit_message(content, request_key:)

        expect(profile.memory_records.count).to eq(1)
        expect(turn.actions.sole.name).to eq("memories.create")
        expect do
          post concierge_conversation_concierge_turns_path(conversation, locale:), params: {
            concierge_message: { content:, request_key: }
          }
        end.not_to have_enqueued_job(ConciergeResponseJob)
        expect(conversation.turns.count).to eq(1)
        expect(provider_responses.requests.length).to eq(3)
      end

      it "preserves completed writes after a provider failure and retries without duplicating them" do
        values = { relationship_profile_id: profile.id, title: "Tea", body: "Ana likes green tea" }
        provider_responses.next_response { provider_responses.tool("memories_create", values) }
        provider_responses.next_response do
          [ 401, { "Content-Type" => "application/json" }, JSON.generate(error: { message: "Synthetic provider failure" }) ]
        end
        turn = submit_message("Remember Ana likes green tea.", expected_state: "failed")
        memory = profile.memory_records.sole
        expect(turn).to have_attributes(error_code: "provider_unavailable", response: nil)
        expect(turn.actions.sole.state).to eq("succeeded")

        provider_responses.next_response { provider_responses.tool("memories_create", values) }
        answer_after_result("Saved.", "succeeded", memory.id)
        expect do
          post retry_concierge_conversation_concierge_turn_path(conversation, turn, locale:)
        end.to have_enqueued_job(ConciergeResponseJob).with(turn.id)
        perform_enqueued_jobs(only: ConciergeResponseJob)
        provider_responses.verify!

        expect(turn.reload).to have_attributes(state: "completed", response: "Saved.", attempts: 2)
        expect(profile.memory_records.sole).to eq(memory)
        expect(turn.actions.count).to eq(1)
      end

      it "fails a malformed tool-call response recoverably before executing a mutation" do
        provider_responses.next_response do
          malformed = provider_responses.tool("memories_create", title: "Tea")
          malformed.fetch("choices").first.fetch("message").fetch("tool_calls").sole.fetch("function")["arguments"] = '{"title":'
          malformed
        end

        turn = submit_message("Remember Ana likes tea.", expected_state: "failed")

        expect(turn).to have_attributes(error_code: "provider_unavailable", response: nil)
        expect(profile.memory_records).to be_empty
        expect(turn.actions).to be_empty
      end

      it "never interprets tool-shaped answer text as an application command" do
        provider_responses.next_response do
          provider_responses.answer(JSON.generate(tool_calls: [ { name: "memories_create",
            arguments: { relationship_profile_id: profile.id, title: "Tea", body: "Tea" } } ]))
        end

        turn = submit_message("Remember Ana likes tea.")

        expect(profile.memory_records).to be_empty
        expect(turn.actions).to be_empty
      end
    end
  end
end
