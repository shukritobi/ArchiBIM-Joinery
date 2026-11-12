# frozen_string_literal: true
require_relative 'enhancements'

module SSDigitalLab
  module ArchiBIMJoinery
    module ScaleMath
      extend self
      # Read Scale directly from the full transformation matrix. SketchUp's
      # xaxis/yaxis/zaxis accessors are not reliable measurement of scaling.
      # Ref: https://developer.sketchup.com/article-making-a-parametric-object
      def decompose(transform)
        matrix = transform.to_a
        homogeneous = matrix.fetch(15).to_f
        raise ArgumentError, 'Invalid homogeneous transform' unless homogeneous.finite? && homogeneous.abs > 1.0e-9
        axes = [0, 4, 8].map do |offset|
          Geom::Vector3d.new(*matrix.slice(offset, 3).map { |v| v.to_f / homogeneous })
        end
        lengths = axes.map(&:length)
        raise ArgumentError, 'Invalid scale factor' unless lengths.all? { |v| v.finite? && v > 0.0001 }
        unit = axes.map(&:normalize)
        dots = [unit[0].dot(unit[1]), unit[0].dot(unit[2]), unit[1].dot(unit[2])]
        raise ArgumentError, 'Skew/shear unsupported; undo the skewed Scale operation' if dots.any? { |v| v.abs > 0.001 }
        raise ArgumentError, 'Mirrored transforms unsupported; undo negative scaling' unless unit[0].cross(unit[1]).dot(unit[2]) > 0.999
        [lengths, unit]
      end

      def apply_dimensions(params,scale_factors)
        p=Core.normalize(params)
        raise ArgumentError,'Expected three scale factors' unless scale_factors.length==3
        factors=scale_factors.map { |n| Float(n) }
        raise ArgumentError,'Invalid native scale factor' unless factors.all? { |n| n.finite? && n>0.0001 }
        result=p.dup
        %w[width depth height].each_with_index do |key,i|
          result[key]=(p.fetch(key).to_f*factors[i]).round(3)
        end
        Core.normalize(result)
      end
      def changed?(scale_factors)
        scale_factors.any? { |v| (v.to_f-1.0).abs>0.0005 }
      end
    end
  end
end
