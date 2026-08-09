class ProductTemplate < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :company

  has_many :template_lines, -> { order(:position) }, dependent: :destroy
  accepts_nested_attributes_for :template_lines, allow_destroy: true

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
