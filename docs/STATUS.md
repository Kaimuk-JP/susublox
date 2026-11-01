# สถานะการพัฒนา

โค้ดครบตามแผนเท่าที่เขียนเป็นโค้ดได้ แต่ **ยังไม่เคยรันหรือคอมไพล์ใน Roblox Studio** (เครื่องนี้ไม่มี Rojo/Studio MCP/Luau runtime)
คาดว่าจะมี syntax error/บั๊กตอนเปิดครั้งแรก — ทำตามหัวข้อ "เริ่มทดสอบ" ด้านล่าง

## เสร็จแล้ว (โค้ด)
- ต่อสู้: M1 4 จังหวะ, บล็อก/Perfect Block, Dash, hitbox ฝั่ง server, safe zone, กันยิงพวกเดียวกัน
- 6 สไตล์ x (Z X C V + ไม้ตาย), Mastery, สกิลติดตัว 2 ช่อง
- เลเวล 1–100, สเตตัส, Prestige, อันดับตามชื่อเสียง, ProfileTemplate + migration
- PlayerData (DataStore + session lock เบื้องต้น), เควสรายวัน/สัปดาห์, ล็อกอินต่อเนื่อง
- ดวล 1v1 + แต้มแรงก์, แก๊ง (ข้ามเซิร์ฟเวอร์ผ่าน DataStore), สงครามแก๊ง 4v4
- บอสหัวหน้าชมรม (ดรอปเคนโด้), บอสพเนจร 20:00, NPC + AI
- ร้านเยน, ProcessReceipt, Battle Pass 30 ขั้น, Live ops + feature flags
- บทสอน, HUD, เมนู 7 แท็บ, VFX โค้ดล้วน, กลางวัน/กลางคืน, กันโกงความเร็ว + rate limit

## ต้องทำเองก่อนเปิดตัว (ทำจากโค้ดไม่ได้)
1. **ทดสอบใน Studio**: `rokit install` -> `rojo serve` -> sync เข้า Studio แล้วแก้ error
2. **Asset จริง**: แอนิเมชัน (Moon Animator 2), เสียง, โมเดลแมพ/พร็อพ (Blender) แล้วใส่ ID ใน `src/shared/Assets.luau` (ตอนนี้เป็น 0 = ข้าม)
3. **Robux**: สร้าง Game Pass/Developer Product ใน Creator Hub แล้วใส่ ID ใน `src/shared/Shop.luau` (ตอนนี้เป็น 0 = ปิด)
4. **ProfileStore**: ย้ายจาก PlayerData เมื่อ `wally install` แล้วเสร็จ (โค้ดปัจจุบันทำงานได้ด้วย DataStore ล้วน)
5. **มือถือ/Performance**: วัด MicroProfiler บนเครื่องจริง, ตัดจำนวน part ให้ <15,000
6. ตรวจกฎ Roblox เรื่องกล่องสุ่ม/อายุก่อนเปิดขายของสุ่ม (ตอนนี้ยังไม่มีกล่องสุ่มในโค้ด)

## เริ่มทดสอบ
- ตรรกะล้วน: `tests/Logic.spec.luau`
- ทดสอบสไตล์/ท่าไม้ตายเร็ว ๆ: ตั้ง Mastery ผ่านโปรไฟล์ใน Studio (สกิลต้องการ Mastery 1/10/25/40/60)

## ภูมิประเทศ (Terrain bake)
- Place ที่เปิดใน Studio ถูก bake ด้วย `tools/TerrainBake.luau` แล้ว (`workspace` attribute `TerrainBaked=true`) — ผู้ใช้ต้อง **เซฟ Place ด้วย Ctrl+S** เอง ไม่งั้นภูมิประเทศหาย
- ถ้าแก้ flat mask (รัศมีย่าน/ระยะถนน/noise) ให้รันสคริปต์ใหม่ใน Edit mode (มัน `Terrain:Clear()` ก่อนเสมอ)
- ตรวจแล้ว: ถนน/โรงเรียน/ย่านราบ y=0.0, ช่องว่างระหว่างย่านสูงสุดที่วัดได้ ~+7 (เนินศาลเจ้า +27), รถจอด 34 คันไม่จม, น้ำแม่น้ำมี, เดินจาก spawn ถึงถนนการค้า (420,170) ได้
