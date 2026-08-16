# PDF önizleme ekranlarında (alış/satış) her satırın ürün adı için: zaten
# birebir eşleşiyorsa dokunma, eşleşmiyorsa "buna mı benziyor?" önerileri
# hesaplar (bkz. Product.suggest_matches). @line_matches, lines dizisiyle aynı
# sırada; her eleman { exact: Product|nil, suggestions: [Product, ...] }.
module ProductMatchSuggestions
  extend ActiveSupport::Concern

  private
    def build_line_matches(lines)
      Array(lines).map do |line|
        name = line[:name].to_s.strip
        exact = Product.match_by_name_or_alias(name)
        { exact: exact, suggestions: exact ? [] : Product.suggest_matches(name).to_a }
      end
    end
end
