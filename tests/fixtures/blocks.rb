# Block fixture: do/end blocks that shouldn't affect scope tracking
class Account
  scope :inactive, -> { where(active: false) }

  scope :warned,
        -> do
          joins(:activity).where(
            'activities.last_warning_at < ?',
            2.months.ago,
          )
        end

  after_commit -> { cleanup! }, on: :destroy

  after_commit -> do
    notify_observers
  end

  def public_method
    items.each do |item|
      process(item)
    end
  end

  private

  def private_one
    'private'
  end

  def private_two
    results = []
    items.map do |item|
      results << transform(item)
    end
    results
  end

  def private_three
    'also private'
  end
end
