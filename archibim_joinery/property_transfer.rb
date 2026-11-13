# frozen_string_literal: true
# Pure Ruby Joinery eyedropper property patching.
require_relative 'v04_features'

module SSDigitalLab
  module ArchiBIMJoinery
    module CabinetPropertyTransfer
      extend self
      # Construction and finish settings, never target identity or placement.
      FIELDS=%w[
        material top_material panel_thickness front_thickness end_panel_thickness
        back_thickness back_recess support_thickness front back shelves divisions
        drawer_count door_count door_gap max_door_width auto_doors drawer_shadow_gap
        runner_type runner_length runner_clearance handle_style handle_offset handle_cc
        toe_height toe_recess floor_finish_panels filler_left filler_right
        end_panel_left end_panel_right top_thickness top_skirting top_skirting_height
        backsplash_height upper_storage box_up
        corner_filler corner_ownership island_style island_back_style
        waterfall_left waterfall_right top_shadow_gap
        groove_height groove_depth groove_center_height
        mirror_enabled mirror_width mirror_height mirror_bottom mirror_thickness mirror_led
        basin_style basin_width basin_depth basin_height
        panel_led_bottom panel_led_top panel_led_left panel_led_right
        panel_led_offset panel_led_width wall_panel_gaps
      ].freeze
      # Must never overwrite target's kind, dimensions, position, path or UUID.
      PRESERVED=%w[kind name width height depth mount_height ceiling_height
                   path_alignment path_side path_wall_units max_carcass_width
                   auto_wall_orient].freeze

      def patch(source,target)
        raise ArgumentError,'Eyedropper requires two cabinet configurations' unless
          source.is_a?(Hash) && target.is_a?(Hash)
        raise ArgumentError,'Eyedropper only supports the same Joinery family' unless
          source['kind']==target['kind']
        FIELDS.each_with_object({}) do |key,changed|
          next unless source.key?(key) && source[key]!=target[key]
          changed[key]=source[key]
        end
      end

      def transfer(source,target)
        changes=patch(source,target)
        merged=target.merge(changes)
        # Structural footprint, mounting datum and family cannot change.
        PRESERVED.each{|key|merged[key]=target[key] if target.key?(key)}
        Core.normalize(merged)
      end
    end

  end
end
