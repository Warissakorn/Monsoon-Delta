# 12 เสียง

## [AU-01] bus
Master → Music, SFX, Ambience (สร้างในโค้ดถ้ายังไม่มี) และปรับระดับจาก settings แบบ linear_to_db

## [AU-02] data/audio.json: key → ไฟล์ใน res://assets/audio/
| key | ไฟล์ | bus | วนลูป |
|---|---|---|---|
| amb_dry | amb_dry.ogg | Ambience | ใช่ |
| amb_rain | amb_rain.ogg | Ambience | ใช่ |
| music_main | music_main.ogg | Music | ใช่ |
| sfx_click | click.ogg | SFX | |
| sfx_dig | dig.ogg | SFX | |
| sfx_fill | fill.ogg | SFX | |
| sfx_build | build.ogg | SFX | |
| sfx_destroy | destroy.ogg | SFX | |
| sfx_error | error.ogg | SFX | |
| sfx_end_turn | end_turn.ogg | SFX | |
| sfx_thunder | thunder.ogg | SFX | |
| sfx_card | card.ogg | SFX | |
| sfx_harvest | harvest.ogg | SFX | |
| sfx_win | win.ogg | SFX | |
| sfx_lose | lose.ogg | SFX | |

## [AU-03] พฤติกรรม
- API: Audio.play(key), Audio.set_ambience("dry" | "rain"), Audio.play_music(key)
- **ไม่มีไฟล์:** ข้ามแบบเงียบ (แจ้งด้วย print_verbose เท่านั้น) ห้าม crash
  - ยกเว้น amb_rain: ถ้าไม่มีไฟล์ ให้สังเคราะห์ด้วย AudioStreamGenerator (white noise ผ่าน low-pass อย่างง่าย y = y + 0.08 × (x − y), ระดับ −18 dB)
- **เปลี่ยนเสียงบรรยากาศ:** crossfade 2 วินาที
- **SFX:** ใช้ AudioStreamPlayer pool 8 ตัว เสียงเดียวกันเล่นซ้ำได้ไม่เกินทุก 0.05 วินาที
- **ฟ้าร้อง:** ตอน begin_turn ของเทิร์นฝน ถ้า preview (ยังไม่ทำอะไร) บอกว่ามีสิ่งพังหรือแพ้

| เหตุการณ์ | เสียง |
|---|---|
| apply สำเร็จ | dig/fill/build ตามชนิดคำสั่ง |
| apply ไม่สำเร็จ | sfx_error |
| กดปุ่ม UI | sfx_click |
| สิ่งก่อสร้างพัง | sfx_destroy (ครั้งเดียวต่อเทิร์น) |
| เลือกการ์ด | sfx_card |
| สรุปปี | sfx_harvest |
| จบเกม | sfx_win หรือ sfx_lose |