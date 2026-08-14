#placement
setMaxRouteLayer 4 
saveDesign floorplan.enc
setPlaceMode -timingDriven true -reorderScan false -congEffort medium -modulePlan True -placeIOPins false
setOptMode -effort high -powerEffort high -leakageToDynamicRatio 0.5 -fixFanoutLoad true -restruct true -verbose true
place_opt_design

# fillers causing drcs, to be added at the end before signoff
# addFiller -cell { DCAP DCAP2 DCAP4 DCAP8 DCAP16 DCAP32} -merge true
# DCAPs should be added after clock and before routing.
saveDesign placement.enc
