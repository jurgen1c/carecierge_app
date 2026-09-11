require "rails_helper"

RSpec.describe "Concierge follow-through journeys", type: :system do
  include ActiveJob::TestHelper

  around { |example| Timecop.freeze(Time.zone.parse("2026-09-08 10:00:00")) { example.run } }

  def stub_concierge(&behavior)
    allow_any_instance_of(Concierge::Agent).to receive(:call) do |_agent, turn:, token:, &stream|
      execute = ->(name, arguments = {}) { Concierge::Execute.call(turn:, token:, name:, arguments:) }
      answer = behavior.call(turn, execute)
      stream.call(answer)
      { content: answer }
    end
  end

  def send_message(message, expecting:)
    fill_in I18n.t("concierge.message_label", locale:), with: message
    perform_enqueued_jobs(only: ConciergeResponseJob) do
      click_button I18n.t("concierge.send", locale:)
      expect(page).to have_current_path(%r{/concierge/[0-9a-f-]+}, ignore_query: true)
      expect(page).to have_content(expecting, wait: 10)
    end
    expect(page).to have_no_css("[data-busy='true']")
    expect(page).to have_no_content("Translation missing")
    @journey_conversation_id ||= page.current_path.split("/").last
    expect(page.current_path.split("/").last).to eq(@journey_conversation_id)
    expect(user.concierge_conversations.count).to eq(1)
  end

  %w[en es].each do |language|
    context "in #{language}" do
      let(:locale) { language }
      let(:spanish) { locale == "es" }
      let(:user) { create(:user, onboarding_completed_at: Time.current) }
      let(:profile) { create(:relationship_profile, user:, first_name: "Ana", preferred_name: nil) }

      before do
        create(:notification_preference, user:, time_zone: "America/Costa_Rica")
        sign_in user
      end

      it "recalls a real job recap with its source and reports a missing detail truthfully" do
        title = spanish ? "Nuevo trabajo" : "New job"
        body = spanish ? "Ana empieza el lunes en la biblioteca." : "Ana starts at the library on Monday."
        recap = create(:conversation_recap, relationship_profile: profile, title:, body:)
        missing = spanish ? "No hay un sueldo guardado para Ana." : "There is no saved salary detail for Ana."
        stub_concierge do |turn, execute|
          found = execute.call("people.search", { query: "Ana" }).fetch("records").sole
          results = execute.call("recaps.search", { relationship_profile_id: found.fetch("id"), query: turn.content.include?("?") ? title : "salary-not-recorded" }).fetch("records")
          results.any? ? results.sole.fetch("body") : missing
        end
        visit concierge_conversations_path(locale:)
        send_message(spanish ? "¿Qué me contó Ana sobre su nuevo trabajo?" : "What did Ana tell me about her new job?", expecting: body)
        expect(page).to have_link(title, href: relationship_profile_path(profile.id, locale: spanish ? locale : nil, anchor: "conversation_recap_#{recap.id}"))
        send_message(spanish ? "Busca el sueldo que mencionó" : "Find the salary she mentioned", expecting: missing)
        expect(profile.memory_records).to be_empty
      end

      it "plans next month's birthday, follows up on its size and clarifies the reminder time" do
        date = create(:important_date, relationship_profile: profile, date_type: "birthday", starts_on: "2026-10-20", recurrence: "yearly")
        user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "ask_every_time")
        title = spanish ? "Cumpleaños de Ana" : "Ana's birthday"
        small = spanish ? "Cuatro personas cercanas" : "Four close people"
        question = spanish ? "¿A qué hora quieres el recordatorio del 13 de octubre?" : "What time should the October 13 reminder be?"
        ready = spanish ? "Revisa el recordatorio para las nueve." : "Review the reminder for nine."
        stub_concierge do |turn, execute|
          if turn.content.include?("9")
            references = Concierge::History.messages(turn:).map { |message| message[:content] }.join
            plan = user.event_plans.sole
            expect(references).to include(plan.id)
            execute.call("plans.read", { relationship_profile_id: profile.id, id: plan.id })
            execute.call("reminders.create", { relationship_profile_id: profile.id, title:, event_plan_id: plan.id,
              reminder_type: "event_preparation", scheduled_at: "2026-10-13T09:00:00-06:00" })
            ready
          elsif user.event_plans.exists?
            found = execute.call("plans.search", { relationship_profile_id: profile.id, query: title }).fetch("records").sole
            execute.call("plans.update", { relationship_profile_id: profile.id, id: found.fetch("id"), guest_list: small })
            question
          else
            found = execute.call("dates.search", { relationship_profile_id: profile.id }).fetch("records").sole
            execute.call("plans.create", { relationship_profile_id: profile.id, title:, occasion_type: "birthday", starts_on: "2026-10-20", important_date_id: found.fetch("id") })
            spanish ? "El plan de cumpleaños está listo." : "The birthday plan is ready."
          end
        end
        visit concierge_conversations_path(locale:)
        send_message(spanish ? "Empieza a planear el cumpleaños de Ana el próximo mes." : "Start planning Ana's birthday next month.", expecting: spanish ? "El plan de cumpleaños está listo." : "The birthday plan is ready.")
        plan = user.event_plans.sole
        expect(plan.source_context.sole.fetch("id")).to eq("important_date:#{date.id}")
        expect(plan.plan_tasks.current).not_to be_empty
        send_message(spanish ? "Que sea pequeño y agrega un recordatorio una semana antes." : "Keep it small and add a reminder a week before.", expecting: question)
        expect(plan.reload.guest_list).to eq(small)
        expect(user.reminders).to be_empty
        send_message(spanish ? "A las 9 de la mañana." : "At 9 in the morning.", expecting: ready)
        expect(user.reminders).to be_empty
        click_button I18n.t("concierge.decisions.approve", locale:)
        expect(page).to have_css(".concierge-receipt", text: I18n.t("concierge.action_states.succeeded", locale:))
        expect(user.reminders.sole).to have_attributes(event_plan_id: plan.id, scheduled_at: Time.iso8601("2026-10-13T09:00:00-06:00"))
        visit event_plan_path(plan, locale:)
        expect(page).to have_text(:all, title)
        visit edit_event_plan_path(plan, locale:)
        expect(page).to have_field("event_plan_guest_list", with: small)
      end

      it "records a Friday promise and its reminder on the same existing commitment" do
        dad = create(:relationship_profile, user:, first_name: spanish ? "Papá" : "Dad", preferred_name: nil)
        user.automation_permissions.create!(relationship_profile: dad, capability: "send_reminders", mode: "allow_automatically")
        title = spanish ? "Llamar a Papá" : "Call Dad"
        question = spanish ? "Guardé la promesa. ¿A qué hora el viernes?" : "I saved the promise. What time on Friday?"
        done = spanish ? "Te recordaré llamar a Papá el viernes a las nueve." : "I'll remind you to call Dad on Friday at nine."
        stub_concierge do |turn, execute|
          if turn.content.include?("9")
            found = execute.call("commitments.search", { relationship_profile_id: dad.id, query: title }).fetch("records").sole
            execute.call("reminders.create", { relationship_profile_id: dad.id, title:, commitment_id: found.fetch("id"), reminder_type: "promise_follow_up", scheduled_at: "2026-09-11T09:00:00-06:00" })
            done
          else
            execute.call("commitments.create", { relationship_profile_id: dad.id, title:, due_on: "2026-09-11" })
            question
          end
        end
        visit concierge_conversations_path(locale:)
        send_message(spanish ? "Prometí llamar a Papá el viernes. Recuérdamelo." : "I promised to call Dad on Friday. Remind me.", expecting: question)
        expect(dad.commitments.sole.due_on).to eq(Date.new(2026, 9, 11))
        send_message(spanish ? "A las 9." : "At 9.", expecting: done)
        expect(user.reminders.sole.commitment_id).to eq(dad.commitments.sole.id)
        visit reminders_path(locale:)
        expect(page).to have_text(:all, title)
      end

      it "reviews real priorities and completes the chosen follow-up through chat" do
        title = spanish ? "Preguntar por el trabajo de Ana" : "Ask about Ana's job"
        commitment = create(:commitment, relationship_profile: profile, title:, due_on: Date.current - 1)
        done = spanish ? "Marqué el seguimiento como completado." : "I marked the follow-up completed."
        stub_concierge do |turn, execute|
          if turn.content.include?("?")
            items = execute.call("priorities.search").fetch("records")
            expect(items.map { |record| record.fetch("id") }).to include(commitment.id)
            title
          else
            reference = Concierge::History.messages(turn:).map { |message| message[:content] }.join
            expect(reference).to include(commitment.id)
            execute.call("commitments.complete", { relationship_profile_id: profile.id, id: commitment.id })
            done
          end
        end
        visit concierge_conversations_path(locale:)
        send_message(spanish ? "¿A qué debería dar seguimiento esta semana?" : "What should I follow up on this week?", expecting: title)
        send_message(spanish ? "Ya lo hice, marca ese seguimiento como completado." : "I did that; mark the follow-up completed.", expecting: done)
        expect(commitment.reload).to be_completed
        last_turn = user.concierge_conversations.reload.sole.turns.to_a.find { |turn| turn.response == done }
        expect(Concierge::History.sources_current?(last_turn)).to be(true)
      end
    end
  end
end
