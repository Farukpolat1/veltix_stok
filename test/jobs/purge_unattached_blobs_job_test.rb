require "test_helper"

class PurgeUnattachedBlobsJobTest < ActiveJob::TestCase
  def create_blob(created_at:)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("dummy"), filename: "test.pdf", content_type: "application/pdf")
    blob.update_column(:created_at, created_at)
    blob
  end

  test "purges unattached blobs older than 24 hours" do
    old_orphan = create_blob(created_at: 2.days.ago)

    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ old_orphan ]) do
      PurgeUnattachedBlobsJob.perform_now
    end
  end

  test "leaves recently uploaded unattached blobs alone (still mid-review)" do
    recent_orphan = create_blob(created_at: 1.hour.ago)

    assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
      PurgeUnattachedBlobsJob.perform_now
    end

    assert ActiveStorage::Blob.exists?(recent_orphan.id)
  end

  test "leaves attached blobs alone even if old" do
    seller = users(:one)
    seller.update!(role: :admin)

    ActsAsTenant.with_tenant(seller.company) do
      customer = Customer.create!(name: "Blob Test Müşterisi")
      sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)
      old_attached = create_blob(created_at: 2.days.ago)
      sale.source_pdfs.attach(old_attached)

      assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
        PurgeUnattachedBlobsJob.perform_now
      end
    end
  end
end
