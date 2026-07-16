class PrivacyVault::Payload
  REDACTED_TEXT = PrivacyVaultItem::REDACTED_TEXT
  STANDARD_NOTE_TITLE_KEYS = {
    "General" => "general_note",
    "Private" => "private_note"
  }.freeze

  def initialize(protectable)
    @protectable = protectable
  end

  def dump
    case protectable
    when MemoryRecord
      {
        "title" => protectable.title,
        "body" => protectable.body,
        "revisions" => protectable.memory_revisions.map do |revision|
          revision.attributes.slice("id", "previous_body", "revised_body", "note")
        end
      }
    when RelationshipNote
      category = protectable.category.presence
      title_key = STANDARD_NOTE_TITLE_KEYS[category] || ("private_note" if category.blank?)
      {
        "title" => title_key ? nil : category,
        "title_key" => title_key,
        "category" => category,
        "body" => protectable.body.body.to_html
      }.compact
    when RelationshipFieldValue
      field_payload.merge("body" => protectable.value.to_s)
    else
      raise ArgumentError, "Unsupported vault record: #{protectable.class.name}"
    end
  end

  def redact!(item:)
    case protectable
    when MemoryRecord
      with_vault_transition do
        protectable.update!(title: REDACTED_TEXT, body: REDACTED_TEXT)
        protectable.memory_revisions.find_each do |revision|
          revision.update!(
            previous_body: REDACTED_TEXT,
            revised_body: REDACTED_TEXT,
            note: revision.note.present? ? REDACTED_TEXT : nil
          )
        end
      end
    when RelationshipNote
      with_vault_transition { protectable.update!(category: nil, body: REDACTED_TEXT) }
    when RelationshipFieldValue
      with_vault_transition do
        protectable.update!(
          label: protectable.custom? ? "[vault:#{item.id}]" : protectable.label,
          value: REDACTED_TEXT
        )
      end
    end
  end

  def restore!(payload:)
    case protectable
    when MemoryRecord
      with_vault_transition do
        protectable.update!(title: payload.fetch("title"), body: payload.fetch("body"))
        restore_memory_revisions!(payload.fetch("revisions", []))
      end
    when RelationshipNote
      with_vault_transition do
        protectable.update!(category: payload.fetch("category", payload["title"]), body: payload.fetch("body"))
      end
    when RelationshipFieldValue
      with_vault_transition do
        original_label = payload["title"] || payload.fetch("title_default")
        protectable.update!(label: restored_field_label(original_label), value: payload.fetch("body"))
      end
    end
  end

  private

  attr_reader :protectable

  def with_vault_transition
    protectable.privacy_vault_transition = true
    yield
  ensure
    protectable.privacy_vault_transition = false
  end

  def restore_memory_revisions!(revisions)
    revisions.each do |attributes|
      revision = protectable.memory_revisions.find(attributes.fetch("id"))
      revision.update!(attributes.slice("previous_body", "revised_body", "note"))
    end
  end

  def field_payload
    if protectable.template_field
      {
        "title_key" => "relationship_template_field",
        "template_field_key" => protectable.template_field.key,
        "title_default" => protectable.template_field.label
      }
    else
      { "title" => protectable.label }
    end
  end

  def restored_field_label(original_label)
    return original_label unless protectable.custom?
    return original_label unless field_label_taken?(original_label)

    base = I18n.t("privacy_vaults.restored_label", label: original_label)
    candidate = base
    suffix = 2

    while field_label_taken?(candidate)
      candidate = "#{base} #{suffix}"
      suffix += 1
    end

    candidate
  end

  def field_label_taken?(label)
    protectable.relationship_profile.relationship_field_values
      .where(custom: true)
      .where.not(id: protectable.id)
      .where("LOWER(label) = ?", label.downcase)
      .exists?
  end
end
