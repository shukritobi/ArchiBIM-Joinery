# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../archibim_joinery/property_transfer'

class JoineryEyedropperTest < Minitest::Test
  C=SSDigitalLab::ArchiBIMJoinery::Core
  T=SSDigitalLab::ArchiBIMJoinery::CabinetPropertyTransfer

  def test_copy_construction_not_target_dimensions
    source=C.presets('base').merge('width'=>2400,'height'=>900,'depth'=>550,
      'material'=>'Oak','front'=>'doors','handle_style'=>'knob','panel_thickness'=>18,
      'end_panel_thickness'=>20)
    target=C.presets('base').merge('width'=>600,'height'=>850,'depth'=>600,
      'material'=>'White Melamine','front'=>'doors','handle_style'=>'none',
      'name'=>'Existing Unit')
    original=target.dup
    out=T.transfer(source,target)
    assert_equal 600,out['width']
    assert_equal 850,out['height']
    assert_equal 600,out['depth']
    assert_equal 'Existing Unit',out['name']
    assert_equal 'Oak',out['material']
    assert_equal 'knob',out['handle_style']
    assert_equal 18,out['panel_thickness']
    assert_equal 20,out['end_panel_thickness']
    assert_equal original,target
  end

  def test_wall_panel_led_and_joints_but_not_size
    s=C.presets('wall_panel').merge('width'=>4000,'panel_led_top'=>true,
      'wall_panel_gaps'=>4,'material'=>'Sage Oak')
    t=C.presets('wall_panel').merge('width'=>1200,'panel_led_top'=>false,
      'wall_panel_gaps'=>0)
    p=T.transfer(s,t)
    assert_equal 1200,p['width']
    assert_equal 4,p['wall_panel_gaps']
    assert p['panel_led_top']
    assert C.parts(p).any?{|r|r['role']=='led'}
  end

  def test_family_mismatch_rejected
    assert_raises(ArgumentError) do
      T.transfer(C.presets('base'),C.presets('tall'))
    end
  end

  def test_target_with_incompatible_width_remains_unmodified
    s=C.presets('basin_vanity').merge('basin_width'=>1000,'width'=>1200)
    t=C.presets('basin_vanity').merge('width'=>600,'basin_width'=>450)
    original=t.dup
    assert_raises(ArgumentError){T.transfer(s,t)}
    assert_equal original,t
  end

  def test_property_patch_does_not_include_identity_or_dimensions
    source=C.presets('tall').merge('height'=>3000,'width'=>2000,'depth'=>500,
      'mount_height'=>250,'name'=>'Sample','groove_height'=>25,'handle_style'=>'center_groove')
    target=C.presets('tall').merge('height'=>2400,'width'=>700,'depth'=>600,
      'mount_height'=>0,'name'=>'Target')
    changed=T.patch(source,target)
    %w[width height depth mount_height name kind id ceiling_height].each do |field|
      refute changed.key?(field),field
    end
    assert_equal 'center_groove',changed['handle_style']
    assert_equal 25,changed['groove_height']
  end
end
