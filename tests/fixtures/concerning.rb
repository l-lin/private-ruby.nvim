# Rails-style concerning blocks - private should be scoped to block
class Model
  def public_before_concern
    'public'
  end

  concerning 'Feature' do
    def public_in_concern
      'public within concern'
    end

    private

    def private_in_concern
      'private within concern'
    end
  end

  def public_after_concern
    'should still be public!'
  end

  concerning :AnotherFeature do
    def also_public
      'new concern, fresh visibility'
    end
  end

  private

  def truly_private
    'class-level private'
  end
end
