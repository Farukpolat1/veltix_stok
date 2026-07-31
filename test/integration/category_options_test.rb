require "test_helper"

class CategoryOptionsTest < ActionDispatch::IntegrationTest
  test "index lists the seeded brand/color/accessory type/series options" do
    sign_in_as users(:one)

    get category_options_path

    assert_response :success
    assert_includes @response.body, "Egepen"
    assert_includes @response.body, "Beyaz"
  end

  test "admin can add a new brand without touching code" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin
    brand_group = category_option_groups(:brand)

    assert_difference "CategoryOption.count", 1 do
      post category_options_path, params: { category_option: { category_option_group_id: brand_group.id, name: "Yeni Test Markası" } }
    end

    assert_redirected_to category_options_path
    assert_includes Category.brand_options, "Yeni Test Markası"
  end

  test "admin can remove an option and it disappears from the category form choices" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin
    option = CategoryOption.create!(category_option_group: category_option_groups(:brand), name: "Silinecek Marka")

    assert_difference "CategoryOption.count", -1 do
      delete category_option_path(option)
    end

    assert_not_includes Category.brand_options, "Silinecek Marka"
  end

  test "series options are manageable and appear on both profil and aksesuar category forms" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin
    series_group = category_option_groups(:series)

    assert_difference "CategoryOption.count", 1 do
      post category_options_path, params: { category_option: { category_option_group_id: series_group.id, name: "90 Serisi" } }
    end
    assert_includes Category.series_options, "90 Serisi"

    get new_category_path
    assert_response :success
    assert_select "select[name='category[series]'] option", text: "90 Serisi", count: 2
  end

  test "non-admin cannot add a new option" do
    depo_user = users(:two)
    depo_user.update!(role: :depo)
    sign_in_as depo_user
    brand_group = category_option_groups(:brand)

    assert_no_difference "CategoryOption.count" do
      post category_options_path, params: { category_option: { category_option_group_id: brand_group.id, name: "Yetkisiz Marka" } }
    end
  end

  test "admin can create a brand-new custom option group and add values under it" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin

    assert_difference "CategoryOptionGroup.count", 1 do
      post category_option_groups_path, params: { category_option_group: { name: "Kalınlık" } }
    end
    group = CategoryOptionGroup.find_by!(name: "Kalınlık")
    assert_not group.core?

    assert_difference "CategoryOption.count", 1 do
      post category_options_path, params: { category_option: { category_option_group_id: group.id, name: "24mm" } }
    end

    get new_category_path
    assert_response :success
    assert_select "select[name='category[custom_attributes][Kalınlık]'] option", text: "24mm"
  end

  test "custom category attribute is saved and shown on the category" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin
    group = CategoryOptionGroup.create!(name: "Kalınlık")
    CategoryOption.create!(category_option_group: group, name: "24mm")

    post categories_path, params: { category: { name: "Kalınlık Testi Kategori", product_type: "diger", custom_attributes: { "Kalınlık" => "24mm" } } }

    category = Category.find_by!(name: "Kalınlık Testi Kategori")
    assert_equal "24mm", category.custom_attributes["Kalınlık"]

    get categories_path
    assert_includes @response.body, "Kalınlık: 24mm"
  end

  test "core option groups (Marka, Renk, Aksesuar Alt Türü, Seri) cannot be deleted" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin
    brand_group = category_option_groups(:brand)

    assert_no_difference "CategoryOptionGroup.count" do
      delete category_option_group_path(brand_group)
    end
    assert_redirected_to category_options_path
  end
end
