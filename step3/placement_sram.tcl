#placement
# Stays at 4. The step1 version raised this to 7 after the floorplan, which
# is right for the chip but wrong here: the abstract LEF declares the macro
# as occupying M1-M4 (write_lef_abstract -specifyTopLayer 4), so anything
# routed above M4 inside the macro is invisible to the parent and the parent
# will route straight through it.
setMaxRouteLayer 4
saveDesign ${design}_floorplan.enc
setPlaceMode -timingDriven true -reorderScan false -congEffort medium -modulePlan True -placeIOPins false
setOptMode -effort high -powerEffort high -leakageToDynamicRatio 0.5 -fixFanoutLoad true -restruct true -verbose true
place_opt_design

# fillers causing drcs, to be added at the end before signoff
addFiller -cell { DCAP16 DCAP32} -merge true

saveDesign ${design}_placement.enc
