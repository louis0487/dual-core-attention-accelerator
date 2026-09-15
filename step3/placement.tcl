#placement
setMaxRouteLayer 7 
saveDesign ${design}_floorplan.enc
setPlaceMode -timingDriven true -reorderScan false -congEffort medium -modulePlan True -placeIOPins false
setOptMode -effort high -powerEffort high -leakageToDynamicRatio 0.5 -fixFanoutLoad true -restruct true -verbose true
place_opt_design

# fillers causing drcs, to be added at the end before signoff
addFiller -cell { DCAP16 DCAP32} -merge true

saveDesign ${design}_placement.enc
