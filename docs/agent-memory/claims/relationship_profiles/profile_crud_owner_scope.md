---
id: relationship_profiles.profile_crud_owner_scope
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: important

title: Relationship profile CRUD is owner scoped

claim: >
  Relationship profiles are authenticated, user-owned records with localized
  searchable namespaced STI relationship types, contact methods, rich notes,
  preferences, reusable user-owned tags, relationship taggings, reusable
  user-owned relationship groups, group memberships, friendly slugs, archive
  state, and relationship field values. Suggested template IDs and custom labels are validated before
  persistence, custom field values remain required even when crafted params mark
  them hidden, template labels are stored canonically and localized only for
  display, default template installation preserves non-system templates that
  already own a default relationship type, template fields referenced by saved
  values are restricted from deletion, RelationshipProfiles::FormState prepares
  and memoizes form rows from
  preloaded template fields during a form render, sorts custom field value slots
  by position and label while preserving stored positions, and owns the
  selected/default/first fallback type exposed to Stimulus so an available
  suggested-field group remains visible when the selected relationship type has
  no template, preferring the default type only when it has a template, saved
  suggested values remain visible when the profile's
  relationship type has no active template, the show view reuses its visible
  relationship field values list during render, edit and show loaders preload
  tag and group assignment joins for form rendering, controller params sanitize
  discriminator inputs, tampered nested tag and group IDs fall back to
  name-based catalog assignment instead of raising, tag and group assignment
  cleanup skips delete queries when no assignments are marked for destruction
  and bulk-deletes marked join rows without destroy callbacks,
  tag and group filters are constrained by the signed-in owner's profile scope
  and catalog options, normalize accepted UUID params to lowercase for stable
  filter form state, and policy scopes restrict CRUD, archive, search, and
  filter access to the signed-in owner.

source_files:
  - app/models/relationship_profile.rb
  - app/models/relationship_profiles/acquaintance.rb
  - app/models/relationship_profiles/advisor.rb
  - app/models/relationship_profiles/aunt.rb
  - app/models/relationship_profiles/best_friend.rb
  - app/models/relationship_profiles/boss.rb
  - app/models/relationship_profiles/brother.rb
  - app/models/relationship_profiles/business_partner.rb
  - app/models/relationship_profiles/caregiver.rb
  - app/models/relationship_profiles/care_recipient.rb
  - app/models/relationship_profiles/child.rb
  - app/models/relationship_profiles/classmate.rb
  - app/models/relationship_profiles/client.rb
  - app/models/relationship_profiles/coach.rb
  - app/models/relationship_profiles/community_member.rb
  - app/models/relationship_profiles/cousin.rb
  - app/models/relationship_profiles/coworker.rb
  - app/models/relationship_profiles/customer.rb
  - app/models/relationship_profiles/daughter.rb
  - app/models/relationship_profiles/direct_report.rb
  - app/models/relationship_profiles/doctor.rb
  - app/models/relationship_profiles/extended_family.rb
  - app/models/relationship_profiles/friend.rb
  - app/models/relationship_profiles/family.rb
  - app/models/relationship_profiles/father.rb
  - app/models/relationship_profiles/fiance.rb
  - app/models/relationship_profiles/fiancee.rb
  - app/models/relationship_profiles/grandchild.rb
  - app/models/relationship_profiles/grandfather.rb
  - app/models/relationship_profiles/grandmother.rb
  - app/models/relationship_profiles/grandparent.rb
  - app/models/relationship_profiles/guardian.rb
  - app/models/relationship_profiles/housemate.rb
  - app/models/relationship_profiles/in_law.rb
  - app/models/relationship_profiles/manager.rb
  - app/models/relationship_profiles/mentor.rb
  - app/models/relationship_profiles/mentee.rb
  - app/models/relationship_profiles/mother.rb
  - app/models/relationship_profiles/colleague.rb
  - app/models/relationship_profiles/neighbor.rb
  - app/models/relationship_profiles/nephew.rb
  - app/models/relationship_profiles/niece.rb
  - app/models/relationship_profiles/other.rb
  - app/models/relationship_profiles/parent.rb
  - app/models/relationship_profiles/partner.rb
  - app/models/relationship_profiles/roommate.rb
  - app/models/relationship_profiles/sibling.rb
  - app/models/relationship_profiles/significant_other.rb
  - app/models/relationship_profiles/sister.rb
  - app/models/relationship_profiles/son.rb
  - app/models/relationship_profiles/spouse.rb
  - app/models/relationship_profiles/stepparent.rb
  - app/models/relationship_profiles/student.rb
  - app/models/relationship_profiles/teacher.rb
  - app/models/relationship_profiles/teammate.rb
  - app/models/relationship_profiles/therapist.rb
  - app/models/relationship_profiles/uncle.rb
  - app/models/relationship_profiles/vendor.rb
  - app/models/contact_method.rb
  - app/models/relationship_note.rb
  - app/models/relationship_preference.rb
  - app/models/relationship_tag.rb
  - app/models/relationship_tagging.rb
  - app/models/relationship_group.rb
  - app/models/relationship_group_membership.rb
  - app/models/relationship_template.rb
  - app/models/template_field.rb
  - app/models/relationship_field_value.rb
  - app/forms/relationship_profiles/form_state.rb
  - app/javascript/controllers/relationship_template_fields_controller.js
  - app/queries/relationship_profile/search_query.rb
  - app/controllers/relationship_profiles_controller.rb
  - app/policies/relationship_profile_policy.rb
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
  - db/migrate/20260701025353_create_relationship_templates.rb
  - db/migrate/20260703140000_add_relationship_taggings_and_groups.rb
  - db/migrate/20260703141000_remove_relationship_tag_profile_reference.rb
  - db/migrate/20260703142000_add_cascade_to_relationship_assignment_foreign_keys.rb

related_files:
  - app/models/user.rb
  - app/javascript/application.js
  - app/views/layouts/application.html.erb
  - app/views/relationship_profiles/index.html.erb
  - app/views/relationship_profiles/new.html.erb
  - app/views/relationship_profiles/edit.html.erb
  - app/views/relationship_profiles/_form.html.erb
  - app/views/relationship_profiles/show.html.erb
  - docs/agent-memory/claims/relationship_profiles/preference_metadata.md
  - config/routes.rb
  - spec/forms/relationship_profiles/form_state_spec.rb
  - spec/models/relationship_profile_spec.rb
  - spec/models/relationship_field_value_spec.rb
  - spec/models/relationship_group_spec.rb
  - spec/models/relationship_group_membership_spec.rb
  - spec/models/relationship_tagging_spec.rb
  - spec/models/template_field_spec.rb
  - spec/requests/relationship_profiles_spec.rb
  - spec/system/relationship_profile_edit_spec.rb
  - config/locales/en.yml
  - config/locales/es.yml
symbols:
  - RelationshipProfile
  - RelationshipProfiles::Acquaintance
  - RelationshipProfiles::Advisor
  - RelationshipProfiles::Aunt
  - RelationshipProfiles::BestFriend
  - RelationshipProfiles::Boss
  - RelationshipProfiles::Brother
  - RelationshipProfiles::BusinessPartner
  - RelationshipProfiles::Caregiver
  - RelationshipProfiles::CareRecipient
  - RelationshipProfiles::Child
  - RelationshipProfiles::Classmate
  - RelationshipProfiles::Client
  - RelationshipProfiles::Coach
  - RelationshipProfiles::CommunityMember
  - RelationshipProfiles::Cousin
  - RelationshipProfiles::Coworker
  - RelationshipProfiles::Customer
  - RelationshipProfiles::Daughter
  - RelationshipProfiles::DirectReport
  - RelationshipProfiles::Doctor
  - RelationshipProfiles::ExtendedFamily
  - RelationshipProfiles::Friend
  - RelationshipProfiles::Family
  - RelationshipProfiles::Father
  - RelationshipProfiles::Fiance
  - RelationshipProfiles::Fiancee
  - RelationshipProfiles::Grandchild
  - RelationshipProfiles::Grandfather
  - RelationshipProfiles::Grandmother
  - RelationshipProfiles::Grandparent
  - RelationshipProfiles::Guardian
  - RelationshipProfiles::Housemate
  - RelationshipProfiles::InLaw
  - RelationshipProfiles::Manager
  - RelationshipProfiles::Mentor
  - RelationshipProfiles::Mentee
  - RelationshipProfiles::Mother
  - RelationshipProfiles::Colleague
  - RelationshipProfiles::Neighbor
  - RelationshipProfiles::Nephew
  - RelationshipProfiles::Niece
  - RelationshipProfiles::Other
  - RelationshipProfiles::Parent
  - RelationshipProfiles::Partner
  - RelationshipProfiles::Roommate
  - RelationshipProfiles::Sibling
  - RelationshipProfiles::SignificantOther
  - RelationshipProfiles::Sister
  - RelationshipProfiles::Son
  - RelationshipProfiles::Spouse
  - RelationshipProfiles::Stepparent
  - RelationshipProfiles::Student
  - RelationshipProfiles::Teacher
  - RelationshipProfiles::Teammate
  - RelationshipProfiles::Therapist
  - RelationshipProfiles::Uncle
  - RelationshipProfiles::Vendor
  - ContactMethod
  - RelationshipNote
  - RelationshipPreference
  - RelationshipTag
  - RelationshipTagging
  - RelationshipGroup
  - RelationshipGroupMembership
  - RelationshipTemplate
  - TemplateField
  - RelationshipFieldValue
  - RelationshipProfiles::FormState
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
  - bundle exec rspec spec/forms/relationship_profiles/form_state_spec.rb spec/models/contact_method_spec.rb spec/models/relationship_profile_spec.rb spec/models/relationship_note_spec.rb spec/models/relationship_preference_spec.rb spec/models/relationship_template_spec.rb spec/models/template_field_spec.rb spec/models/relationship_field_value_spec.rb
  - bundle exec rspec spec/models/relationship_group_spec.rb spec/models/relationship_group_membership_spec.rb spec/models/relationship_tagging_spec.rb
  - bundle exec rspec spec/queries/relationship_profile/search_query_spec.rb
  - bundle exec rspec spec/system/relationship_profile_edit_spec.rb
  - bundle exec rspec spec/system/relationship_profile_lexxy_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Relationship profile CRUD is owner scoped

## Claim

Relationship profiles are authenticated, user-owned records with localized
searchable namespaced STI relationship types, contact methods, rich notes,
preferences, reusable user-owned tags and relationship groups, friendly slugs,
archive state, and relationship field values. Suggested template IDs and custom labels are validated before
persistence, template labels are stored canonically and localized only for
display, template fields referenced by saved values are restricted from
deletion, `RelationshipProfiles::FormState` prepares form rows from preloaded
template fields plus tag and group slots, controller params sanitize
discriminator inputs, tampered nested tag and group IDs fall back to name-based
catalog assignment instead of raising, edit form loads preload tag and group
assignment joins, tag and group assignment cleanup skips delete queries when no
assignments are marked for destruction and bulk-deletes marked join rows without
destroy callbacks, tag and group filters normalize accepted UUID params to
lowercase for stable filter form state, and policy scopes restrict CRUD,
archive, search, tag filters, and group filters to the signed-in owner.

## Why It Matters

Relationship data is sensitive and foundational to Carecierge. Future reminders,
automation, and sharing work should reference profiles through the owner-scoped
relationship profile boundary rather than introducing parallel personal-context
stores.

## Review Notes

CAR-25 reviewed this claim while adding nested important-date onboarding capture. The
owner-scoped profile boundary remains current; date-specific behavior is owned by
`relationship_profiles.important_dates`.

## Evidence

- `app/models/relationship_profile.rb`
- `app/models/relationship_profiles/*.rb`
- `app/models/relationship_profiles/friend.rb`
- `app/models/relationship_profiles/family.rb`
- `app/models/relationship_profiles/mentor.rb`
- `app/models/relationship_profiles/colleague.rb`
- `app/models/relationship_profiles/neighbor.rb`
- `app/models/relationship_profiles/other.rb`
- `app/models/relationship_preference.rb`
- `app/models/relationship_tag.rb`
- `app/models/relationship_tagging.rb`
- `app/models/relationship_group.rb`
- `app/models/relationship_group_membership.rb`
- `app/models/relationship_template.rb`
- `app/models/template_field.rb`
- `app/models/relationship_field_value.rb`
- `app/forms/relationship_profiles/form_state.rb`
- `app/queries/relationship_profile/search_query.rb`
- `app/controllers/relationship_profiles_controller.rb`
- `app/policies/relationship_profile_policy.rb`
- `app/views/relationship_profiles/show.html.erb`
- `app/views/relationship_profiles/new.html.erb`
- `app/views/relationship_profiles/edit.html.erb`
- `app/views/relationship_profiles/_form.html.erb`
- `spec/requests/relationship_profiles_spec.rb`
- `spec/models/relationship_profile_spec.rb`
- `spec/models/relationship_template_spec.rb`
- `spec/models/relationship_field_value_spec.rb`
- `spec/models/relationship_group_spec.rb`
- `spec/models/relationship_group_membership_spec.rb`
- `spec/models/relationship_tagging_spec.rb`
- `spec/system/relationship_profile_edit_spec.rb`
- `app/javascript/application.js`
- `app/javascript/controllers/relationship_template_fields_controller.js`
- `db/migrate/20260625120500_add_case_insensitive_relationship_indexes.rb`
- `db/migrate/20260625121000_add_relationship_profile_integrity_constraints.rb`
- `db/migrate/20260625121100_update_existing_relationship_profile_schema.rb`
- `db/migrate/20260628120000_use_sti_and_associated_relationship_notes.rb`
- `db/migrate/20260625121400_move_relationship_notes_to_action_text.rb`
- `db/migrate/20260701025353_create_relationship_templates.rb`
- `db/migrate/20260703140000_add_relationship_taggings_and_groups.rb`
- `db/migrate/20260703141000_remove_relationship_tag_profile_reference.rb`
- `db/migrate/20260703142000_add_cascade_to_relationship_assignment_foreign_keys.rb`
- `db/migrate/20260625120300_create_relationship_preferences.rb`

## Verification

- `bundle exec rspec spec/forms/relationship_profiles/form_state_spec.rb spec/models/contact_method_spec.rb spec/models/relationship_profile_spec.rb spec/models/relationship_note_spec.rb spec/models/relationship_preference_spec.rb spec/models/relationship_template_spec.rb spec/models/template_field_spec.rb spec/models/relationship_field_value_spec.rb`
- `bundle exec rspec spec/models/relationship_group_spec.rb spec/models/relationship_group_membership_spec.rb spec/models/relationship_tagging_spec.rb`
- `bundle exec rspec spec/queries/relationship_profile/search_query_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb`
- `bundle exec rspec spec/system/relationship_profile_edit_spec.rb`
- `bundle exec rspec spec/system/relationship_profile_lexxy_spec.rb`
- `bundle exec rspec`
