ReviewCase('01_original_damage_init_leaves_both_cabinets_at_20',function()
    local v=ReviewFixture({'Base.Mov_ModernCounter','Base.Mov_WoodenCounter'})
    local s=VLS.Damage.Init(v,v.parts[1])
    ReviewEq(VLS.Damage.Init(v,v.parts[2]),s,'per-vehicle cached state')
    for _,p in ipairs(v.parts) do ReviewEq(p.container.capacity,20);ReviewEq(p.container.writes,0) end
end)
ReviewCase('02_original_access_allows_but_does_not_restore_capacity',function()
    local v,ch=ReviewFixture({'Base.Mov_ModernCounter'})
    ReviewEq(VLS.ContainerAccess.UniversalSlot(v,v.parts[1],ch),true)
    ReviewEq(v.parts[1].container.capacity,20)
end)
ReviewCase('03_exact_client_refresh_repairs_local_copy_only',function()
    local server=ReviewFixture({'Base.Mov_ModernCounter'})
    local client=ReviewFixture({'Base.Mov_ModernCounter'})
    local p=client.parts[1]
    ReviewSetClient(true)
    ReviewClientRefresh({backpacks={{inventory=p.container}}},'buttonsAdded')
    ReviewSetClient(false)
    ReviewEq(p.container.capacity,50,'client copy')
    ReviewEq(server.parts[1].container.capacity,20,'independent server copy')
end)
ReviewCase('04_cabinet_only_appliance_tracker_does_not_restore_on_minute',function()
    local v=ReviewFixture({'Base.Mov_ModernCounter'})
    VLS.Server.trackVehicle(v)
    ReviewMinute()
    ReviewEq(v.parts[1].container.capacity,20)
end)
ReviewCase('05_original_update_restores_even_with_matching_item_and_profile_ids',function()
    local v=ReviewFixture({'Base.Mov_ModernCounter'})
    local p=v.parts[1]
    VLS.Update.UniversalSlot(v,p,1)
    ReviewEq(p.container.capacity,50)
    ReviewEq(p.data.vlsEquipmentItemId,p.item.id)
    ReviewEq(p.data.vlsContainerProfileVersion,2)
    local writes=p.container.writes
    VLS.Update.UniversalSlot(v,p,1)
    ReviewEq(p.container.writes,writes,'no redundant capacity write')
end)
ReviewCase('06_candidate_init_restores_every_slot_preserving_identity_and_damage_cache',function()
    local v=ReviewFixture({'Base.Mov_ModernCounter','Base.Mov_WoodenCounter','Base.Mov_Microwave'})
    local damageState=VLS.Damage.Init(v)
    local expected={50,50,5}
    for i,p in ipairs(v.parts) do
        local item,container,contents,entry=p.item,p.container,p.container.contents,p.container.contents[1]
        ReviewCandidate.Init(v,p)
        ReviewEq(p.container.capacity,expected[i])
        ReviewEq(p.item,item);ReviewEq(p.container,container);ReviewEq(p.container.contents,contents);ReviewEq(p.container.contents[1],entry)
        ReviewEq(p.item.condition,80)
        ReviewEq(VLS.Damage.Init(v),damageState)
        local writes=p.container.writes
        ReviewCandidate.Init(v,p)
        ReviewEq(p.container.writes,writes)
    end
end)
ReviewCase('07_candidate_access_recovers_injected_reset_but_not_unauthorized_access',function()
    local v,ch=ReviewFixture({'Base.Mov_ModernCounter'})
    local p=v.parts[1]
    ReviewCandidate.Init(v,p)
    p.container.capacity=20 -- explicitly injected reset, NOT engine event
    ReviewEq(ReviewCandidate.Access(v,p,ch),true)
    ReviewEq(p.container.capacity,50)
    p.container.capacity=20
    ch.vehicle=nil
    ReviewEq(ReviewCandidate.Access(v,p,ch),false)
    ReviewEq(p.container.capacity,20)
end)
ReviewCase('08_candidate_init_uses_individual_KI5_profiles_not_uniform_50',function()
    local v=ReviewFixture({'Base.Mov_ModernCounter','Base.Mov_SmallPineCabinet','Base.Mov_FridgeMini'},'Base.Trailer87Scamp16')
    for i,p in ipairs(v.parts) do
        ReviewCandidate.Init(v,p)
        ReviewEq(p.container.capacity,({50,10,20})[i])
    end
end)
print('RESULT 8/8 offline function checks passed; no runtime failure/reload/transfer was captured')
