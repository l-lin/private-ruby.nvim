# Endless method fixture (Ruby 3.0+)
class Config
  def public_getter = @value
  def public_with_arg(x) = x * 2

  private

  def private_getter = @secret
  def private_with_arg(x) = x + 1
  def private_with_args(a, b) = a + b

  # Regular method after endless methods (tests scope tracking)
  def regular_private
    'still private'
  end

  public

  def back_to_public
    'public again'
  end
end
