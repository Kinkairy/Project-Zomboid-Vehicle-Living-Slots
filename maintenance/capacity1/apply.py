from pathlib import Path
import re, json, hashlib, subprocess, shutil, sys
R=Path(sys.argv[1]);inputs=Path(__file__).parent
assert subprocess.check_output(['git','-C',str(R),'rev-parse','HEAD'],text=True).strip()=='8cac58cff9433b43701d829e2e5cae5758dbfd77'
m=R/'workshop/Contents/mods/VehicleLivingSlots/common/media'
p=m/'lua/shared/VLS_RoofCargo.lua';s=p.read_text()
old=re.search(r'^R.rackCapacities = .*$',s,re.M)[0]
caps={k:int(v) for k,v in re.findall(r'\["([^"]+)"\]=(\d+)',old)}
assert len(caps)==106 and set(caps.values())=={150,200,300}
s=s.replace(old,re.sub(r'\]=(\d+)',lambda a:']='+str(int(a[1])+100),old),1)
helper='''-- Use absolute per-body capacities, never repeatedly add to saved values.
-- Refresh the existing item and storage in place, including previously fitted
-- racks. No item/container replacement, cargo removal or global vehicle scan.
function R.syncFixedRackCapacity(vehicle,part)
    if not vehicle or not part or part:getVehicle()~=vehicle
            or part:getId()~=R.fixedId or not R.isPart(part)
            or vehicle:getPartById(R.fixedId)~=part then return false end
    local item=part:getInventoryItem()
    if not item or item:getFullType()~=R.fixedType then return false end
    local capacity=R.rackCapacities[vehicle:getScript():getFullName()]
    if not capacity then return false end
    local itemChanged=item:getMaxCapacity()~=capacity
    if itemChanged then item:setMaxCapacity(capacity) end
    local changed=itemChanged
    if part:getContainerCapacity()~=capacity then
        part:setContainerCapacity(capacity)
        changed=true
    end
    local container=part:getItemContainer()
    if container and container:getCapacity()~=capacity then
        container:setCapacity(capacity)
        changed=true
    end
    -- The two peers derive container capacity locally from the same table.
    -- Only a changed installed item needs the existing item synchronization.
    if itemChanged and not isClient() then vehicle:transmitPartItem(part) end
    return changed
end
'''
marker='-- The 0.12 script allowed native/debug installation of a MetalBar instead'
assert s.count(marker)==1;s=s.replace(marker,helper+marker)
for fn in ['InitFixedRack','UpdateFixedRack']:
    marker='function R.'+fn+'(vehicle,part)\n';assert s.count(marker)==1
    s=s.replace(marker,marker+'    R.syncFixedRackCapacity(vehicle,part)\n',1)
a='    return not chr:getVehicle() and vehicle:isInArea(part:getArea(),chr)\nend\nfunction R.Create'
assert s.count(a)==1;s=s.replace(a,'    R.syncFixedRackCapacity(vehicle,part)\n'+a,1);p.write_text(s)
for fname,count in [('VLS_StepVanRoofRackAdjustment.txt',1),('VLS_VehicleRoofAdapters.txt',4)]:
    p=m/'scripts'/fname;s=p.read_text();changes=[]
    for mt in re.finditer(r'\bpart\s+VLSFixedRoofRack\s*\{',s):
        start=mt.start();pos=mt.end();depth=1
        while depth:
            depth+=(s[pos]=='{')-(s[pos]=='}');pos+=1
        block=s[start:pos];vals=re.findall(r'\bcapacity\s*=\s*(\d+)',block)
        assert len(vals)==1 and int(vals[0]) in (150,200,300)
        changes.append((start,pos,re.sub(r'(\bcapacity\s*=\s*)(\d+)',lambda x:x[1]+str(int(x[2])+100),block)))
    assert len(changes)==count
    for a,b,t in reversed(changes):s=s[:a]+t+s[b:]
    p.write_text(s)
p=m/'scripts/VLS_RoofRackItem.txt';s=p.read_text();assert s.count('MaxCapacity = 300,')==1;p.write_text(s.replace('MaxCapacity = 300,','MaxCapacity = 400,'))
p=m/'lua/shared/VLS_Config.lua';s=p.read_text();assert s.count('release-3.8.3-20260917')==1;p.write_text(s.replace('release-3.8.3-20260917','release-3.8.3-capacity1-20260917'))
for name,dest in [('build_roof_capacity_translations.py','tools'),('test_roof_capacity.lua','tools'),('vls-roof-capacity-ui.json','translations'),('VLS_3.8.3_CAPACITY1.md','ag-handoff/releases')]:
    (R/dest).mkdir(parents=True,exist_ok=True);shutil.copyfile(inputs/name,R/dest/name)
subprocess.run([sys.executable,str(R/'tools/build_roof_capacity_translations.py'),'--repo',str(R)],check=True)
p=R/'release-3.8.3.json';r=json.loads(p.read_text());r['build']='release-3.8.3-capacity1-20260917';r['base_commit']='8cac58cff9433b43701d829e2e5cae5758dbfd77';rt=R/'workshop/Contents/mods';r['files']={q.relative_to(rt).as_posix():hashlib.sha256(q.read_bytes()).hexdigest() for q in sorted(rt.rglob('*')) if q.is_file()};p.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
p=R/'CHANGELOG.md';s=p.read_text();title=s.splitlines()[0];s=s.replace(title+'\n',title+'\n\n## 3.8.3 capacity1 — 2026-09-17\n\n- Add 100 base capacity to every supported roof rack: StepVan 400, Van/VanSeats 300, SUV/PickUpVan 250.\n- Reconcile existing installed rack capacities in place; preserve cargo and condition.\n- Keep fabrication materials, interior storage and the four original 3.8.3 changes unchanged.\n',1);p.write_text(s)
p=R/'README.md';p.write_text(p.read_text()+'\n## 3.8.3 capacity1\n\nFixed roof rack base capacity is now StepVan **400**, Van/VanSeats **300**, and SUV/PickUpVan **250** (+100 each, all supported variants). Existing installed racks are updated in place; fabrication costs do not change.\n\n行李架基础容量统一增加100：StepVan **400**，Van/VanSeats **300**，SUV/PickUpVan **250**。旧架原位更新，材料不变。\n\n行李架基礎容量統一增加100：StepVan **400**，Van/VanSeats **300**，SUV/PickUpVan **250**。舊架原位更新，材料不變。\n')
p=R/'workshop/CHANGELOG_3.8.3.txt';p.write_text(p.read_text().rstrip()+'\n- Capacity1: +100 base roof-rack capacity for all supported variants (StepVan 400; Van/VanSeats 300; SUV/PickUpVan 250). Existing racks updated in place, cargo retained, construction costs unchanged.\n')
subprocess.run(['git','-C',str(R),'add','-A'],check=True)
subprocess.run(['git','-C',str(R),'add','-f','ag-handoff/releases/VLS_3.8.3_CAPACITY1.md'],check=True)
tree=subprocess.check_output(['git','-C',str(R),'write-tree'],text=True).strip()
runtime=subprocess.check_output(['git','-C',str(R),'rev-parse',tree+':workshop/Contents'],text=True).strip()
assert runtime=='8047903561f2814d287eddde930bd19d9c5fe424',runtime
print('VERIFIED_RUNTIME_TREE='+runtime)
