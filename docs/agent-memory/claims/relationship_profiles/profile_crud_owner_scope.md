---
id: relationship_profiles.profile_crud_owner_scope
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: important

title: Relationship profile CRUD is owner scoped

claim: >
  Relationship profiles are authenticated, user-owned records for core details,
  localized and searchable Rails STI-backed relationship types across common
  family, romantic, work, school, community, care, and professional categories,
  nested add/edit/remove contact methods, associated add/edit/remove Lexxy/Action
  Text-backed rich relationship notes, associated add/edit/remove structured
  preferences and tags with in-memory duplicate checks matching their normalized
  case-insensitive indexes, friendly slugs, and discard-backed archive status;
  RelationshipProfilesController sanitizes tampered STI and contact-kind
  discriminator params before assignment, index preloads tags and rich notes for
  profile cards, and RelationshipProfilePolicy and policy scopes restrict CRUD,
  archive, search, and filter access to the signed-in owner.

source_files:
  - app/models/user.rb
  - app/models/relationship_profile.rb
  - app/models/acquaintance_relationship_profile.rb
  - app/models/advisor_relationship_profile.rb
  - app/models/aunt_relationship_profile.rb
  - app/models/best_friend_relationship_profile.rb
  - app/models/boss_relationship_profile.rb
  - app/models/brother_relationship_profile.rb
  - app/models/business_partner_relationship_profile.rb
  - app/models/caregiver_relationship_profile.rb
  - app/models/care_recipient_relationship_profile.rb
  - app/models/child_relationship_profile.rb
  - app/models/classmate_relationship_profile.rb
  - app/models/client_relationship_profile.rb
  - app/models/coach_relationship_profile.rb
  - app/models/community_member_relationship_profile.rb
  - app/models/cousin_relationship_profile.rb
  - app/models/coworker_relationship_profile.rb
  - app/models/customer_relationship_profile.rb
  - app/models/daughter_relationship_profile.rb
  - app/models/direct_report_relationship_profile.rb
  - app/models/doctor_relationship_profile.rb
  - app/models/extended_family_relationship_profile.rb
  - app/models/friend_relationship_profile.rb
  - app/models/family_relationship_profile.rb
  - app/models/father_relationship_profile.rb
  - app/models/fiance_relationship_profile.rb
  - app/models/fiancee_relationship_profile.rb
  - app/models/grandchild_relationship_profile.rb
  - app/models/grandfather_relationship_profile.rb
  - app/models/grandmother_relationship_profile.rb
  - app/models/grandparent_relationship_profile.rb
  - app/models/guardian_relationship_profile.rb
  - app/models/housemate_relationship_profile.rb
  - app/models/in_law_relationship_profile.rb
  - app/models/manager_relationship_profile.rb
  - app/models/mentor_relationship_profile.rb
  - app/models/mentee_relationship_profile.rb
  - app/models/mother_relationship_profile.rb
  - app/models/colleague_relationship_profile.rb
  - app/models/neighbor_relationship_profile.rb
  - app/models/nephew_relationship_profile.rb
  - app/models/niece_relationship_profile.rb
  - app/models/other_relationship_profile.rb
  - app/models/parent_relationship_profile.rb
  - app/models/partner_relationship_profile.rb
  - app/models/roommate_relationship_profile.rb
  - app/models/sibling_relationship_profile.rb
  - app/models/significant_other_relationship_profile.rb
  - app/models/sister_relationship_profile.rb
  - app/models/son_relationship_profile.rb
  - app/models/spouse_relationship_profile.rb
  - app/models/stepparent_relationship_profile.rb
  - app/models/student_relationship_profile.rb
  - app/models/teacher_relationship_profile.rb
  - app/models/teammate_relationship_profile.rb
  - app/models/therapist_relationship_profile.rb
  - app/models/uncle_relationship_profile.rb
  - app/models/vendor_relationship_profile.rb
  - app/models/contact_method.rb
  - app/models/relationship_note.rb
  - app/models/relationship_preference.rb
  - app/models/relationship_tag.rb
  - app/queries/relationship_profile/search_query.rb
  - app/controllers/relationship_profiles_controller.rb
  - app/policies/relationship_profile_policy.rb
  - config/routes.rb
  - db/migrate/20260625120000_create_relationship_profiles.rb
  - db/migrate/20260625120100_create_contact_methods.rb
  - db/migrate/20260625120200_create_relationship_notes.rb
  - db/migrate/20260625120300_create_relationship_preferences.rb
  - db/migrate/20260625120400_create_relationship_tags.rb
  - db/migrate/20260625120500_add_case_insensitive_relationship_indexes.rb
  - db/migrate/20260625121000_add_relationship_profile_integrity_constraints.rb
  - db/migrate/20260625121100_update_existing_relationship_profile_schema.rb
  - db/migrate/20260625121200_create_active_storage_tables.active_storage.rb
  - db/migrate/20260625121300_create_action_text_tables.action_text.rb
  - db/migrate/20260625121400_move_relationship_notes_to_action_text.rb
  - db/migrate/20260628120000_use_sti_and_associated_relationship_notes.rb

related_files:
  - app/javascript/application.js
  - app/views/layouts/application.html.erb
  - app/views/relationship_profiles/index.html.erb
  - app/views/relationship_profiles/new.html.erb
  - app/views/relationship_profiles/edit.html.erb
  - app/views/relationship_profiles/_form.html.erb
  - app/views/relationship_profiles/show.html.erb
  - spec/requests/relationship_profiles_spec.rb
  - spec/system/relationship_profile_edit_spec.rb
  - config/locales/en.yml
  - config/locales/es.yml
symbols:
  - User
  - RelationshipProfile
  - AcquaintanceRelationshipProfile
  - AdvisorRelationshipProfile
  - AuntRelationshipProfile
  - BestFriendRelationshipProfile
  - BossRelationshipProfile
  - BrotherRelationshipProfile
  - BusinessPartnerRelationshipProfile
  - CaregiverRelationshipProfile
  - CareRecipientRelationshipProfile
  - ChildRelationshipProfile
  - ClassmateRelationshipProfile
  - ClientRelationshipProfile
  - CoachRelationshipProfile
  - CommunityMemberRelationshipProfile
  - CousinRelationshipProfile
  - CoworkerRelationshipProfile
  - CustomerRelationshipProfile
  - DaughterRelationshipProfile
  - DirectReportRelationshipProfile
  - DoctorRelationshipProfile
  - ExtendedFamilyRelationshipProfile
  - FriendRelationshipProfile
  - FamilyRelationshipProfile
  - FatherRelationshipProfile
  - FianceRelationshipProfile
  - FianceeRelationshipProfile
  - GrandchildRelationshipProfile
  - GrandfatherRelationshipProfile
  - GrandmotherRelationshipProfile
  - GrandparentRelationshipProfile
  - GuardianRelationshipProfile
  - HousemateRelationshipProfile
  - InLawRelationshipProfile
  - ManagerRelationshipProfile
  - MentorRelationshipProfile
  - MenteeRelationshipProfile
  - MotherRelationshipProfile
  - ColleagueRelationshipProfile
  - NeighborRelationshipProfile
  - NephewRelationshipProfile
  - NieceRelationshipProfile
  - OtherRelationshipProfile
  - ParentRelationshipProfile
  - PartnerRelationshipProfile
  - RoommateRelationshipProfile
  - SiblingRelationshipProfile
  - SignificantOtherRelationshipProfile
  - SisterRelationshipProfile
  - SonRelationshipProfile
  - SpouseRelationshipProfile
  - StepparentRelationshipProfile
  - StudentRelationshipProfile
  - TeacherRelationshipProfile
  - TeammateRelationshipProfile
  - TherapistRelationshipProfile
  - UncleRelationshipProfile
  - VendorRelationshipProfile
  - ContactMethod
  - RelationshipNote
  - RelationshipPreference
  - RelationshipTag
  - RelationshipProfile::SearchQuery
  - RelationshipProfilesController
  - RelationshipProfilePolicy
routes:
  - relationship_profiles
  - relationship_profile
  - archive_relationship_profile
tags:
  - relationship_profiles
  - pundit
  - ransack
  - action_text
  - lexxy
  - privacy

verification:
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb
  - bundle exec rspec spec/models/contact_method_spec.rb spec/models/relationship_profile_spec.rb spec/models/relationship_note_spec.rb spec/models/relationship_preference_spec.rb
  - bundle exec rspec spec/queries/relationship_profile/search_query_spec.rb
  - bundle exec rspec spec/system/relationship_profile_edit_spec.rb
  - bundle exec rspec spec/system/relationship_profile_lexxy_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Relationship profile CRUD is owner scoped

## Claim

Relationship profiles are authenticated, user-owned records for core details,
localized and searchable Rails STI-backed relationship types across common
family, romantic, work, school, community, care, and professional categories,
nested add/edit/remove contact methods, associated add/edit/remove Lexxy/Action
Text-backed rich relationship notes, associated add/edit/remove structured
preferences and tags with in-memory duplicate checks matching their normalized
case-insensitive indexes, friendly slugs, and discard-backed archive status;
`RelationshipProfilesController` sanitizes tampered STI and contact-kind
discriminator params before assignment, index preloads tags and rich notes for
profile cards, and `RelationshipProfilePolicy` and policy scopes restrict CRUD,
archive, search, and filter access to the signed-in owner.

## Why It Matters

Relationship data is sensitive and foundational to Carecierge. Future reminders,
automation, and sharing work should reference profiles through the owner-scoped
relationship profile boundary rather than introducing parallel personal-context
stores.

## Evidence

- `app/models/relationship_profile.rb`
- `app/models/*_relationship_profile.rb`
- `app/models/friend_relationship_profile.rb`
- `app/models/family_relationship_profile.rb`
- `app/models/mentor_relationship_profile.rb`
- `app/models/colleague_relationship_profile.rb`
- `app/models/neighbor_relationship_profile.rb`
- `app/models/other_relationship_profile.rb`
- `app/models/user.rb`
- `app/models/relationship_preference.rb`
- `app/queries/relationship_profile/search_query.rb`
- `app/controllers/relationship_profiles_controller.rb`
- `app/policies/relationship_profile_policy.rb`
- `app/views/relationship_profiles/show.html.erb`
- `app/views/relationship_profiles/new.html.erb`
- `app/views/relationship_profiles/edit.html.erb`
- `app/views/relationship_profiles/_form.html.erb`
- `spec/requests/relationship_profiles_spec.rb`
- `spec/system/relationship_profile_edit_spec.rb`
- `app/javascript/application.js`
- `config/routes.rb`
- `db/migrate/20260625120500_add_case_insensitive_relationship_indexes.rb`
- `db/migrate/20260625121000_add_relationship_profile_integrity_constraints.rb`
- `db/migrate/20260625121100_update_existing_relationship_profile_schema.rb`
- `db/migrate/20260628120000_use_sti_and_associated_relationship_notes.rb`
- `db/migrate/20260625121400_move_relationship_notes_to_action_text.rb`
- `db/migrate/20260625120300_create_relationship_preferences.rb`

## Verification

- `bundle exec rspec spec/models/contact_method_spec.rb spec/models/relationship_profile_spec.rb spec/models/relationship_note_spec.rb spec/models/relationship_preference_spec.rb`
- `bundle exec rspec spec/queries/relationship_profile/search_query_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb`
- `bundle exec rspec spec/system/relationship_profile_edit_spec.rb`
- `bundle exec rspec spec/system/relationship_profile_lexxy_spec.rb`
- `bundle exec rspec`
