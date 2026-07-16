require "rails_helper"

RSpec.describe PrivacyVault::Protect do
  let(:user) { create(:user) }
  let(:relationship_profile) { create(:relationship_profile, user:) }

  it "moves a memory record into an encrypted vault payload and restores it" do
    memory = create(
      :memory_record,
      relationship_profile:,
      title: "Private anniversary plan",
      body: "Book the quiet table."
    )

    item = described_class.call(actor: user, protectable: memory)

    expect(memory.reload.title).not_to eq("Private anniversary plan")
    expect(item.payload).to include(
      "title" => "Private anniversary plan",
      "body" => "Book the quiet table."
    )
    expect(item).not_to be_suggestion_allowed

    PrivacyVault::Restore.call(actor: user, item:)

    expect(memory.reload).to have_attributes(
      title: "Private anniversary plan",
      body: "Book the quiet table."
    )
    expect(item).to be_destroyed
  end

  it "redacts memory revision plaintext and restores it with the memory" do
    memory = create(:memory_record, relationship_profile:, title: "Private plan", body: "Current secret")
    revision = create(
      :memory_revision,
      memory_record: memory,
      user:,
      previous_body: "Old secret",
      revised_body: "Current secret",
      note: "Why it changed"
    )

    item = described_class.call(actor: user, protectable: memory)

    expect(revision.reload.attributes.values_at("previous_body", "revised_body", "note")).not_to include(
      "Old secret",
      "Current secret",
      "Why it changed"
    )
    expect(item.payload.fetch("revisions").sole).to include(
      "previous_body" => "Old secret",
      "revised_body" => "Current secret",
      "note" => "Why it changed"
    )

    PrivacyVault::Restore.call(actor: user, item:)

    expect(revision.reload).to have_attributes(
      previous_body: "Old secret",
      revised_body: "Current secret",
      note: "Why it changed"
    )
  end

  it "moves an Action Text relationship note into the vault without leaving searchable plaintext" do
    note = create(
      :relationship_note,
      relationship_profile:,
      category: "Sensitive family context",
      body: "A private family concern"
    )

    item = described_class.call(actor: user, protectable: note)

    expect(note.reload.body.to_plain_text).not_to include("private family concern")
    expect(note.category).to be_nil
    expect(item.payload.fetch("title")).to eq("Sensitive family context")
    expect(item.payload.fetch("body")).to include("private family concern")

    PrivacyVault::Restore.call(actor: user, item:)

    expect(note.reload.body.to_plain_text).to eq("A private family concern")
    expect(note.category).to eq("Sensitive family context")
  end

  it "localizes the fallback title for an uncategorized relationship note" do
    note = create(:relationship_note, relationship_profile:, category: nil, body: "A private family concern")

    item = described_class.call(actor: user, protectable: note)

    expect(item.payload).to include("title_key" => "private_note")
    I18n.with_locale(:es) do
      expect(item.display_title).to eq(I18n.t("privacy_vaults.item_types.private_note", locale: :es))
    end
  end

  it "stores stable metadata and localizes standard note titles at display time" do
    note = create(:relationship_note, relationship_profile:, category: "General", body: "A private family concern")

    item = described_class.call(actor: user, protectable: note)

    expect(item.payload).to include("category" => "General", "title_key" => "general_note")
    expect(item.payload).not_to have_key("title")
    I18n.with_locale(:es) do
      expect(item.display_title).to eq(I18n.t("privacy_vaults.item_types.general_note", locale: :es))
    end

    PrivacyVault::Restore.call(actor: user, item:)
    expect(note.reload.category).to eq("General")
  end

  it "refuses to protect a rich-text note with embedded files without deleting them" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("private attachment"),
      filename: "private.txt",
      content_type: "text/plain"
    )
    attachment = ActionText::Attachment.from_attachable(blob)
    note = create(
      :relationship_note,
      relationship_profile:,
      body: "<p>A private family concern</p>#{attachment.to_html}"
    )

    expect do
      described_class.call(actor: user, protectable: note)
    end.to raise_error(ActiveRecord::RecordInvalid, /embedded files/i)

    expect(note.reload.body.embeds_blobs).to contain_exactly(blob)
    expect(blob.reload).to be_present
  end

  it "moves a relationship detail into the vault and restores its value" do
    detail = create(
      :relationship_field_value,
      relationship_profile:,
      template_field: nil,
      custom: true,
      label: "Family context",
      value: "Keep this detail private"
    )

    item = described_class.call(actor: user, protectable: detail)

    expect(detail.reload.value).not_to eq("Keep this detail private")
    expect(item.payload).to include("title" => "Family context", "body" => "Keep this detail private")

    PrivacyVault::Restore.call(actor: user, item:)

    expect(detail.reload.value).to eq("Keep this detail private")
  end

  it "stores canonical template metadata and localizes suggested field titles at display time" do
    template_field = create(:template_field, key: "communication_style", label: "Communication style")
    detail = create(
      :relationship_field_value,
      relationship_profile:,
      template_field:,
      value: "Keep this detail private"
    )

    item = I18n.with_locale(:es) { described_class.call(actor: user, protectable: detail) }

    expect(item.payload).to include(
      "title_key" => "relationship_template_field",
      "template_field_key" => "communication_style",
      "title_default" => "Communication style"
    )
    expect(item.payload).not_to have_key("title")
    I18n.with_locale(:es) do
      expect(item.display_title).to eq("Estilo de comunicación")
    end
  end

  it "restores a custom relationship detail when its original label was reused" do
    detail = create(
      :relationship_field_value,
      relationship_profile:,
      template_field: nil,
      custom: true,
      label: "Family context",
      value: "Keep this detail private"
    )
    item = described_class.call(actor: user, protectable: detail)
    create(
      :relationship_field_value,
      relationship_profile:,
      template_field: nil,
      custom: true,
      label: "Family context",
      value: "New detail"
    )

    expect { PrivacyVault::Restore.call(actor: user, item:) }.not_to raise_error
    expect(detail.reload.label).to eq("Family context (restored)")
    expect(detail.value).to eq("Keep this detail private")
  end

  it "rejects stale ordinary writes after a record is protected" do
    memory = create(:memory_record, relationship_profile:, title: "Private plan", body: "Secret")
    stale_copy = MemoryRecord.find(memory.id)

    described_class.call(actor: user, protectable: memory)

    expect do
      stale_copy.update!(title: "Leaked", body: "Plaintext leak")
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(memory.reload.body).not_to eq("Plaintext leak")
  end

  it "rejects records owned by another user" do
    memory = create(:memory_record)

    expect do
      described_class.call(actor: user, protectable: memory)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
