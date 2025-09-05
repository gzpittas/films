# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_05_140259) do
  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.string "phones"
    t.string "emails"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "production_id", null: false
    t.index ["production_id"], name: "index_companies_on_production_id"
  end

  create_table "credits", force: :cascade do |t|
    t.string "role"
    t.integer "production_id", null: false
    t.integer "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_credits_on_person_id"
    t.index ["production_id"], name: "index_credits_on_production_id"
  end

  create_table "people", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "productions", force: :cascade do |t|
    t.string "title"
    t.string "status"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "production_type"
    t.string "network"
    t.text "description"
  end

  add_foreign_key "companies", "productions"
  add_foreign_key "credits", "people"
  add_foreign_key "credits", "productions"
end
