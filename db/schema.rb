# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140522233202) do

  create_table "algorithms", :force => true do |t|
    t.text     "name"
    t.text     "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "regression_distances_mi", :force => true do |t|
    t.string "type"
    t.string "height"
    t.string "reader_power"
    t.string "antenna_number"
    t.string "const"
    t.string "mi_coeff"
    t.string "angle_coeff"
    t.string "mi_type"
    t.string "mi_coeff_t"
    t.string "angle_coeff_t"
  end

  create_table "regression_mi_boundaries", :force => true do |t|
    t.integer "reader_power"
    t.string  "type"
    t.string  "min"
    t.string  "max"
  end

  create_table "regression_probabilities_distances", :force => true do |t|
    t.integer "reader_power"
    t.string  "ellipse_ratio"
    t.string  "coeffs"
    t.boolean "previous_rp_answered"
  end

end
