require "rails_helper"

RSpec.describe DigestMailer, type: :mailer do
  it "renders concise localized HTML and text alternatives" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "David")
    create(:commitment, relationship_profile: profile, title: "Send the book recommendation", due_on: now.to_date - 3.days)
    digest = Digests::Compose.call(user:, as_of: now, mode: "weekly")

    mail = described_class.with(recipient: user, digest:).summary

    expect(mail.to).to eq([ user.email ])
    expect(mail.subject).to eq("Your weekly relationship digest")
    expect(mail.html_part.body.encoded).to include("Start here", "Send the book recommendation", "3 days overdue")
    expect(mail.text_part.body.encoded).to include("Send the book recommendation")

    spanish = I18n.with_locale(:es) { described_class.with(recipient: user, digest:).summary.message }
    expect(spanish.subject).to eq("Tu resumen semanal de relaciones")
    expect(spanish.html_part.body.encoded).to include("Empieza aquí")
  end

  it "localizes generated check-in copy at render time" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Carlos")
    create(:contact_cadence, relationship_profile: profile, interval_days: 7, created_at: now - 8.days)
    digest = Digests::Compose.call(user:, as_of: now, mode: "daily")

    mail = I18n.with_locale(:es) { described_class.with(recipient: user, digest:).summary.message }

    expect(mail.html_part.body.encoded).to include("Comunícate con Carlos")
    expect(mail.html_part.body.encoded).not_to include("Check in with Carlos")
  end

  it "renders planning guidance once for every planning item in both alternatives" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    birthday_profile = create(:relationship_profile, user:, preferred_name: "Ana")
    anniversary_profile = create(:relationship_profile, user:, preferred_name: "Marta")
    create(:important_date, relationship_profile: birthday_profile, date_type: "birthday", starts_on: now.to_date + 20.days, recurrence: "none")
    create(:important_date, relationship_profile: anniversary_profile, date_type: "anniversary", starts_on: now.to_date + 21.days, recurrence: "none")
    digest = Digests::Compose.call(user:, as_of: now, mode: "weekly")

    mail = described_class.with(recipient: user, digest:).summary
    html = mail.html_part.body.decoded
    text = mail.text_part.body.decoded

    expect(html.scan("Plan ahead for this birthday.").size).to eq(1)
    expect(html.scan("Plan ahead for this anniversary.").size).to eq(1)
    expect(text.scan("Plan ahead for this birthday.").size).to eq(1)
    expect(text.scan("Plan ahead for this anniversary.").size).to eq(1)
    expect(html).to include("Aug 4, 2026", "Aug 5, 2026")
  end

  it "localizes important-date snapshot values at render time" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Ana")
    create(:important_date, relationship_profile: profile, date_type: "birthday", starts_on: now.to_date + 20.days, recurrence: "none")
    digest = Digests::Compose.call(user:, as_of: now, mode: "weekly")
    snapshot = Digests::Snapshot.dump(digest)

    mail = I18n.with_locale(:es) do
      described_class.with(recipient: user, digest_snapshot: snapshot).summary.message
    end

    expect(mail.html_part.body.decoded).to include("Cumpleaños", "Planear con tiempo para este cumpleaños.")
    expect(mail.html_part.body.decoded).not_to include("Birthday", "Plan ahead for this birthday.")
  end
end
