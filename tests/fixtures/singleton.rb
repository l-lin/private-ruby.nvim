# Singleton fixture: def self.x and class << self block
class Singleton
  def instance_public
    'instance public'
  end

  def self.singleton_public
    'singleton public'
  end

  private

  def instance_private
    'instance private'
  end

  class << self
    def singleton_in_block_public
      'singleton block public'
    end

    private

    def singleton_in_block_private
      'singleton block private'
    end
  end
end
