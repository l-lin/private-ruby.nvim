# Operator and indexer method fixture
class Vector
  def initialize(x, y)
    @x = x
    @y = y
  end

  def +(other)
    Vector.new(@x + other.x, @y + other.y)
  end

  def [](index)
    index == 0 ? @x : @y
  end

  private

  def -(other)
    Vector.new(@x - other.x, @y - other.y)
  end

  def *(other)
    Vector.new(@x * other, @y * other)
  end

  def []=(index, value)
    index == 0 ? @x = value : @y = value
  end

  def <=>(other)
    magnitude <=> other.magnitude
  end

  def ==(other)
    @x == other.x && @y == other.y
  end
end
