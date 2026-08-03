# decap addition
addFiller -cell {DCAP DCAP4 DCAP8 DCAP16 DCAP32} -merge true

# filler addition
set FillerList [list FILL1 FILL2 FILL4 FILL8 FILL16 FILL32]
addFiller -cell $FillerList

#DRC LVS checks to make sure no overlapping internal shape shorts
verifyGeometry
verifyConnectivity
