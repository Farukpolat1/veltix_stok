class AddPaymentMethodToCustomerPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_payments, :payment_method, :integer, default: 0, null: false
  end
end
