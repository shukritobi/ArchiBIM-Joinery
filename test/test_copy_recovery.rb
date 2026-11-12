# frozen_string_literal: true
# Pure-Ruby copy recovery contract, exercised without a SketchUp installation.
require 'minitest/autorun'
module Sketchup
  class Group; end
  class Face; end
end
require_relative '../archibim_joinery/copy_recovery'
Bounds = Struct.new(:width, :height, :depth)
Transform = Struct.new(:values) do
  def to_a; values; end
end
class MockCabinetGroup < Sketchup::Group
  attr_reader :entities, :transformation, :bounds
  def initialize(children: [], attrs: {}, n: 0)
    @entities = children
    @attrs = attrs
    @transformation = Transform.new([1,0,0,0,0,1,0,0,0,0,1,0,n,0,0,1])
    @bounds = Bounds.new(1,2,3)
  end
  def get_attribute(_dict, key); @attrs[key]; end
end
class MockFace < Sketchup::Face; end
class CopyRecoveryTest < Minitest::Test
  ID = '01234567-89ab-cdef-0123-456789abcdef'
  RECOVERY = SSDigitalLab::ArchiBIMJoinery::CopyRecovery
  def parts(id: ID, attrs: true, n: 8)
    (0...n).map do |i|
      keys = attrs ? {'part_key'=>"#{id}:part-#{i}"} : {}
      MockCabinetGroup.new(children:[MockFace.new],attrs:keys,n:i)
    end
  end
  def source(group, id=ID)
    [[group,{'id'=>id}]]
  end
  def test_group_copy_with_nested_keys_restores_source
    original=MockCabinetGroup.new(children:parts)
    copy=MockCabinetGroup.new(children:parts)
    assert_same original, RECOVERY.match_source(copy,source(original),'ABJ').first
  end
  def test_group_copy_without_any_nested_attributes_uses_unique_geometry
    original=MockCabinetGroup.new(children:parts)
    copy=MockCabinetGroup.new(children:parts(attrs:false))
    assert_same original, RECOVERY.match_source(copy,source(original),'ABJ').first
  end
  def test_unrelated_geometry_never_rehydrated
    original=MockCabinetGroup.new(children:parts)
    candidate=MockCabinetGroup.new(children:parts(attrs:false,n:7))
    assert_nil RECOVERY.match_source(candidate,source(original),'ABJ')
  end
  def test_multiple_identical_cabinets_are_ambiguous
    first=MockCabinetGroup.new(children:parts)
    second=MockCabinetGroup.new(children:parts)
    clone=MockCabinetGroup.new(children:parts(attrs:false))
    assert_nil RECOVERY.match_source(clone,source(first,'first')+source(second,'second'),'ABJ')
  end
  def test_small_unknown_group_not_recovered
    first=MockCabinetGroup.new(children:parts(n:3))
    clone=MockCabinetGroup.new(children:parts(n:3,attrs:false))
    assert_nil RECOVERY.match_source(clone,source(first),'ABJ')
  end
  def test_conflicting_part_ids_are_not_guessed_by_geometry
    original=MockCabinetGroup.new(children:parts)
    copied=parts
    copied[0]=MockCabinetGroup.new(children:[MockFace.new],
       attrs:{'part_key'=>'ffffffff-ffff-ffff-ffff-ffffffffffff:wrong'},n:0)
    clone=MockCabinetGroup.new(children:copied)
    assert_nil RECOVERY.match_source(clone,source(original),'ABJ')
  end
end
