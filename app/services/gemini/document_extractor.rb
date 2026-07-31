require "net/http"
require "json"
require "base64"

module Gemini
  # PDF + "function calling" şemasıyla Gemini API'den yapılandırılmış JSON
  # çıkarır. Invoices::PdfImporter ve Invoices::SalePdfImporter tarafından
  # kullanılır — ikisi de aynı çıkarma mekaniğine ihtiyaç duyar, farkları
  # sadece şema ve sonuçtan hangi kaydın oluşturulacağıdır.
  class DocumentExtractor
    ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"
    DEFAULT_MODEL = "gemini-flash-latest"

    class ExtractionError < StandardError; end

    def self.call(...) = new(...).call

    def initialize(pdf_binary:, prompt:, tool_name:, tool_description:, input_schema:)
      @pdf_binary = pdf_binary
      @prompt = prompt
      @tool_name = tool_name
      @tool_description = tool_description
      @input_schema = input_schema
    end

    def call
      api_key = ENV["GEMINI_API_KEY"].presence or raise ExtractionError, "GEMINI_API_KEY tanımlı değil."

      uri = URI(format(ENDPOINT, model))
      uri.query = URI.encode_www_form(key: api_key)

      response = Net::HTTP.post(uri, request_body.to_json, "Content-Type" => "application/json")
      parsed = JSON.parse(response.body)

      raise ExtractionError, turkish_error_message(response) unless response.is_a?(Net::HTTPSuccess)

      function_call = parsed.dig("candidates", 0, "content", "parts")&.find { |part| part["functionCall"] }&.dig("functionCall")
      raise ExtractionError, "Gemini belgeden veri çıkaramadı." unless function_call

      function_call["args"].deep_symbolize_keys
    rescue JSON::ParserError
      raise ExtractionError, "Yapay zeka servisinin yanıtı okunamadı. Lütfen tekrar deneyin."
    rescue Timeout::Error, SocketError, EOFError
      raise ExtractionError, "Yapay zeka servisine ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin."
    end

    private
      # Google'ın ham (İngilizce) API hata metnini kullanıcıya hiç göstermeyiz —
      # durum koduna göre anlaşılır, Türkçe bir mesaja çeviririz.
      def turkish_error_message(response)
        case response.code.to_i
        when 429
          "Yapay zeka servisi şu anda çok fazla istek aldı (kota sınırı doldu). Lütfen birkaç dakika sonra tekrar deneyin."
        when 401, 403
          "Yapay zeka servisine erişim reddedildi. Sistem yöneticinizle iletişime geçin."
        when 500..599
          "Yapay zeka servisi şu anda yanıt vermiyor. Lütfen birkaç dakika sonra tekrar deneyin."
        else
          "Belge yapay zeka ile okunamadı. Lütfen tekrar deneyin."
        end
      end

      def model
        ENV["GEMINI_MODEL"].presence || DEFAULT_MODEL
      end

      def request_body
        {
          contents: [
            {
              parts: [
                { inline_data: { mime_type: "application/pdf", data: Base64.strict_encode64(@pdf_binary) } },
                { text: @prompt }
              ]
            }
          ],
          tools: [
            {
              function_declarations: [
                { name: @tool_name, description: @tool_description, parameters: normalize_schema(@input_schema) }
              ]
            }
          ],
          tool_config: {
            function_calling_config: { mode: "ANY", allowed_function_names: [ @tool_name ] }
          }
        }
      end

      # Şemalar bu servisin çağıranlarında Claude'un JSON Schema tarzıyla
      # (type: "object"/"string"/...) yazılmış — Gemini'nin Schema.Type enum'ı
      # büyük harf bekliyor (OBJECT/STRING/...), burada dönüştürüyoruz ki
      # çağıranlar tek bir şema tanımını her iki sağlayıcı için de kullanabilsin.
      def normalize_schema(schema)
        return schema unless schema.is_a?(Hash)

        schema.each_with_object({}) do |(key, value), result|
          result[key] =
            case key.to_s
            when "type" then value.is_a?(String) ? value.upcase : value
            when "properties" then value.is_a?(Hash) ? value.transform_values { |v| normalize_schema(v) } : value
            when "items" then normalize_schema(value)
            else value
            end
        end
      end
  end
end
