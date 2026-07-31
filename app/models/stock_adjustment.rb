class StockAdjustment < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :product
  belongs_to :user
  has_one :stock_movement, as: :source, dependent: :destroy

  validates :reason, presence: true
  validates :quantity_before, :quantity_after, presence: true

  after_create :create_stock_movement

  def difference
    quantity_after - quantity_before
  end

  private
    def create_stock_movement
      return if difference.zero?

      StockMovement.create!(
        product: product,
        source: self,
        direction: difference.positive? ? :in : :out,
        quantity: difference.abs,
        occurred_at: adjusted_at,
        user: user,
        note: reason
      )
    end
end
