# Bir kanadın genişlik/yükseklik ölçüsüne göre doğru donanım hücresini
# (HardwareSchemaCell) bulup içindeki parça listesini döndürür. Eşleşme
# yoksa (ör. ölçü tablo aralığının dışındaysa) hata fırlatır — sessizce
# yanlış/eksik donanım önermek, hiç önermemekten daha kötü.
class HardwareResolver
  class NoMatchingCellError < StandardError; end

  Result = Struct.new(:product, :quantity, keyword_init: true)

  def self.call(system:, acilim_tipi:, genislik_mm:, yukseklik_mm:)
    new(system: system, acilim_tipi: acilim_tipi, genislik_mm: genislik_mm, yukseklik_mm: yukseklik_mm).call
  end

  def initialize(system:, acilim_tipi:, genislik_mm:, yukseklik_mm:)
    @system = system
    @acilim_tipi = acilim_tipi
    @genislik_mm = genislik_mm
    @yukseklik_mm = yukseklik_mm
  end

  def call
    cell = HardwareSchemaCell.resolve(system: system, acilim_tipi: acilim_tipi, genislik_mm: genislik_mm, yukseklik_mm: yukseklik_mm)
    unless cell
      raise NoMatchingCellError, "#{system}/#{acilim_tipi} için #{genislik_mm}x#{yukseklik_mm} mm ölçüsünde eşleşen donanım hücresi bulunamadı."
    end

    cell.hardware_schema_lines.includes(:product).map { |line| Result.new(product: line.product, quantity: line.quantity) }
  end

  private
    attr_reader :system, :acilim_tipi, :genislik_mm, :yukseklik_mm
end
