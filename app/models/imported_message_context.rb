# == Schema Information
#
# Table name: imported_message_contexts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  lock_version            :integer          default(0), not null
#  reply_draft             :text
#  snippet                 :text             not null
#  source_key              :string           not null
#  subject                 :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  external_id             :text             not null
#  messaging_connection_id :uuid             not null
#  thread_id               :text             not null
#
# Indexes
#
#  idx_on_messaging_connection_id_source_key_d6f9fe6c82        (messaging_connection_id,source_key) UNIQUE
#  index_imported_message_contexts_on_messaging_connection_id  (messaging_connection_id)
#
# Foreign Keys
#
#  fk_rails_...  (messaging_connection_id => messaging_connections.id)
#
class ImportedMessageContext < ApplicationRecord
  belongs_to :messaging_connection
  encrypts :external_id, :thread_id, :subject, :snippet, :reply_draft
  validates :source_key, presence: true, uniqueness: { scope: :messaging_connection_id }
  validates :external_id, :thread_id, format: { with: /\A[0-9a-f]{1,64}\z/i }
  validates :subject, length: { maximum: 500 }
  validates :snippet, presence: true, length: { maximum: 2_000 }
  validates :reply_draft, length: { maximum: DraftRevision::MAX_CONTENT_LENGTH }
  attr_readonly :external_id, :thread_id, :source_key, :subject, :snippet, :messaging_connection_id

  def source_url = "https://mail.google.com/mail/?#{URI.encode_www_form(authuser: messaging_connection.mailbox_email)}#all/#{thread_id}"
  def ai_memory_extraction_allowed? = false
end
