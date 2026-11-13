# frozen_string_literal: true
# SketchUp runtime for open island waterfall mitres and cabinet paths.
require_relative 'layout'

module SSDigitalLab
  module ArchiBIMJoinery
    module PathRuntime
      def build_geometry(group,data)
        super
        group.entities.grep(Sketchup::Group).each do |part_group|
          raw=part_group.get_attribute(DICT,'part_data')
          next unless raw
          part=JSON.parse(raw)
          profile=part['profile']
          next unless %w[waterfall_top waterfall_left waterfall_right].include?(profile)
          w=part['w'].mm; d=part['d'].mm; h=part['h'].mm
          case profile
          when 'waterfall_top'
            left=part['miter_left'];right=part['miter_right']
            points=[[0,0,h],[w,0,h],
                    right ? [w-h,0,0] : [w,0,0],
                    left ? [h,0,0] : [0,0,0]]
          when 'waterfall_left'
            points=[[0,0,0],[w,0,0],[w,0,h-w],[0,0,h]]
          when 'waterfall_right'
            points=[[0,0,0],[w,0,0],[w,0,h],[0,0,h-w]]
          end
          replace_profile(part_group,part,points,d,Y_AXIS)
        end
        group
      end

      def path_frame(step)
        origin=Geom::Point3d.new(*step['origin'].map { |x| x.mm })
        xa=Geom::Vector3d.new(*step['xaxis'])
        ya=Geom::Vector3d.new(*step['yaxis'])
        Geom::Transformation.axes(origin,xa,ya,Z_AXIS)
      end

      def create_from_path_points(params, paths)
        p=Core.normalize(params)
        raise ArgumentError,'Draw a base, wall, tall or desk path' unless %w[base wall tall desk].include?(p['kind'])
        raise ArgumentError,'No cabinet paths found' if paths.empty?
        jobs=[]
        paths.each do |points|
          layouts=[[p,PathPlanner.plan(points,p)]]
          if p['kind']=='base' && p['path_wall_units']
            overhead=Core.presets('wall').merge(
              'material'=>p['material'],'top_material'=>p['top_material'],
              'path_alignment'=>p['path_alignment'],'path_side'=>p['path_side'],
              'corner_filler'=>p['corner_filler'],'corner_ownership'=>p['corner_ownership'],
              'max_carcass_width'=>p['max_carcass_width'])
            overhead=Core.normalize(overhead)
            layouts << [overhead,PathPlanner.plan(points,overhead)]
          end
          layouts.each do |config,layout|
            layout['runs'].each do |run|
              h=config.merge('width'=>run['length'],
                             'end_panel_left'=>false,'end_panel_right'=>false,
                             'filler_left'=>0,'filler_right'=>0)
              jobs << [Core.normalize(h),run]
            end
            layout['corners'].each do |corner|
              corner_kind='corner_'+config['kind']
              h=Core.presets(corner_kind).merge(
                'width'=>config['depth'],'depth'=>config['depth'],
                'height'=>config['height'],'mount_height'=>config['mount_height'],
                'top_thickness'=>config['top_thickness'],'toe_height'=>config['toe_height'],
                'material'=>config['material'],'top_material'=>config['top_material'],
                'corner_filler'=>config['corner_filler'],
                'corner_ownership'=>config['corner_ownership'],
                'back'=>config['back'],'front'=>'open')
              jobs << [Core.normalize(h),corner]
            end
          end
        end
        # Validate ALL parts before SketchUp starts an operation, preventing
        # a later segment failure from leaving a half-generated installation.
        jobs.each { |config,_| Core.parts(config) }
        model=Sketchup.active_model
        model.start_operation('ArchiBIM Joinery: Cabinet Paths',true)
        groups=[]
        begin
          jobs.each do |config,step|
            g=model.entities.add_group
            data={'schema'=>Core::SCHEMA,'id'=>SecureRandom.uuid,
                  'params'=>config,'anchor'=>nil,'version'=>VERSION,
                  'path'=>{'type'=>step['kind'],'turn'=>step['turn'],
                           'alignment'=>p['path_alignment'],'side'=>p['path_side']}}
            g.transformation=path_frame(step)
            # Unit origin is at model path elevation; mount is relative to it.
            offset=Geom::Transformation.translation([0,0,config['mount_height'].mm])
            g.transformation=g.transformation*offset
            build_geometry(g,data)
            groups<<g
          end
          model.selection.clear
          model.selection.add(groups)
          model.commit_operation
          log('cabinet_path_created',groups:groups.size,paths:paths.size,
              corners:jobs.count { |_,step| step['kind']=='corner' },
              overhead:p['kind']=='base' && p['path_wall_units'])
          refresh
        rescue StandardError=>e
          model.abort_operation
          log('cabinet_path_error',error:e.message)
          raise
        end
        groups
      end

      def path_from_selected_lines(params)
        model=Sketchup.active_model
        edges=model.selection.grep(Sketchup::Edge)
        raise ArgumentError,'Select native SketchUp edges, then click Generate From Lines' if edges.empty?
        pairs=edges.map { |e| [e.start.position.to_a.map(&:to_mm),e.end.position.to_a.map(&:to_mm)] }
        paths=PathPlanner.ordered_paths(pairs)
        create_from_path_points(params,paths)
      end

      def display
        existing=@dialog && @dialog.visible?
        super
        return if existing
        @dialog.add_action_callback('path_selected') do |_ctx,raw|
          begin
            path_from_selected_lines(JSON.parse(raw))
          rescue StandardError=>e
            log('path_selected_error',error:e.message)
            UI.messagebox("Joinery path: #{e.message}")
          end
        end
        @dialog.add_action_callback('path_draw') do |_ctx,raw|
          begin
            Sketchup.active_model.select_tool(CabinetPathTool.new(JSON.parse(raw)))
          rescue StandardError=>e
            log('path_draw_error',error:e.message)
            UI.messagebox("Joinery path: #{e.message}")
          end
        end
      end
    end

    class CabinetPathTool
      def initialize(params)
        @params=Core.normalize(params)
        @points=[]
        @input=Sketchup::InputPoint.new
      end

      def activate
        Sketchup.status_text='Cabinet path: click each vertex; Enter = generate, Backspace = undo, Esc = cancel.'
      end

      def onMouseMove(_flags,x,y,view)
        if @points.empty?
          @input.pick(view,x,y)
        else
          previous=Sketchup::InputPoint.new(Geom::Point3d.new(*@points[-1].map { |n| n.mm }))
          @input.pick(view,x,y,previous)
        end
        view.tooltip=@input.tooltip if @input.valid?
        view.invalidate
      end

      def onLButtonDown(_flags,x,y,view)
        @input.pick(view,x,y)
        return unless @input.valid?
        p=@input.position
        point=[p.x.to_mm,p.y.to_mm,p.z.to_mm]
        if !@points.empty? && (point[2]-@points[0][2]).abs>1
          UI.beep
          Sketchup.status_text='All cabinet path vertices must remain on the same horizontal plane.'
          return
        end
        return if !@points.empty? && PathPlanner.distance(@points[-1],point)<1
        @points<<point
        Sketchup.status_text="Cabinet path: #{@points.length} vertices. Enter generates."
        view.invalidate
      end

      def onKeyDown(key,_repeat,_flags,view)
        if key==VK_RETURN
          if @points.size<2
            UI.beep
          else
            begin
              ArchiBIMJoinery.create_from_path_points(@params,[@points])
              Sketchup.active_model.select_tool(nil)
            rescue StandardError=>e
              ArchiBIMJoinery.log('path_tool_error',error:e.message)
              UI.messagebox("Joinery path: #{e.message}")
            end
          end
          return true
        end
        if key==VK_BACK
          @points.pop
          view.invalidate
          return true
        end
        return false unless [VK_RIGHT,VK_LEFT,VK_UP,VK_DOWN].include?(key)
        if key==VK_DOWN || @points.empty?
          view.lock_inference
        else
          axis={VK_RIGHT=>X_AXIS,VK_LEFT=>Y_AXIS,VK_UP=>Z_AXIS}[key]
          base=Geom::Point3d.new(*@points[-1].map { |n| n.mm })
          view.lock_inference(Sketchup::InputPoint.new(base),
                              Sketchup::InputPoint.new(base.offset(axis,100.mm)))
        end
        true
      end

      def draw(view)
        return if @points.empty?
        @input.draw(view) if @input.valid? && @input.display?
        view.drawing_color=Sketchup::Color.new(24,190,174)
        p=@points.map { |a| Geom::Point3d.new(*a.map { |n| n.mm }) }
        p<<@input.position if @input.valid?
        view.line_width=3
        view.draw(GL_LINE_STRIP,p) if p.size>=2
        view.draw_points(p,7,2,Sketchup::Color.new(24,190,174))
      end

      def getExtents
        bb=Sketchup.active_model.bounds
        @points.each { |a| bb.add(Geom::Point3d.new(*a.map { |n| n.mm })) }
        bb
      end

      def onCancel(_reason,view)
        Sketchup.active_model.select_tool(nil)
        view.invalidate
      end

      def deactivate(view)
        view.lock_inference if view
      end
    end

    singleton_class.prepend(PathRuntime)
    unless defined?(@path_menu_registered) && @path_menu_registered
      menu=UI.menu('Extensions').add_submenu('ArchiBIM Joinery: Cabinet Paths')
      menu.add_item('Draw Cabinet Path') { Sketchup.active_model.select_tool(CabinetPathTool.new(Core.presets('base'))) }
      menu.add_item('From Selected Lines (Base + Wall)') { path_from_selected_lines(Core.presets('base')) }
      @path_menu_registered=true
    end
  end
end
