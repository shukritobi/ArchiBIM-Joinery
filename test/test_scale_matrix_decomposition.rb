# frozen_string_literal: true
# Pure-Ruby matrix contract tests: actual SketchUp runtime tests run in QA Lab.
require 'minitest/autorun'

module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x, @y, @z = x.to_f, y.to_f, z.to_f; end
    def length; Math.sqrt(x*x + y*y + z*z); end
    def normalize; self.class.new(x/length, y/length, z/length); end
    def dot(v); x*v.x + y*v.y + z*v.z; end
    def cross(v); self.class.new(y*v.z-z*v.y, z*v.x-x*v.z, x*v.y-y*v.x); end
  end
end

class TransformationStub
  def initialize(matrix); @matrix = matrix; end
  def to_a; @matrix; end
end

source_path = File.expand_path('../archibim_joinery/scale_math.rb', __dir__)
source = File.read(source_path).sub("require_relative 'enhancements'", '')
eval(source, TOPLEVEL_BINDING, source_path)

class ScaleMatrixDecompositionTest < Minitest::Test
  def decompose(matrix)
    SSDigitalLab::ArchiBIMJoinery::ScaleMath.decompose(TransformationStub.new(matrix))
  end

  def diagonal(x, y, z, h=1.0)
    [x,0,0,0, 0,y,0,0, 0,0,z,0, 0,0,0,h]
  end

  def test_independent_xyz_scale
    scales, axes = decompose(diagonal(1.25,0.8,1.5))
    assert_equal [1.25,0.8,1.5], scales
    assert_equal [1.0,1.0,1.0], axes.map(&:length)
  end

  def test_rotated_nonuniform_scale
    scales, = decompose([0,1.4,0,0, -0.7,0,0,0, 0,0,1.2,0, 0,0,0,1])
    assert_in_delta 1.4, scales[0], 0.0001
    assert_in_delta 0.7, scales[1], 0.0001
  end

  def test_homogeneous_component
    scales, = decompose(diagonal(2.5,2.0,2.0,2.0))
    assert_equal [1.25,1.0,1.0], scales
  end

  def test_mirroring_is_rejected
    assert_match(/mirror/i, assert_raises(ArgumentError) { decompose(diagonal(-1,1,1)) }.message)
  end

  def test_shearing_is_rejected
    matrix=diagonal(1,1,1);matrix[4]=0.3
    assert_match(/shear/i, assert_raises(ArgumentError) { decompose(matrix) }.message)
  end

  def test_degenerate_transform_is_rejected
    assert_raises(ArgumentError) { decompose(diagonal(0,1,1)) }
  end
end
