from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
if not (root/'workshop').exists():
    root=root.parent/'mods/vehicle-living-slots'
mods=root/'workshop/Contents/mods'
def locale(mod,lang):
    return json.loads((mods/mod/'common/media/lua/shared/Translate'/lang/'IG_UI.json').read_text(encoding='utf-8-sig'))
for lang in ['EN','CN','CH']:
    main=locale('VehicleLivingSlots',lang)
    campers=locale('VehicleLivingSlotsKI5Campers',lang)
    f700=locale('VehicleLivingSlotsKI5F700',lang)
    assert f700['IGUI_VLSF700RearLeftSpace']==campers['IGUI_VLSKI5SpaceRearLeft']
    assert f700['IGUI_VLSF700RearRightSpace']=={'EN':'Rear Right Space','CN':'右后空间','CH':'右後空間'}[lang]
    assert f700['IGUI_VLSF700RearCenterSpace']==main['IGUI_VLSLargeVanRearSpace']
    assert f700['IGUI_VehiclePartVLSF700Slot6']==f700['IGUI_VLSF700RearRightSpace']
    assert f700['IGUI_VehiclePartVLSF700Slot7']==f700['IGUI_VLSF700RearCenterSpace']
    assert f700['IGUI_VehiclePartVLSF700WaterTank2']==campers['IGUI_VehiclePartVLSKI5CamperWaterTank2']
    assert f700['IGUI_VehiclePartVLSTopFrame4']==main['IGUI_VehiclePartVLSTopFrame1']
    assert f700['IGUI_VehiclePartVLSOverhead3']==main['IGUI_VehiclePartVLSOverhead1']
    for i in range(1, 7):
        assert f700[f'IGUI_VLSF700Space{i}'] == f'SeatP{i+2}'
        assert f700[f'IGUI_VLSF700Seat{i}'] == ('Seat' if lang == 'EN' else '座位') + str(i+2)
    for i in range(1,15):
        assert f700[f'IGUI_VLSF700BusSpace{i}']==f'SeatP{i+1}'
        assert f700[f'IGUI_VLSF700BusSeat{i}']==('Seat' if lang=='EN' else '座位')+str(i+1)
print('VLS_SEAT_LABELS_PASS languages=3 semantic_checks=60')
