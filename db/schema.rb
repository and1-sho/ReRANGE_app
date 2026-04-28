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

ActiveRecord::Schema[7.1].define(version: 2026_04_27_113100) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "advices", force: :cascade do |t|
    t.text "body"
    t.integer "request_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "edited", default: false, null: false
    t.boolean "accepts_paid_advice", default: false, null: false
    t.boolean "paid_text_menu_enabled", default: false, null: false
    t.boolean "paid_text_video_menu_enabled", default: false, null: false
    t.index ["request_id", "user_id"], name: "index_advices_on_request_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_advices_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "request_id", null: false
    t.string "kind", null: false
    t.text "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "read_at"
    t.index ["request_id"], name: "index_notifications_on_request_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "paid_advice_requests", force: :cascade do |t|
    t.integer "advice_id", null: false
    t.integer "request_id", null: false
    t.integer "member_id", null: false
    t.integer "trainer_id", null: false
    t.string "menu_code", null: false
    t.integer "amount_jpy", null: false
    t.string "status", default: "checkout_started", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advice_id"], name: "index_paid_advice_requests_on_advice_id"
    t.index ["member_id"], name: "index_paid_advice_requests_on_member_id"
    t.index ["request_id"], name: "index_paid_advice_requests_on_request_id"
    t.index ["stripe_checkout_session_id"], name: "index_paid_advice_requests_on_stripe_checkout_session_id", unique: true
    t.index ["trainer_id"], name: "index_paid_advice_requests_on_trainer_id"
  end

  create_table "requests", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "directed_to_trainer_id"
    t.boolean "edited", default: false, null: false
    t.index ["directed_to_trainer_id"], name: "index_requests_on_directed_to_trainer_id"
    t.index ["user_id"], name: "index_requests_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.datetime "last_seen_at"
    t.string "profile_affiliation"
    t.string "profile_prefecture"
    t.string "profile_area_detail"
    t.date "boxing_started_on"
    t.date "instruction_started_on"
    t.text "profile_bio"
    t.integer "radar_attack", default: 0, null: false
    t.integer "radar_technique", default: 0, null: false
    t.integer "radar_physical", default: 0, null: false
    t.integer "radar_speed", default: 0, null: false
    t.integer "radar_strategy", default: 0, null: false
    t.integer "radar_defense", default: 0, null: false
    t.date "birth_date"
    t.string "stance"
    t.string "weight_class"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "advices", "requests"
  add_foreign_key "advices", "users"
  add_foreign_key "notifications", "requests"
  add_foreign_key "notifications", "users"
  add_foreign_key "paid_advice_requests", "advices"
  add_foreign_key "paid_advice_requests", "requests"
  add_foreign_key "paid_advice_requests", "users", column: "member_id"
  add_foreign_key "paid_advice_requests", "users", column: "trainer_id"
  add_foreign_key "requests", "users"
  add_foreign_key "requests", "users", column: "directed_to_trainer_id"
  add_foreign_key "requests", "users", column: "directed_to_trainer_id"
end
