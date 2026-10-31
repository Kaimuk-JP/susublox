# susublox

เกม Roblox ต่อสู้โรงเรียนญี่ปุ่นสไตล์การ์ตูน — ดูแผนเต็มในไฟล์ .md และ `docs/GDD.md`

## โครงสร้าง
- `src/server` — ระบบฝั่งเซิร์ฟเวอร์ (ต่อสู้, ข้อมูลผู้เล่น)
- `src/client` — อินพุต กล้อง UI เอฟเฟกต์
- `src/shared` — config และโค้ดที่ใช้ร่วมกัน (CombatConfig)

## เริ่มต้น
1. ติดตั้ง [Rokit](https://github.com/rojo-rbx/rokit) แล้วรัน `rokit install`
2. `rojo serve` แล้วเชื่อมใน Roblox Studio
