# Basic fixture: one public method, private section, two private methods
class Example
  def public_method
    'I am public'
  end

  private

  def private_method_one
    'I am private'
  end

  def private_method_two
    'I am also private'
  end
end
