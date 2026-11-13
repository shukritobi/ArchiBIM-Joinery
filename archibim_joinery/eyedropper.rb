# frozen_string_literal: true
# Like ArchiBIM Core's eyedropper: source once, then apply to many same-type
# targets without moving them, changing width/depth/height or replacing IDs.
require_relative 'diagnostics'
require_relative 'property_transfer'

module SSDigitalLab
  module ArchiBIMJoinery
    class CabinetEyedropperTool
      def initialize
        @source=nil
        @count=0
      end

      def activate
        Sketchup.status_text='Joinery Eyedropper: click source cabinet, then same-family target(s). Esc exits.'
      end

      def pick(view,x,y)
        helper=view.pick_helper
        helper.do_pick(x,y)
        (0...helper.count).each do |index|
          path=helper.path_at(index)
          next unless path
          # Favor the outermost parametric assembly, not individual side panels.
          entity=path.find do |item|
            item.is_a?(Sketchup::Group) && ArchiBIMJoinery.data_for(item)
          end
          next unless entity
          return [entity,ArchiBIMJoinery.data_for(entity)]
        end
        nil
      end

      def onMouseMove(_flags,x,y,view)
        item=pick(view,x,y)
        view.tooltip=if item
          @source ? "Apply #{@source[1]['params']['kind']} settings to #{item[1]['params']['kind']}" :
                    "Sample #{item[1]['params']['kind']} settings"
        else
          'Hover a parametric Joinery group'
        end
      end

      def onLButtonDown(_flags,x,y,view)
        picked=pick(view,x,y)
        unless picked
          Sketchup.status_text='Joinery Eyedropper: select a parametric Joinery cabinet, not loose geometry.'
          return
        end
        unless @source
          @source=[picked[0],JSON.parse(JSON.generate(picked[1]))]
          Sketchup.status_text="Sampled #{@source[1]['params']['kind']}. Click same-family cabinets to apply finishes and construction settings, without changing their sizes or position. Esc exits."
          ArchiBIMJoinery.log('eyedropper_source',id:@source[1]['id'],kind:@source[1]['params']['kind'])
          # Also load sampled dimensions and finishes into the editor so the
          # user can Place New with the same settings after leaving this tool.
          begin
            dlg=ArchiBIMJoinery.instance_variable_get(:@dialog)
            if dlg && dlg.visible?
              dlg.execute_script("window.joineryPreset(#{JSON.generate(@source[1]['params'])});")
            end
          rescue StandardError=>e
            ArchiBIMJoinery.log('eyedropper_ui_preview_error',error:e.message)
          end
          return
        end
        group,data=picked
        if group==@source[0] || data['id']==@source[1]['id']
          Sketchup.status_text='Source and target are the same object. Click a different cabinet.'
          return
        end
        begin
          target=CabinetPropertyTransfer.transfer(@source[1]['params'],data['params'])
          patch=CabinetPropertyTransfer.patch(@source[1]['params'],data['params'])
          if patch.empty?
            Sketchup.status_text='That cabinet already has these transferable properties.'
            return
          end
          # Validation first. A source configuration may not fit a narrower
          # target; such a target must remain unchanged.
          Core.parts(target)
          model=group.model
          model.start_operation('ArchiBIM Joinery: Match Cabinet Properties',true)
          begin
            data['params']=target
            before=group.transformation
            ArchiBIMJoinery.build_geometry(group,data)
            group.transformation=before
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          @count+=1
          ArchiBIMJoinery.log('eyedropper_applied',
            source:@source[1]['id'],target:data['id'],
            kind:target['kind'],changed_fields:patch.keys,applied:@count)
          Sketchup.status_text="Joinery Eyedropper: #{@count} target(s) matched. Click another same-family target or Esc to finish."
          ArchiBIMJoinery.refresh
          view.invalidate
        rescue StandardError=>e
          ArchiBIMJoinery.log('eyedropper_target_error',target:data['id'],error:e.message)
          Sketchup.status_text="Joinery Eyedropper could not apply: #{e.message}. Target preserved."
        end
      end

      def onCancel(_reason,view)
        Sketchup.active_model.select_tool(nil)
        view.invalidate if view
      end
      def deactivate(view)
        view.invalidate if view
      end
    end

    module EyedropperRuntime
      def display
        previously=@dialog && @dialog.visible?
        super
        return if previously
        @dialog.add_action_callback('eyedropper') do |_ctx|
          begin
            Sketchup.active_model.select_tool(CabinetEyedropperTool.new)
            log('eyedropper_started')
          rescue StandardError=>e
            log('eyedropper_start_error',error:e.message)
            UI.messagebox("Joinery Eyedropper: #{e.message}")
          end
        end
      end
    end
    singleton_class.prepend(EyedropperRuntime)
    unless defined?(@eyedropper_menu_registered) && @eyedropper_menu_registered
      menu=UI.menu('Extensions').add_submenu('ArchiBIM Joinery: Tools')
      menu.add_item('Eyedropper: Match Cabinet Properties') do
        Sketchup.active_model.select_tool(CabinetEyedropperTool.new)
      end
      @eyedropper_menu_registered=true
    end
  end
end
