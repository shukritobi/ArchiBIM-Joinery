# frozen_string_literal: true
require 'minitest/autorun'

class JoineryAccessibilityTest < Minitest::Test
  HTML = File.read(File.expand_path('../archibim_joinery/ui/panel.html', __dir__), encoding: 'UTF-8')

  def test_responsive_single_column_inputs
    assert_match(/@media\s*\(max-width:520px\)/, HTML)
    assert_includes HTML, '.grid{grid-template-columns:minmax(0,1fr)}'
    assert_includes HTML, '.span2{grid-column:auto}'
  end

  def test_sticky_commands_scroll_in_narrow_dialog
    assert_includes HTML, '.command-dock .buttons{display:flex;flex-wrap:nowrap;overflow-x:auto;'
    assert_includes HTML, '.command-dock .buttons button{flex:0 0 auto;white-space:nowrap}'
  end

  def test_command_and_selection_status_are_accessible
    assert_includes HTML, 'id="action-feedback" class="info" role="status" aria-live="polite"'
    assert_includes HTML, 'id="status" class="status" role="status" aria-live="polite"'
    assert_includes HTML, 'Cabinet selection and quantities refreshed from SketchUp.'
    assert_includes HTML, "document.addEventListener('click',event=>"
  end

  def test_cabinet_fields_and_live_callbacks_remain
    %w[kind width height depth panel_thickness front drawer_count handle_style].each do |id|
      assert_includes HTML, %(id="#{id}")
    end
    %w[joineryPreset joineryRefresh collect fill place edit resize bind].each do |func|
      assert_match(/\b#{func}\b/,HTML)
    end
  end
end
