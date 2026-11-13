# frozen_string_literal: true
# Parametric island, modular carcass and orthogonal run planning, millimetres.
require_relative 'enhancements'

module SSDigitalLab
  module ArchiBIMJoinery
    module Core
      extra = %w[island corner_base corner_wall corner_tall corner_desk]
      old_kinds = const_get(:KINDS)
      remove_const(:KINDS)
      const_set(:KINDS, (old_kinds + extra).freeze)
      old_presets = const_get(:PRESETS)
      remove_const(:PRESETS)
      const_set(:PRESETS, old_presets.merge(
        'island' => { 'width'=>1800,'height'=>1000,'depth'=>600,'toe_height'=>0,'top_thickness'=>50,'front'=>'open','back'=>'none','shelves'=>0 },
        'corner_base' => old_presets['base'].merge('width'=>600,'depth'=>600,'front'=>'open','shelves'=>0),
        'corner_wall' => old_presets['wall'].merge('width'=>350,'depth'=>350,'front'=>'open','shelves'=>0),
        'corner_tall' => old_presets['tall'].merge('width'=>600,'depth'=>600,'front'=>'open','shelves'=>0),
        'corner_desk' => old_presets['desk'].merge('width'=>600,'depth'=>600,'front'=>'open','shelves'=>0)
      ).freeze)

      module LayoutExtensions
        def presets(kind)
          p = super
          p.merge!('max_carcass_width'=>1200,'path_alignment'=>'inner','path_side'=>'left',
                   'path_wall_units'=>kind=='base','corner_filler'=>50,
                   'corner_ownership'=>'empty','island_style'=>'open',
                   'island_back_style'=>'low','waterfall_left'=>kind=='island',
                   'waterfall_right'=>false,'top_shadow_gap'=>kind=='base' ? 20 : 0,
                   'end_panel_thickness'=>20)
          if kind == 'base'
            p['end_panel_left'] = true
            p['end_panel_right'] = true
          elsif kind == 'island'
            p['end_panel_right'] = true
            p['panel_thickness'] = 20
            p['top_material'] = 'Countertop'
            p['auto_wall_orient'] = false
          elsif kind == 'corner_wall'
            p['mount_height'] = 1450
          end
          p
        end

        def normalize(raw)
          p = super
          d = presets(p['kind'])
          %w[max_carcass_width corner_filler top_shadow_gap].each do |key|
            p[key] = value(d.merge(raw), key, 0, key == 'max_carcass_width' ? 1200 : 100_000)
          end
          raise ArgumentError, 'Carcass width must be at least 200 mm' if p['max_carcass_width'] < 200
          p['path_alignment'] = raw.fetch('path_alignment',d['path_alignment']).to_s
          p['path_side'] = raw.fetch('path_side',d['path_side']).to_s
          p['corner_ownership'] = raw.fetch('corner_ownership',d['corner_ownership']).to_s
          p['island_style'] = raw.fetch('island_style',d['island_style']).to_s
          p['island_back_style'] = raw.fetch('island_back_style',d['island_back_style']).to_s
          %w[path_wall_units waterfall_left waterfall_right].each do |key|
            val = raw.fetch(key,d[key])
            p[key] = val == true || val.to_s == 'true'
          end
          raise ArgumentError,'Unknown path line alignment' unless %w[inner center outer].include?(p['path_alignment'])
          raise ArgumentError,'Unknown cabinet side of path' unless %w[left right].include?(p['path_side'])
          raise ArgumentError,'Unknown corner access' unless %w[empty left right].include?(p['corner_ownership'])
          raise ArgumentError,'Unknown island construction' unless %w[open carcass].include?(p['island_style'])
          raise ArgumentError,'Unknown island back' unless %w[none low apron full].include?(p['island_back_style'])
          if p['kind'] == 'island'
            raise ArgumentError,'Open island does not support cabinet fronts; choose carcass mode' if
              p['island_style']=='open' && p['front']!='open'
            raise ArgumentError,'Waterfall is thicker than usable island width' if
              (p['waterfall_left'] || p['waterfall_right']) && p['width'] <= 4*p['top_thickness']
            raise ArgumentError,'Island waterfall top must be at least 10 mm' if
              (p['waterfall_left'] || p['waterfall_right']) && p['top_thickness'] < 10
          end
          if p['kind'].start_with?('corner_')
            raise ArgumentError,'Corner filler cannot exceed one third of unit size' if
              p['corner_filler'] > [p['width'],p['depth']].min/3.0
          end
          p
        end

        def parts(raw)
          p = normalize(raw)
          if p['kind'] == 'island'
            return island_parts(p, super(p))
          end
          if p['kind'].start_with?('corner_')
            return corner_parts(p)
          end
          result = super(p)
          result = modular_parts(result,p) if %w[base wall tall desk].include?(p['kind'])
          if p['top_shadow_gap'] > p['door_gap'] && p['handle_style']=='none' && p['front']!='open'
            result.select { |r| r['role']=='door' }.each do |door|
              door['h'] = (door['h'] - (p['top_shadow_gap']-p['door_gap'])).round(4)
            end
          end
          result
        end

        def island_parts(p, base_parts)
          out=[]
          t=p['top_thickness']; w=p['width']; d=p['depth']; h=p['height']
          if p['island_style']=='carcass'
            out=base_parts
          else
            # An open snack bar: support is modelled separately, never assumed from stone.
            if p['end_panel_left'] && !p['waterfall_left']
              add_part(out,'island-support-left','Island Left End Support',0,0,0,
                       p.fetch('end_panel_thickness',p['panel_thickness']),d,h-t,'support',p)
            end
            if p['end_panel_right'] && !p['waterfall_right']
              add_part(out,'island-support-right','Island Right End Support',
                       w-p.fetch('end_panel_thickness',p['panel_thickness']),0,0,p.fetch('end_panel_thickness',p['panel_thickness']),d,h-t,'support',p)
            end
            case p['island_back_style']
            when 'low'
              add_part(out,'island-low-back','Lower Rear Modesty Panel',p['panel_thickness'],d-p['panel_thickness'],0,
                       w-2*p['panel_thickness'],p['panel_thickness'],200,'back',p)
            when 'apron'
              add_part(out,'island-apron','Rear Apron',p['panel_thickness'],d-p['panel_thickness'],h-t-200,
                       w-2*p['panel_thickness'],p['panel_thickness'],200,'support',p)
            when 'full'
              add_part(out,'island-full-back','Full Rear Panel',p['panel_thickness'],d-p['panel_thickness'],0,
                       w-2*p['panel_thickness'],p['panel_thickness'],h-t,'back',p)
            end
          end
          out.reject! { |a| a['key']=='worktop' || (a['role']=='finish' &&
            ((p['waterfall_left'] && a['key']=='end-left') || (p['waterfall_right'] && a['key']=='end-right'))) }
          profile = p['waterfall_left'] || p['waterfall_right'] ? 'waterfall_top' : nil
          top = {'material'=>p['top_material']}
          top['profile']=profile if profile
          top['miter_left']=p['waterfall_left'];top['miter_right']=p['waterfall_right']
          add_part(out,'worktop','Island Worktop',0,0,h-t,w,d,t,'worktop',p,top)
          if p['waterfall_left']
            add_part(out,'waterfall-left','Left 45 Degree Waterfall',0,0,0,t,d,h,'waterfall',p,
                     {'material'=>p['top_material'],'profile'=>'waterfall_left'})
          end
          if p['waterfall_right']
            add_part(out,'waterfall-right','Right 45 Degree Waterfall',w-t,0,0,t,d,h,'waterfall',p,
                     {'material'=>p['top_material'],'profile'=>'waterfall_right'})
          end
          out
        end

        def corner_parts(p)
          # Square blind corner, 50 mm orthogonal front returns, access from one
          # face only. The opposite face remains blank to prevent clashes.
          t=p['panel_thickness']; ft=p['front_thickness']; gap=p['door_gap']
          w=p['width']; d=p['depth']; h=p['height']
          toe=p['toe_height']; top=p['top_thickness']; ch=h-toe-top
          f=p['corner_filler']
          out=[]
          add_part(out,'corner-side-left','Corner Side Left',0,ft,toe,t,d-ft,ch,'carcass',p)
          # Side-access doors cannot occupy the same volume as a full side panel.
          # Leave that side open when access comes from the perpendicular run.
          unless p['corner_ownership']=='right'
            add_part(out,'corner-side-right','Corner Side Right',w-t,ft,toe,t,d-ft,ch,'carcass',p)
          end
          add_part(out,'corner-floor','Corner Base',t,ft,toe,w-2*t,d-ft,t,'carcass',p)
          add_part(out,'corner-ceiling','Corner Head',t,ft,toe+ch-t,w-2*t,d-ft,t,'carcass',p)
          if top>0
            add_part(out,'corner-worktop','Corner Continuous Worktop',0,0,h-top,w,d,top,'worktop',p,
                     {'material'=>p['top_material']})
          end
          if toe>0
            add_part(out,'corner-plinth','Corner Plinth',0,p['toe_recess'],0,w,t,toe,'toe_kick',p)
          end
          # Two perpendicular 50 mm fillers meet without occupying the same volume.
          add_part(out,'corner-filler-front','Inner Corner Front Return',0,0,toe,f,ft,ch,'filler',p)
          add_part(out,'corner-filler-side','Inner Corner Side Return',0,ft,toe,ft,f-ft,ch,'filler',p) if f>ft
          if p['corner_ownership']=='left'
            leaf=w-f-2*gap
            add_part(out,'corner-door-front','Corner Front Access',f+gap,0,toe+gap,leaf,ft,ch-2*gap,'door',p)
          elsif p['corner_ownership']=='right'
            leaf=d-f-2*gap
            add_part(out,'corner-door-side','Corner Side Access',w-ft,f+gap,toe+gap,ft,leaf,ch-2*gap,'door',p)
          end
          if p['back']!='none'
            add_part(out,'corner-back','Corner Rear Back',t,d-p['back_thickness'],toe+t,
                     w-2*t,p['back_thickness'],ch-2*t,'back',p)
          end
          out
        end

        def modular_parts(parts,p)
          cw=case_width(p); max=p['max_carcass_width']
          return parts if cw<=max+0.001
          x0=p['filler_left']+(p['end_panel_left'] ? p.fetch('end_panel_thickness',p['panel_thickness']) : 0)
          doors=parts.select { |a| a['role']=='door' }.sort_by { |a| a['x'] }
          # Never cut a door leaf with a carcass division. Find a legal chain
          # of whole-leaf module boundaries using dynamic programming, with
          # each module between 150 mm and the configured maximum width.
          seams=[]
          if doors.size>=2 && %w[doors combo].include?(p['front'])
            midpoints=doors.each_cons(2).map { |a,b| (a['x']+a['w']+b['x'])/2.0 }
            candidates=[x0]+midpoints+[x0+cw]
            best=Array.new(candidates.length)
            best[-1]=[]
            (candidates.length-2).downto(0) do |i|
              choices=((i+1)...candidates.length).select do |j|
                width=candidates[j]-candidates[i]
                width>=150 && width<=max+0.001 && best[j]
              end
              next if choices.empty?
              # Fewest carcasses first, then widest feasible modules.
              j=choices.min_by { |idx| [best[idx].length,-(candidates[idx]-candidates[i])] }
              best[i]=[j]+best[j]
            end
            raise ArgumentError,'Cannot divide door leaves into modules within maximum carcass width' unless best[0]
            seams=best[0][0...-1].map { |i| candidates[i] }
          else
            count=(cw/max).ceil
            (1...count).each { |i| seams << x0+cw*i/count.to_f }
          end
          bounds=[x0]+seams+[x0+cw]
          t=p['panel_thickness']; ft=p['front_thickness']
          floor=p['toe_height']; ch=p['height']-floor-p['top_thickness']
          cy=p['front']=='open' ? 0 : ft; cd=p['depth']-cy
          back_y=p['back']=='inset' ? p['depth']-p['back_recess']-p['back_thickness'] : p['depth']-p['back_thickness']
          sd=p['back']=='none' ? cd : back_y-cy
          keep=parts.reject { |a| %w[carcass back shelf].include?(a['role']) }
          if %w[drawers combo].include?(p['front'])
            keep.reject! { |a| a['key'].start_with?('drawer-','runner-','handle-drawer-','standoff-drawer-') }
          end
          bounds.each_cons(2).with_index do |(left,right),i|
            n=i+1; width=right-left; inner=width-2*t
            raise ArgumentError,'Module too narrow for twin carcass sides' if inner<100
            add_part(keep,"module-#{n}-left","Module #{n} Left Side",left,cy,floor,t,cd,ch,'carcass',p,
                     {'module'=>n})
            add_part(keep,"module-#{n}-right","Module #{n} Right Side",right-t,cy,floor,t,cd,ch,'carcass',p,
                     {'module'=>n})
            unless p['kind']=='desk'
              add_part(keep,"module-#{n}-bottom","Module #{n} Bottom",left+t,cy,floor,inner,cd,t,'carcass',p,
                       {'module'=>n})
              add_part(keep,"module-#{n}-top","Module #{n} Top",left+t,cy,floor+ch-t,inner,cd,t,'carcass',p,
                       {'module'=>n})
              if p['back']!='none'
                add_part(keep,"module-#{n}-back","Module #{n} Back",left+t,back_y,floor+t,
                         inner,p['back_thickness'],ch-2*t,'back',p,{'module'=>n})
              end
              p['shelves'].times do |s|
                z=floor+t+(ch-2*t)*(s+1)/(p['shelves']+1.0)-t/2
                add_part(keep,"module-#{n}-shelf-#{s+1}","Module #{n} Shelf #{s+1}",
                         left+t,cy,z,inner,sd,t,'shelf',p,{'module'=>n})
              end
            end
            if %w[drawers combo].include?(p['front'])
              front_h=ch-2*p['door_gap']
              if p['front']=='combo'
                upper=[front_h*0.3,130.0].max
                upper=[upper,front_h*0.5].min
                start=floor+p['door_gap']+front_h-upper
                count=1
                height=upper
              else
                start=floor+p['door_gap']
                count=p['drawer_count']
                height=front_h
              end
              new_fronts=[]
              drawers(lambda { |key,name,x,y,z,w,d,h,role='carcass',material=nil|
                add_part(new_fronts,"m#{n}-#{key}",name,x,y,z,w,d,h,role,p,{'module'=>n,'material'=>material || p['material']})
              },p.merge('drawer_count'=>count),left,width,start,height,ft,p['door_gap'],0)
              add_handles(new_fronts,p)
              keep.concat(new_fronts)
            end
          end
          keep
        end
      end
      singleton_class.prepend(LayoutExtensions)
    end

    module PathPlanner
      extend self
      EPS=0.001

      def distance(a,b)
        Math.hypot(b[0]-a[0],b[1]-a[1])
      end

      def unit(a,b)
        len=distance(a,b)
        raise ArgumentError,'Cabinet path contains a zero-length line' if len<1
        [(b[0]-a[0])/len,(b[1]-a[1])/len]
      end

      def cross(a,b)
        a[0]*b[1]-a[1]*b[0]
      end

      def line_intersection(a,u,b,v)
        det=cross(u,v)
        raise ArgumentError,'Parallel path lines do not intersect' if det.abs<EPS
        t=cross([b[0]-a[0],b[1]-a[1]],v)/det
        [a[0]+u[0]*t,a[1]+u[1]*t]
      end

      def dot(a,b)
        a[0]*b[0]+a[1]*b[1]
      end

      def normalize_points(points)
        raise ArgumentError,'Path needs at least two vertices' unless points.is_a?(Array) && points.size>=2
        clean=points.map do |p|
          a=p.map { |x| Float(x) }
          raise ArgumentError,'Path must contain XYZ points in millimetres' unless a.size==3 && a.all?(&:finite?)
          a
        end
        raise ArgumentError,'Path must lie on one horizontal plane' unless
          clean.all? { |p| (p[2]-clean[0][2]).abs<=1.0 }
        # Merge collinear consecutive vertices but reject backtracking.
        loop do
          modified=false
          (1...clean.size-1).each do |i|
            u=unit(clean[i-1],clean[i]);v=unit(clean[i],clean[i+1])
            if cross(u,v).abs<0.001
              raise ArgumentError,'Path doubles back on itself' if dot(u,v)<0.99
              clean.delete_at(i); modified=true; break
            end
          end
          break unless modified
        end
        clean
      end

      def ordered_paths(edges)
        nodes={};adj=Hash.new { |h,k| h[k]=[] }
        edges.each do |a,b|
          ka=a.map { |x| (Float(x)*10).round }
          kb=b.map { |x| (Float(x)*10).round }
          raise ArgumentError,'Zero-length selected edge' if ka==kb
          nodes[ka]=a.map(&:to_f);nodes[kb]=b.map(&:to_f)
          adj[ka] << kb unless adj[ka].include?(kb)
          adj[kb] << ka unless adj[kb].include?(ka)
        end
        raise ArgumentError,'Select at least one SketchUp line' if adj.empty?
        raise ArgumentError,'Branch intersections need separate paths (no T or X nodes)' if adj.any? { |_,ns| ns.size>2 }
        paths=[];visited={}
        adj.each_key do |start|
          next if visited[start]
          component=[];stack=[start]
          until stack.empty?
            k=stack.pop;next if visited[k]
            visited[k]=true;component << k;stack.concat(adj[k])
          end
          ends=component.select { |k| adj[k].size==1 }
          raise ArgumentError,'Closed cabinet loops require a designated opening' unless ends.size==2
          chain=[ends[0]];prev=nil;cur=ends[0]
          loop do
            following=adj[cur].find { |k| k!=prev }
            break unless following
            chain << following;prev=cur;cur=following
          end
          paths << normalize_points(chain.map { |k| nodes[k] })
        end
        paths
      end

      def plan(points,p)
        pts=normalize_points(points)
        d=p.fetch('depth').to_f; side=p.fetch('path_side','left')
        align=p.fetch('path_alignment','inner')
        sign=side=='left' ? 1.0 : -1.0
        shift=case align
              when 'inner' then 0.0  # line is back face of cabinet
              when 'center' then d/2.0
              when 'outer' then d
              else raise ArgumentError,'Unknown cabinet path alignment'
              end
        dirs=(0...pts.size-1).map { |i| unit(pts[i],pts[i+1]) }
        normals=dirs.map { |u| [-u[1]*sign,u[0]*sign] }
        # Shift path to actual cabinet back face, then intersect adjacent back lines.
        back_a=dirs.each_index.map { |i| [pts[i][0]+normals[i][0]*shift,pts[i][1]+normals[i][1]*shift] }
        back_b=dirs.each_index.map { |i| [pts[i+1][0]+normals[i][0]*shift,pts[i+1][1]+normals[i][1]*shift] }
        join=[back_a[0]]
        turns=[]
        (1...pts.size-1).each do |i|
          dot_value=dot(dirs[i-1],dirs[i])
          raise ArgumentError,'Only straight and 90-degree corner joins are supported in this build' if dot_value.abs>0.01
          cross_value=cross(dirs[i-1],dirs[i])
          raise ArgumentError,'Corner geometry is degenerate' if cross_value.abs<0.99
          join << line_intersection(back_a[i-1],dirs[i-1],back_a[i],dirs[i])
          turns << (cross_value*sign>0 ? :convex : :concave)
        end
        join << back_b[-1]
        runs=[]
        dirs.each_index do |i|
          base=join[i]
          finish=join[i+1]
          start_trim=i>0 && turns[i-1]==:concave ? d : 0
          end_trim=i<turns.length && turns[i]==:concave ? d : 0
          length=distance(base,finish)-start_trim-end_trim
          raise ArgumentError,'A path leg is too short for the corner depth' if length<200
          u=dirs[i]; n=normals[i]
          back=[base[0]+u[0]*start_trim,base[1]+u[1]*start_trim]
          origin=[back[0]-n[0]*d,back[1]-n[1]*d,pts[0][2]]
          runs << {'kind'=>'run','origin'=>origin,'xaxis'=>[u[0],u[1],0],
                   'yaxis'=>[n[0],n[1],0],'length'=>length}
        end
        corners=turns.each_with_index.map do |type,i|
          u=dirs[i];n=normals[i];c=join[i+1]
          start=type==:concave ? [c[0]-u[0]*d,c[1]-u[1]*d] : c
          {'kind'=>'corner','origin'=>[start[0]-n[0]*d,start[1]-n[1]*d,pts[0][2]],
           'xaxis'=>[u[0],u[1],0],'yaxis'=>[n[0],n[1],0],
           'length'=>d,'turn'=>type.to_s}
        end
        {'runs'=>runs,'corners'=>corners}
      end
    end
  end
end
