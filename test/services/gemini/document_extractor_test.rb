require "test_helper"

module Gemini
  class DocumentExtractorTest < ActiveSupport::TestCase
    FakeResponse = Struct.new(:code, :body)

    def stub_http_post(response)
      original = Net::HTTP.method(:post)
      Net::HTTP.define_singleton_method(:post) { |*| response }
      yield
    ensure
      Net::HTTP.define_singleton_method(:post, original)
    end

    test "translates a Gemini quota (429) error into a Turkish message, never leaking the raw English text" do
      raw_body = { error: { code: 429, message: "Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_requests, limit: 20" } }.to_json
      response = FakeResponse.new("429", raw_body)

      ENV["GEMINI_API_KEY"] = "test-key"
      error = assert_raises(DocumentExtractor::ExtractionError) do
        stub_http_post(response) do
          DocumentExtractor.call(pdf_binary: "x", prompt: "p", tool_name: "t", tool_description: "d", input_schema: { type: "object", properties: {} })
        end
      end

      assert_match(/kota/i, error.message)
      assert_no_match(/Quota exceeded/, error.message)
      assert_no_match(/generativelanguage/, error.message)
    ensure
      ENV.delete("GEMINI_API_KEY")
    end

    test "translates a generic Gemini server error into a Turkish message" do
      response = FakeResponse.new("503", { error: { message: "Service Unavailable" } }.to_json)
      ENV["GEMINI_API_KEY"] = "test-key"

      error = assert_raises(DocumentExtractor::ExtractionError) do
        stub_http_post(response) do
          DocumentExtractor.call(pdf_binary: "x", prompt: "p", tool_name: "t", tool_description: "d", input_schema: { type: "object", properties: {} })
        end
      end

      assert_match(/yanıt vermiyor/i, error.message)
      assert_no_match(/Service Unavailable/, error.message)
    ensure
      ENV.delete("GEMINI_API_KEY")
    end
  end
end
