-- Authority-only motion evidence. Transient observations; no saved/network data.
local M={rows=setmetatable({},{__mode='k'})}
local function finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function baseline(v,p,t,x,y,z,owner,driver,item)
 local r={t=t,x=x,y=y,z=z,owner=owner,driver=driver,item=item,settle=t+600}
 M.rows[p]=r;return r
end
local function window(r,t,x,y)
 r.ax,r.ay,r.at=x,y,t;r.steps=0;r.path=0;r.dx,r.dy=nil,nil
 r.vx,r.vy,r.voteMs=x,y,t
 r.active=false
end
function M.clear(p)M.rows[p]=nil end
function M.confirm(v,p,t)
 if isClient() then M.clear(p);return false end
 if not finite(t) then M.clear(p);return false end
 local ok,result=pcall(function()
  local x,y,z=v:getX(),v:getY(),v:getZ()
  -- Native horizontal velocity is also valid for unoccupied/towed vehicles.
  -- The signed dashboard-speed getter can clear itself when no driver owns physics.
  local speed=v:getSpeed2D()*3.6
  local owner,driver,item=v:getNetPlayerId(),v:getDriver(),p:getInventoryItem()
  if not finite(x) or not finite(y) or not finite(z) or not finite(speed) then M.clear(p);return false end
  local r=M.rows[p]
  if not r or t<r.t or t-r.t>1000 or r.owner~=owner or r.driver~=driver or r.item~=item or math.abs(z-r.z)>0.25 then
   baseline(v,p,t,x,y,z,owner,driver,item);return false
  end
  if t-r.t<100 then return false end -- repeated track/tick calls are one observation
  local dt=t-r.t;local px,py=r.x,r.y
  r.t,r.x,r.y,r.z=t,x,y,z
  if t<=r.settle then window(r,t,x,y);return false end
  if not r.at or t-r.voteMs>5000 then window(r,t,px,py) end
  local sx,sy=x-px,y-py;local distance=math.sqrt(sx*sx+sy*sy)
  -- Discontinuities and speed/position disagreement establish a new baseline.
  -- Native speed corroborates displacement; it never proves motion by itself.
  if speed<=0 or distance>20 or distance>speed*dt/3600*3+0.02 then
   window(r,t,x,y);return false
  end
  if not r.active then
   if distance<=0 then return false end
   window(r,t-dt,px,py);r.active=true
  end
  local dx,dy=x-r.vx,y-r.vy;distance=math.sqrt(dx*dx+dy*dy)
  if distance<0.005 then return false end -- accumulate crawling motion across quantized samples
  if r.dx and dx*r.dx+dy*r.dy<=0 then window(r,t,x,y);return false end
  r.steps=r.steps+1;r.path=r.path+distance;r.dx,r.dy=dx,dy
  r.vx,r.vy,r.voteMs=x,y,t
  local nx,ny=x-r.ax,y-r.ay;local net=math.sqrt(nx*nx+ny*ny)
  return r.steps>=2 and t-r.at>=300 and net>=0.05 and r.path<=net*1.5
 end)
 if not ok then M.clear(p);return false end
 return result==true
end
return M
