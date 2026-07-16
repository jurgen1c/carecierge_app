class DigestEmailNotifier < Noticed::Event
  deliver_by :email do |config|
    config.mailer = "DigestMailer"
    config.method = :summary
  end

  validates :record, presence: true
end
