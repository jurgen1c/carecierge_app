class AddRelationshipTaggingsAndGroups < ActiveRecord::Migration[8.1]
  def up
    add_reference :relationship_tags, :user, type: :uuid, foreign_key: true unless column_exists?(:relationship_tags, :user_id)
    change_column_null :relationship_tags, :relationship_profile_id, true

    execute <<~SQL.squish
      UPDATE relationship_tags
      SET user_id = relationship_profiles.user_id
      FROM relationship_profiles
      WHERE relationship_tags.relationship_profile_id = relationship_profiles.id
        AND relationship_tags.user_id IS NULL
    SQL

    create_table :relationship_taggings, id: :uuid, if_not_exists: true do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.references :relationship_tag, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :relationship_taggings,
              %i[relationship_profile_id relationship_tag_id],
              unique: true,
              name: "index_relationship_taggings_on_profile_and_tag",
              if_not_exists: true

    execute <<~SQL.squish
      INSERT INTO relationship_taggings (id, relationship_profile_id, relationship_tag_id, created_at, updated_at)
      SELECT gen_random_uuid(), relationship_profile_id, id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM relationship_tags
      WHERE relationship_profile_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    deduplicate_relationship_tags
    change_column_null :relationship_tags, :user_id, false

    add_index :relationship_tags,
              "user_id, lower(name)",
              unique: true,
              name: "index_relationship_tags_on_user_id_and_lower_name",
              if_not_exists: true

    create_table :relationship_groups, id: :uuid, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false

      t.timestamps
    end

    add_index :relationship_groups,
              "user_id, lower(name)",
              unique: true,
              name: "index_relationship_groups_on_user_id_and_lower_name",
              if_not_exists: true

    create_table :relationship_group_memberships, id: :uuid, if_not_exists: true do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.references :relationship_group, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :relationship_group_memberships,
              %i[relationship_profile_id relationship_group_id],
              unique: true,
              name: "index_relationship_group_memberships_on_profile_and_group",
              if_not_exists: true
  end

  def down
    drop_table :relationship_group_memberships, if_exists: true
    drop_table :relationship_groups, if_exists: true
    drop_table :relationship_taggings, if_exists: true

    remove_index :relationship_tags, name: "index_relationship_tags_on_user_id_and_lower_name", if_exists: true
    remove_reference :relationship_tags, :user, foreign_key: true if column_exists?(:relationship_tags, :user_id)
    change_column_null :relationship_tags, :relationship_profile_id, false
  end

  private

  def deduplicate_relationship_tags
    execute <<~SQL.squish
      WITH canonical_tags AS (
        SELECT DISTINCT ON (user_id, lower(name))
          id AS canonical_id,
          user_id,
          lower(name) AS normalized_name
        FROM relationship_tags
        WHERE user_id IS NOT NULL
        ORDER BY user_id, lower(name), created_at, id
      ),
      duplicate_tags AS (
        SELECT relationship_tags.id AS duplicate_id, canonical_tags.canonical_id
        FROM relationship_tags
        INNER JOIN canonical_tags
          ON canonical_tags.user_id = relationship_tags.user_id
          AND canonical_tags.normalized_name = lower(relationship_tags.name)
        WHERE relationship_tags.id != canonical_tags.canonical_id
      )
      UPDATE relationship_taggings
      SET relationship_tag_id = duplicate_tags.canonical_id
      FROM duplicate_tags
      WHERE relationship_taggings.relationship_tag_id = duplicate_tags.duplicate_id
    SQL

    execute <<~SQL.squish
      DELETE FROM relationship_taggings current_tagging
      USING relationship_taggings duplicate_tagging
      WHERE current_tagging.ctid < duplicate_tagging.ctid
        AND current_tagging.relationship_profile_id = duplicate_tagging.relationship_profile_id
        AND current_tagging.relationship_tag_id = duplicate_tagging.relationship_tag_id
    SQL

    execute <<~SQL.squish
      WITH canonical_tags AS (
        SELECT DISTINCT ON (user_id, lower(name))
          id AS canonical_id,
          user_id,
          lower(name) AS normalized_name
        FROM relationship_tags
        WHERE user_id IS NOT NULL
        ORDER BY user_id, lower(name), created_at, id
      )
      DELETE FROM relationship_tags
      USING canonical_tags
      WHERE relationship_tags.user_id = canonical_tags.user_id
        AND lower(relationship_tags.name) = canonical_tags.normalized_name
        AND relationship_tags.id != canonical_tags.canonical_id
    SQL
  end
end
