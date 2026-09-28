#!/usr/bin/env python3
"""Generate only F700's own script from unchanged VLS 3.9 and native KI5 parts."""
import argparse,re
from pathlib import Path

def block(text, kind, name):
    match=re.search(r'(?m)^\s*'+re.escape(kind)+r'\s+'+re.escape(name)+r'\s*\{',text)
    if not match:raise ValueError((kind,name))
    start=text.index('{',match.start());depth=1;end=start+1
    while depth:
        depth+=(text[end]=='{')-(text[end]=='}');end+=1
    return text[match.start():end].strip()

def build(root, native):
    scripts=root/'workshop/Contents/mods/VehicleLivingSlots/common/media/scripts'
    living=block((scripts/'VLS_StepVanWaterPatch.txt').read_text(),'template vehicle','VLSLargeVanLivingSystem')
    top=block((scripts/'VLS_ZTopSpaceVehicles.txt').read_text(),'template vehicle','VLSTopSpace1')
    rows=['module Base\n{\n    template vehicle VLSKI5F700LivingSystem\n    {']
    slots=['SeatBed','VLSLargeVanSlot2','VLSLargeVanSlot3','VLSLargeVanSlot4','VLSLargeVanSlot5','VLSF700Slot6','VLSF700Slot7']
    seats=['Bed','SpaceCenter','SpaceRight','VLSLargeVanSpace4','VLSLargeVanSpace5','VLSF700Space6','VLSF700Space7']
    freezers=['VLSUniversalFreezer','VLSLargeVanFreezer2','VLSLargeVanFreezer3','VLSLargeVanFreezer4','VLSLargeVanFreezer5']
    for id in slots[:5]+freezers+['VLSLargeVanWaterTank','VLSAuxBatterySlot']:
        rows.append('        template = VLSLargeVanLivingSystem/part/'+id+',')
    for i in range(6,15):
        rows.append(block(living,'part','VLSLargeVanSlot5').replace('VLSLargeVanSlot5','VLSF700Slot'+str(i)).replace('VLSLargeVanSpace5','VLSF700Space'+str(i)))
        rows.append(block(living,'part','VLSLargeVanFreezer5').replace('VLSLargeVanFreezer5','VLSF700Freezer'+str(i)))
    for i in range(2,5):
        rows.append(block(living,'part','VLSLargeVanWaterTank').replace('VLSLargeVanWaterTank','VLSF700WaterTank'+str(i)))
    rows.append(block(living,'part','VLSAuxBatterySlot').replace('VLSAuxBatterySlot','VLSF700Battery3').replace('Vehicles.UninstallTest.Battery','VLS.F700Power.uninstallTest'))
    overhead=['VLSPantryCoffee','VLSOverhead1','VLSOverhead2','VLSOverhead3']
    for i,id in enumerate(overhead,1):
        rows.append(block(top,'part','VLSTopFrame1').replace('VLSTopFrame1','VLSTopFrame'+str(i)).replace('VLS.Chassis.','VLS.F700Frames.'))
        rows.append(block(top,'part','VLSPantryCoffee').replace('VLSPantryCoffee',id).replace('VLSTopFrame1','VLSTopFrame'+str(i)))
    rows.append('    }')
    bank=(native/'87fordF700bank.txt').read_text()
    def switch(id):return '            switchSeat '+id+' { anim = Climb_WindowB, rate = 0.23, sound = VehicleChangeSeat, }'
    for model,source,original in [('87fordF700bank',bank,['FrontLeft','FrontRight'])]:
        rows += ['    vehicle '+model+'\n    {','        seats = '+str(len(original)+7)+',']
        bank_parts=slots+freezers+['VLSF700Freezer6','VLSF700Freezer7','VLSLargeVanWaterTank','VLSF700WaterTank2','VLSAuxBatterySlot']
        bank_parts+=['VLSTopFrame'+str(i) for i in range(1,5)]+overhead
        for part_id in bank_parts: rows.append('        template = VLSKI5F700LivingSystem/part/'+part_id+',')
        for id in original:
            body=block(source,'passenger',id)
            body=re.sub(r'(?m)^( +)',lambda m: '\t'*(len(m.group(1))//4)+' '*(len(m.group(1))%4),body)
            rows.append(body[:-1]+'\n'+'\n'.join(switch(s) for s in seats)+'\n        }')
        for i,id in enumerate(seats):
            x=0 if i==6 else (0.6778 if i%2==0 else -0.6778)
            z=[0.1222,-0.6,-1.3556,-2.15][i//2]
            rows.append("""        passenger %s
        {
            area = TruckBed,
            door = TrunkDoor,
            hasRoof = true,
            showPassenger = false,
            position inside { offset = %s 0.0556 %s, rotate = 0.0 0.0 0.0, }
            position outside { offset = -0.0111 -1.3333 -2.0556, rotate = 0.0 0.0 0.0, area = TruckBed, }
            anim enter { anim = Climb_WindowA, rate = 0.33, }
            anim idle { anim = Idle, rate = 1.0, }
            anim exit { anim = Climb_WindowB, rate = 0.23, }
%s
        }"""%(id,x,z,'\n'.join(switch(s) for s in original+seats if s!=id)))
        rows.append('    }')
    # All paired models share the same generated parts/hooks. Only the native
    # passenger indices and the real driver's seat item/recipe differ.
    native_seats=(native/'template_F700_seats.txt').read_text()
    swat_front=block(block(native_seats,'template vehicle','F700SeatsFront'),'part','SeatFrontLeft')
    bus_front=block(block((native/'template_B700_seats.txt').read_text(),'template vehicle','B700SeatDriver'),'part','SeatFrontLeft')
    paired=[('87fordF700swat',6,2,'USMIL.Seat0',swat_front)]
    paired += [(model,14,1,'Base.87fordB700Seat2',bus_front) for model in ('87fordB700school','87fordB700prison','87fordB700military')]
    for model,count,first,item_type,front in paired:
        rows += ['    vehicle '+model+'\n    {', '        seats = '+str(count+first)+',']
        model_slots=slots[:5]+['VLSF700Slot'+str(i) for i in range(6,count+1)]
        extras=freezers+['VLSF700Freezer'+str(i) for i in range(6,count+1)]
        extras+=['VLSLargeVanWaterTank']+['VLSF700WaterTank'+str(i) for i in range(2,5 if first==1 else 3)]+['VLSAuxBatterySlot']
        if first==1: extras.append('VLSF700Battery3')
        extras+=['VLSTopFrame'+str(i) for i in range(1,5)]+overhead
        for id in extras: rows.append('        template = VLSKI5F700LivingSystem/part/'+id+',')
        for i,id in enumerate(model_slots,first):
            passenger='P'+str(i); seat='Seat'+passenger
            rows.append('        template = VLSKI5F700LivingSystem/part/'+id+',')
            rows.append("""        part %s
        {
            container { seat = %s, }
            lua { create = VLS.Create.UniversalSlot, init = VLS.F700Seats.initLiving, update = VLS.F700Seats.updateLiving, }
            table install { requireUninstalled = %s, test = VLS.F700Seats.installTest, complete = VLS.F700Seats.completeLiving, }
            table uninstall { test = VLS.F700Seats.uninstallTest, complete = VLS.F700Seats.completeLiving, }
        }"""%(id,passenger,seat))
            rows.append('        part '+seat+'\n        {\n            category = VLSLiving,\n            itemType = '+item_type+',\n            specificItem = false,\n            mechanicArea = Back,\n            lua { create = Vehicles.Create.Default, init = VLS.F700Seats.initSeat, }')
            for action in ('install','uninstall'):
                recipe=block(front,'table',action)
                recipe=recipe.replace('Vehicles.InstallTest.Default','VLS.F700Seats.installTest').replace('Vehicles.UninstallTest.Default','VLS.F700Seats.uninstallTest')
                recipe=recipe[:-1]+('    requireUninstalled = '+id+',\n' if action == 'install' else '')+'    complete = VLS.F700Seats.completeSeat,\n            }'
                rows.append(recipe)
            rows.append('        }')
        if first==1:
            for id in ('DAMNGenerator',):
                rows.append('        part '+id+'\n        {\n            table uninstall { test = VLS.F700Roof.uninstallTest, }\n        }')
        rows.append('    }')
    rows.append('}')
    return '\n'.join(rows)+'\n'
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--ki5-scripts',type=Path,required=True);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    result=build(root,args.ki5_scripts)
    path=root/'workshop/Contents/mods/VehicleLivingSlotsKI5F700/common/media/scripts/VLS_KI5F700Patch.txt'
    if args.check:assert path.read_text()==result,'F700 script differs from source templates'
    else:path.parent.mkdir(parents=True,exist_ok=True);path.write_text(result)
    print('F700_SCRIPT_OK: Bank 9; SWAT 8 / 6 pairs; three Bus 15 / 14 pairs / 4 tanks; native passenger and exit definitions unchanged; Bus battery #3')
