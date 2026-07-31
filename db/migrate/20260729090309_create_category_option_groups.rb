class CreateCategoryOptionGroups < ActiveRecord::Migration[8.1]
  # option_type enum sırasıyla eşleşir: brand: 0, color: 1, accessory_type: 2, series: 3
  CORE_GROUPS = [ "Marka", "Renk", "Aksesuar Alt Türü", "Seri" ].freeze

  def up
    create_table :category_option_groups do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :category_option_groups, :name, unique: true

    now = Time.current
    group_ids = CORE_GROUPS.map do |name|
      execute("INSERT INTO category_option_groups (name, created_at, updated_at) VALUES (#{quote(name)}, #{quote(now)}, #{quote(now)}) RETURNING id")
        .first["id"]
    end

    add_column :category_options, :category_option_group_id, :bigint

    group_ids.each_with_index do |group_id, option_type|
      execute("UPDATE category_options SET category_option_group_id = #{group_id} WHERE option_type = #{option_type}")
    end

    change_column_null :category_options, :category_option_group_id, false
    add_index :category_options, :category_option_group_id
    add_foreign_key :category_options, :category_option_groups
    remove_index :category_options, [ :option_type, :name ]
    remove_column :category_options, :option_type
    add_index :category_options, [ :category_option_group_id, :name ], unique: true

    add_column :categories, :custom_attributes, :jsonb, null: false, default: {}
  end

  def down
    remove_column :categories, :custom_attributes
    add_column :category_options, :option_type, :integer
    remove_column :category_options, :category_option_group_id
    drop_table :category_option_groups
  end
end
