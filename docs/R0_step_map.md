# R0 考古 — Step 對映表(2026-08-16 W3 交付)

對帳原則:每一格都要有**檔案證據**(檔名/路徑),不憑記憶。官方目標欄已照
`Project_Instructions_official.md` 預填;其餘欄位在 server 上邊盤點邊填。

## 每個 step 資料夾回答四問(填表用)

1. **誰在跑**:資料夾裡的 run 腳本(tcl/sh)是哪些?各自叫哪個工具(dc_shell / innovus / xcelium)?
2. **吃什麼**:輸入是哪個 RTL / netlist / SDC?(看 tcl 開頭的 read/source/set 區)
3. **吐什麼**:產物是什麼(netlist / .enc / 波形 / 報告)?
4. **對官方哪段**:這資料夾對應官方 step 幾的哪句話?

## 對映表

| 官方 | 目標(預填) | 對應資料夾(哪棵樹) | 關鍵檔:run 腳本→輸入→輸出 | 當年怎麼 run | 重建要改什麼 |
|---|---|---|---|---|---|
| S1 | 單核 QK:RTL(**8-input MAC 重設計**)+合成+PnR@1GHz(WNS 負可,FAQ5=先放寬時脈)+GLS,結果落 pmem | | | | |
| S2 | 正規化:分子/分母**皆取 abs**→逐列 sum→相除→寫回 pmem;行為模擬驗證 | | | | |
| S3 | **階層式流程**:SRAM 獨立 synth+PnR 成 macro(top=M4、pin pitch 4µm、D 下/Q 上/其餘左)→核心把 SRAM 當 cell 階層合成+PnR;含 normalizer | | | | |
| S4 | 雙核:跨時脈域 sum 交換(async 協定) | | | | |
| S5 | 官方優化步:setup 0 WNS@TYP、hold@FAST,只優化最終雙核 | | | | |
| S6 | B2 列級稀疏(30%,numpy 門檻)疊在 S5 上 | | | | |

## 三道判決題(要證據檔名)

- [ ] **A. 兩棵樹的分工**:`1D_Vector_Processor/`(step1–6)vs `finalproject/1D_Vector_Processor/`(step1–5+6a/6b)——各是什麼時期/用途?重建該以哪棵為基準?(證據:兩樹同名 step 的 RTL 或 log 差異)
- [ ] **B. step6 vs step6a/6b**:6a/6b 誰是 baseline、誰是 B2 sparsity?頂層樹的 step6 又是哪個版本?(證據:RTL diff 或 run log)
- [ ] **C. 官方 S3 的 macro 規格落點**:M4 top / 4µm pin pitch / D 下 Q 上,這三條約束寫在你 step3 的哪個 tcl 的哪幾行?(這題是替 R3 提前踩點)

## 盤點時順手記(重建情報)

- 每步大約跑多久(log 時間戳頭尾)→ 重建時的預期
- 有沒有哪步當年卡過/重跑過的痕跡(多份 log、_old 檔)→ 那就是地雷區
