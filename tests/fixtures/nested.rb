# Nested fixture: module + nested class with private section
module OuterModule
  def module_public
    'module public'
  end

  class InnerClass
    def inner_public
      'inner public'
    end

    private

    def inner_private
      'inner private'
    end
  end

  private

  def module_private
    'module private'
  end
end
