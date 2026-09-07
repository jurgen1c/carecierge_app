module DevelopmentSeeds
  class SharedJourneys
    def initialize(world)
      @world = world
    end

    def build
      owner = @world.users.fetch("owner_en")
      partner = @world.users.fetch("owner_es")
      couple = @world.put(SharedRelationshipSpace, "shared/couple", owner:, partner:,
        title: "Synthetic couple", invited_email: partner.email,
        invitation_expires_at: @world.at(7), accepted_at: @world.at(-7))
      family = @world.put(SharedRelationshipSpace, "shared/family", owner:, mode: "family", title: "Synthetic family")
      @world.put(FamilyMembership, "shared/member", shared_relationship_space: family,
        user: partner, invited_email: partner.email, relationship_type: "chosen_family",
        invitation_expires_at: @world.at(7), accepted_at: @world.at(-7))
      [ couple, family ].each do |space|
        @world.put(SharedItem, "shared/#{space.mode}/plan", shared_relationship_space: space,
          creator: owner, title: "Synthetic shared picnic", kind: "plan", editing: "participants")
      end
    end
  end
end
