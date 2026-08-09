module ApplicationHelper
  def company_logo?
    current_company&.logo&.attached? || false
  end

  def company_initials
    initials_for(current_company&.name, fallback: "??")
  end

  # Tedarikçi/müşteri kartlarında hızlı görsel kimlik için baş harf avatarı.
  def initials_for(name, fallback: "?")
    name.to_s.split.map { |word| word[0] }.join.first(2).upcase.presence || fallback
  end

  # Navbar'daki dört ana bölümden (Stok/Alış/Satış/Yönetim) hangisinin aktif
  # olduğunu, o an render edilen controller'a bakarak belirler — alt sekme
  # şeridinin (bkz. shared/_navbar) hangi grubu göstereceğini seçer.
  NAV_SECTIONS = {
    stok: %w[products categories stock_movements stock_adjustments product_templates template_lines],
    alis: %w[suppliers supplier_payments purchase_invoices purchase_invoice_items],
    satis: %w[customers customer_payments sales sale_items],
    yonetim: %w[users company_settings companies]
  }.freeze

  def current_nav_section
    # DashboardController hem misafir/işletme anasayfasını (index — kendi alt
    # sekmesi yok) hem İş Özeti'ni (summary — Yönetim'in bir parçası) render
    # ediyor, bu yüzden tek başına özel ele alınıyor.
    return :yonetim if controller_name == "dashboard" && action_name == "summary"
    NAV_SECTIONS.find { |_, controllers| controllers.include?(controller_name) }&.first
  end

  def sub_tab_class(*controllers)
    active = controllers.map(&:to_s).include?(controller_name)
    "sub-tab#{' active' if active}"
  end

  # Liste kolon başlıklarını tıklanabilir sıralama linkine çevirir — mevcut
  # arama/filtre parametrelerini korur, tekrar tıklayınca yönü (asc/desc)
  # değiştirir. `column`, çağıran controller'ın izin verdiği (whitelist)
  # bir sıralama anahtarı olmalı.
  def sortable_header(column, label)
    column = column.to_s
    current_sort = params[:sort]
    current_dir = params[:direction] == "desc" ? "desc" : "asc"
    active = current_sort == column
    next_dir = active && current_dir == "asc" ? "desc" : "asc"

    icon_class =
      if active
        current_dir == "asc" ? "bi-sort-alpha-down" : "bi-sort-alpha-up"
      else
        "bi-arrow-down-up"
      end

    link_to url_for(request.query_parameters.merge(sort: column, direction: next_dir, page: nil)), class: "sortable-th #{'active' if active}" do
      safe_join([ label, content_tag(:i, "", class: "bi #{icon_class} ms-1") ])
    end
  end

  # Sayfa numaralarını (1 2 3 … 30 gibi) makul bir pencereye sıkıştırır —
  # yüzlerce sayfa varsa hepsini tek tek basmamak için.
  def pagination_window(page, total_pages, radius: 2)
    return (1..total_pages).to_a if total_pages <= (radius * 2) + 5

    pages = ([ 1, 2 ] + ((page - radius)..(page + radius)).to_a + [ total_pages - 1, total_pages ])
      .select { |p| p.between?(1, total_pages) }
      .uniq.sort

    windowed = []
    pages.each_with_index do |p, i|
      windowed << :gap if i.positive? && p - pages[i - 1] > 1
      windowed << p
    end
    windowed
  end

  def category_badge(category)
    return content_tag(:span, "—", class: "text-muted") unless category
    content_tag(:span, category.name, class: "category-badge")
  end
end
