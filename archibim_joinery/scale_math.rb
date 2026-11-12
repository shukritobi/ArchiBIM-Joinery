# frozen_string_literal: true
require_relative 'enhancements'

module SSDigitalLab
  module ArchiBIMJoinery
    module ScaleMath
      extend self
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
