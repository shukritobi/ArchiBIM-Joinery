# frozen_string_literal: true
require 'sketchup.rb'
require 'extensions.rb'

module SSDigitalLab
  module ArchiBIMJoinery
    unless defined?(@registered) && @registered
      extension = SketchupExtension.new('ArchiBIM Joinery', 'archibim_joinery/main')
      extension.description = 'Parametric cabinets, desks and built-in joinery with ArchiBIM wall hosting.'
      extension.version = '0.2.0'
      extension.creator = 'SS Digital Lab'
      extension.copyright = '2026 SS Digital Lab'
      Sketchup.register_extension(extension, true)
      @registered = true
    end
  end
end
