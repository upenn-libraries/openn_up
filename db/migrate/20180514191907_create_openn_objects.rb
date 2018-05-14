class CreateOpennObjects < ActiveRecord::Migration[5.1]
  def change
    create_table :openn_objects do |t|
      t.string :openn_id
      t.string :colenda_id
    end
  end
end
