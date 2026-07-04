class RemoveRelationshipTagProfileReference < ActiveRecord::Migration[8.1]
  def up
    remove_index :relationship_tags, name: "index_relationship_tags_on_profile_id_and_lower_name", if_exists: true
    remove_reference :relationship_tags, :relationship_profile, foreign_key: true, type: :uuid if column_exists?(:relationship_tags, :relationship_profile_id)

    add_index :relationship_tags,
              "user_id, lower(name)",
              unique: true,
              name: "index_relationship_tags_on_user_id_and_lower_name",
              if_not_exists: true
  end

  def down
    unless column_exists?(:relationship_tags, :relationship_profile_id)
      add_reference :relationship_tags, :relationship_profile, type: :uuid, foreign_key: true
    end

    restore_profile_owned_tags

    add_index :relationship_tags,
              "relationship_profile_id, lower(name)",
              unique: true,
              name: "index_relationship_tags_on_profile_id_and_lower_name",
              if_not_exists: true
  end

  private

  def restore_profile_owned_tags
    remove_index :relationship_tags, name: "index_relationship_tags_on_user_id_and_lower_name", if_exists: true

    execute <<~SQL.squish
      WITH ranked_taggings AS (
        SELECT
          relationship_taggings.id AS tagging_id,
          relationship_taggings.relationship_profile_id,
          relationship_taggings.relationship_tag_id,
          relationship_tags.user_id,
          relationship_tags.name,
          relationship_tags.created_at,
          relationship_tags.updated_at,
          ROW_NUMBER() OVER (
            PARTITION BY relationship_taggings.relationship_tag_id
            ORDER BY relationship_taggings.created_at, relationship_taggings.id
          ) AS tag_position
        FROM relationship_taggings
        INNER JOIN relationship_tags
          ON relationship_tags.id = relationship_taggings.relationship_tag_id
      ),
      updated_existing_tags AS (
        UPDATE relationship_tags
        SET relationship_profile_id = ranked_taggings.relationship_profile_id
        FROM ranked_taggings
        WHERE relationship_tags.id = ranked_taggings.relationship_tag_id
          AND ranked_taggings.tag_position = 1
      )
      INSERT INTO relationship_tags (id, relationship_profile_id, user_id, name, created_at, updated_at)
      SELECT gen_random_uuid(), relationship_profile_id, user_id, name, created_at, updated_at
      FROM ranked_taggings
      WHERE tag_position > 1
    SQL

    execute <<~SQL.squish
      DELETE FROM relationship_tags
      WHERE relationship_profile_id IS NULL
    SQL
  end
end
