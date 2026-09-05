module Contacts
  class Matches
    def self.call(contact:)
      data = contact.data
      scope = contact.user.relationship_profiles.with_discarded
      names = scope.where("LOWER(first_name) = ? AND LOWER(COALESCE(last_name, '')) = ?", data["first_name"].to_s.downcase, data["last_name"].to_s.downcase)
      values = [ data["email"], data["phone"] ].compact_blank.map(&:downcase)
      methods = ContactMethod.where("LOWER(value) IN (?)", values).select(:relationship_profile_id)
      names.or(scope.where(id: methods)).order(:id).limit(20)
    end
  end
end
