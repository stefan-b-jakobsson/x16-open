.export kvswitch_tmp1
.export kvswitch_tmp2
.exportzp imparm

.segment "K_ZP"
    imparm: .res 1

.segment "K_LRAM"
    kvswitch_tmp1: .res 1
    kvswitch_tmp2: .res 1
