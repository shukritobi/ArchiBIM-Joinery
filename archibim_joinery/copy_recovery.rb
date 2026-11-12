# frozen_string_literal: true
# Recover cabinet identity when SketchUp Group#copy drops outer attributes.
# Pure Ruby algorithm; only examines existing geometry without mutating models.
module SSDigitalLab
  module ArchiBIMJoinery
    module CopyRecovery
      extend self

      def child_groups(group)
        group.entities.grep(Sketchup::Group)
      end

      def unique_part_origin(group, dict)
        children = child_groups(group)
        return nil if children.length < 5
        ids = children.filter_map do |child|
          raw = child.get_attribute(dict, 'part_key').to_s
          match = /\A([a-f0-9-]{36}):(.+)\z/i.match(raw)
          [match[1], match[2]] if match
        end
        return nil if ids.empty?
        return :conflict if ids.map(&:first).uniq.length != 1
        return :incomplete if ids.length < 3 || ids.map(&:last).uniq.length < 3
        ids.first.first
      rescue StandardError
        nil
      end

      def geometry_fingerprint(group)
        children = child_groups(group)
        return nil if children.length < 5
        children.map do |part|
          values = part.transformation.to_a.map { |n| n.to_f.round(6) }
          b = part.bounds
          dims = [b.width, b.height, b.depth].map { |n| n.to_f.round(6) }
          faces = part.entities.grep(Sketchup::Face).length
          [values, dims, faces]
        end.sort
      rescue StandardError
        nil
      end

      def match_source(copy, originals, dict)
        return nil unless copy && child_groups(copy).length >= 5
        origins = originals.reject { |source, _data| source.equal?(copy) }
        original_id = unique_part_origin(copy, dict)
        return nil if original_id == :conflict || original_id == :incomplete
        if original_id
          candidates = origins.select { |_source, data| data['id'] == original_id }
          return candidates.first if candidates.length == 1 &&
            child_groups(candidates.first.first).length == child_groups(copy).length
          return nil # Inconsistent part UUIDs must not be guessed from shape.
        end
        fingerprint = geometry_fingerprint(copy)
        return nil unless fingerprint
        candidates = origins.select { |source, _data| geometry_fingerprint(source) == fingerprint }
        candidates.length == 1 ? candidates.first : nil
      end
    end
  end
end
