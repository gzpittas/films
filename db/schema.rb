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

ActiveRecord::Schema[8.0].define(version: 2025_09_06_213657) do
  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_companies_on_name"
  end

  create_table "credits", force: :cascade do |t|
    t.integer "production_id", null: false
    t.integer "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role_id"
    t.index ["person_id"], name: "index_credits_on_person_id"
    t.index ["production_id"], name: "index_credits_on_production_id"
    t.index ["role_id"], name: "index_credits_on_role_id"
  end

  create_table "email_addresses", force: :cascade do |t|
    t.string "email", null: false
    t.string "email_type", default: "primary"
    t.integer "person_id"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_email_addresses_on_company_id"
    t.index ["email"], name: "index_email_addresses_on_email"
    t.index ["person_id"], name: "index_email_addresses_on_person_id"
    t.check_constraint "(person_id IS NOT NULL AND company_id IS NULL) OR (person_id IS NULL AND company_id IS NOT NULL)", name: "email_belongs_to_person_or_company"
  end

  create_table "people", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_people_on_name"
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.string "number", null: false
    t.string "phone_type", default: "office"
    t.integer "person_id"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_phone_numbers_on_company_id"
    t.index ["number"], name: "index_phone_numbers_on_number"
    t.index ["person_id"], name: "index_phone_numbers_on_person_id"
    t.check_constraint "(person_id IS NOT NULL AND company_id IS NULL) OR (person_id IS NULL AND company_id IS NOT NULL)", name: "phone_belongs_to_person_or_company"
  end

  create_table "production_companies", force: :cascade do |t|
    t.integer "production_id", null: false
    t.integer "company_id", null: false
    t.string "relationship_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_production_companies_on_company_id"
    t.index ["production_id", "company_id"], name: "index_production_companies_on_production_id_and_company_id", unique: true
    t.index ["production_id"], name: "index_production_companies_on_production_id"
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
    t.integer "edition_number"
    t.index ["status"], name: "index_productions_on_status"
    t.index ["title"], name: "index_productions_on_title"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  add_foreign_key "credits", "people"
  add_foreign_key "credits", "productions"
  add_foreign_key "credits", "roles"
  add_foreign_key "email_addresses", "companies"
  add_foreign_key "email_addresses", "people"
  add_foreign_key "phone_numbers", "companies"
  add_foreign_key "phone_numbers", "people"
  add_foreign_key "production_companies", "companies"
  add_foreign_key "production_companies", "productions"
end
