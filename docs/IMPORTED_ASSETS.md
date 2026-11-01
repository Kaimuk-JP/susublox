# โมเดลที่นำเข้าจาก Creator Store

นำเข้าด้วย Studio MCP (`search_asset` / `insert_asset`) เก็บใน `ServerStorage.ImportedAssets` (Cars / Trees / Props)
**โมเดลอยู่ใน Place file เท่านั้น (ไม่ใช่ใน git) — ต้องกด Ctrl+S ใน Studio**

## ขั้นตอนตรวจความปลอดภัย (ทุกโมเดล)
- ลบ Script/LocalScript/ModuleScript, Sound, ParticleEmitter/Fire/Smoke/Sparkles, SurfaceGui/BillboardGui/ScreenGui,
  Remote/Bindable Event/Function, Seat/VehicleSeat, ProximityPrompt, ClickDetector, Humanoid
- Anchored ทุกชิ้น, CanCollide=false, CanTouch=false
- Cars: PrimaryPart = ชิ้นใหญ่สุด, Pivot = กึ่งกลางใต้ล้อ, หน้ารถหัน -Z (ตรวจด้วยภาพ preview), scale ให้ ~4.2x9
- Trees: Pivot = โคนต้น (ชิ้นต่ำสุดเยื้อง pivot ≤0.6 stud), สูง 12 studs
- เกณฑ์รับ: MeshPart ≤ 60 (ใช้จำนวนชิ้น; ไม่มี API อ่านจำนวนสามเหลี่ยมได้ จึงไม่ได้วัด triangle จริง)
- Decal/Texture: โมเดลที่คัดเข้าเหลือ Decal เพียง 1 ชิ้น (Tree_Sakura2) — **ไม่ได้ตรวจเนื้อหารูปด้วยตา** ทุกโมเดลดูจาก preview เฉพาะรถ

## Cars / Bikes (ServerStorage.ImportedAssets.Cars) — ชุดยุค ~1985-2005 (อัปเดต step 8-10)
ทุกโมเดล normalize แล้ว: ยาวตามแกน Z, **หน้ารถ = -Z**, Pivot = กึ่งกลางใต้ล้อ (WorldPivot, ไม่มี PrimaryPart), ไม่มี Script/Sound/Decal/Weld, ตัด Decal ทั้งหมด (กันโลโก้)
Attribute `Kind` = kei | sedan | van | bike ใช้สุ่มสัดส่วน (kei 40 / เก๋ง 20 / ตู้-กระบะ 15 / มอเตอร์ไซค์ 15 / แท็กซี่ 10)
บิ๊กไบค์/สกูตเตอร์มี `RiderY` `RiderZ` `RiderPose` (ตำแหน่งสะโพกคนขี่ใน pivot space, ท่า bike/scooter)
| ชื่อ | Kind | Asset ID | ชื่อต้นฉบับ | ผู้สร้าง | ชิ้นส่วน (BasePart) | ความยาว (studs) |
|---|---|---|---|---|---|---|
| Car_MeshSedan | sedan | 9470295166 | Moving Sedan mesh car | PEPPAROMPE | 1 | 9.0 |
| Car_HijetKeiVan | van | 88771625973855 | 1981 Daihatsu Hijet Tianjin TJ 110 Van | FerreroMexx2 | 15 | 8.9 |
| Car_AE86 | sedan | 1777924328 | Toyota Corolla Ae86 Trueno | Hoonic0rn | 47 | 9.0 |
| Car_RX7 | sedan | 2535365320 | 1988 Mazda RX7 FC3S | trafficracer | 62 | 9.0 |
| Car_CivicEG | kei (compact) | 8320827818 | Honda Civic EG Hatch | Tyyjz_91 | 57 | 9.0 |
| Car_WagonR | kei | 3121285452 | 1998 Suzuki Wagon R CV51S 4WD | 0toko | 83 | 9.0 |
| Car_SambarTruck | van | 5353980325 | Subaru Sambar | J03EY | 88 | 7.8 |
| Car_HijetTruck | van | 1086524580 | 2015 Daihatsu Hijet Truck SG | DaliuagTeam | 51 | 7.8 |
| Bike_Moped (เดิม Car_Moped) | bike | 1322080939 | Moped (ทรง Vespa) | WiliFIN | 39 | 6.7 |
| Bike_Dream305 | bike | 1935238850 | 1969 Honda Dream 305 | Ujiyasu | 95 | 7.8 |
| Bike_Underbone | bike | 88489555740035 | Moto (ทรง underbone/Honda Wave) | bvrchaff_flare | 56 | 7.1 |
| Bike_SuperCub | bike | 18980811003 | 2012 Honda Dream 110i Super Cub | (ไม่ได้บันทึกชื่อผู้สร้าง) | 68 (ต้นฉบับ 174 → ตัด Wheel โปร่งใส/Seat/R15 dummy/สคริปต์ 34) | 6.2 |
| Bike_Rebel | bike | 4573621467 | Honda Rebel | (ไม่ได้บันทึกชื่อผู้สร้าง) | 68 (ต้นฉบับ 73) | 6.8 |
| Car_CrownTaxi | taxi | 5061252915 | Toyota Crown taxi | (ไม่ได้บันทึกชื่อผู้สร้าง) | 110 (ต้นฉบับ 123) | 9.0 |

ถอดออกจากพูลเพราะไม่เข้ายุค/ไม่ใช่รถญี่ปุ่น: Car_SovietSedan (Volga), Car_PolyVan (Ford Transit), Car_GreenSedan (เก๋งเขียวยุคใหม่)
แท็กซี่: ใช้ Car_CrownTaxi จริงแล้ว (ดูหัวข้อท้ายไฟล์)
ที่ลองแล้วตัดทิ้ง (ชิ้นเกิน/สคริปต์เยอะ/ไม่เข้ายุค): Kei Truck 17248998748 (241 ชิ้น), Honda Acty 12374570495 (113), Nissan R32 1970532634 (113, mesh 109), Ninja 650 477270814 (192), Fireblade 11126200354 (162), Crown taxi 678438548 (371), Yellow cab 8627987379 (ทรง Camry ยุคใหม่)
**ไม่ได้ตรวจ**: ความถูกต้องของรุ่น/ปีตามจริง (ดูจากภาพ preview เท่านั้น), ไม่ได้วัดจำนวนสามเหลี่ยม, ปี/ยี่ห้อมาจากชื่อผู้สร้าง; Bike_CafeRacer ทรงคล้าย Ural/Dnepr (ไม่ใช่ญี่ปุ่น), Peugeot 103 เป็นมอเตอร์ไซค์เล็กฝรั่งเศสยุค 80
ทิศหน้า: ตรวจด้วยภาพจากด้าน -Z ทุกคัน (AE86/RX7/Hijet Truck/CafeRacer/Peugeot ถูกกลับ 180° ตอน import) และวัดใน Play: รถวิ่งหันหน้าตามทิศวิ่ง (dot = 1.00), รถจอดขนานแกนถนน, ล้อล่างสุดห่างพื้น ≤ 0.08 studs

### คนขี่มอเตอร์ไซค์
`RigFactory.CreateRider(parent, pose)` — R15 จาก HumanoidDescription แปลง AnimationConstraint เป็น Motor6D แล้วตั้งท่า (เอนตัวไปหน้า มือจับแฮนด์ เข่างอ) วางชิ้นส่วนเองด้วย forward kinematics, ไม่มี Humanoid/ไม่ชน/Massless, weld เข้ากับตัวรถ, ถูกลบพร้อมรถ
เสื้อยืดหลายสี ผมปกติ (spiky/short/side/pompadour) หมวกกันน็อก 40% — มอเตอร์ไซค์รถวิ่ง 100% มีคนขี่, จอดข้างทาง 50%

## Trees (สูง 12 studs)
| ชื่อ | Asset ID | ชื่อต้นฉบับ | ผู้สร้าง | ชิ้น (MeshPart) |
|---|---|---|---|---|
| Tree_Sakura1 | 16014247305 | Japanese Sakura Tree v1 | kedyhizm | 6 (2) |
| Tree_Sakura2 | 9527121899 | Japanese Sakura Tree | JhuanCarloMusico | 2 (1) |
| Tree_SakuraPark | 15343255788 | Sakura Park Tree | VonStarBlack | 3 (2) |
| Tree_Sakura3 | 3725991689 | Sakura Tree | plentune | 2 (1) |
| Tree_Pine1 | 5616880673 | Low poly pine tree | smartycar23 | 2 (2) |
| Tree_Pine2 | 4830544188 | Low Poly Pine Tree FREE!! | cocajola3 | 2 (2) |
| Tree_Pine3 | 2852057943 | Low-poly Pine Tree | rik4100 | 2 (2) |
| Tree_GinkgoYellow | 119994048581892 | Birch Tree (ใบเหลือง ใช้แทนแปะก๊วย) | Striatp | 2 (2) |
| Tree_GoldGreen | 95316078430275 | Birch Tree (เขียว-ทอง) | Striatp | 2 (2) |
| Tree_Zelkova | 17031038456 | Brookhaven realistic tree (ใช้แทนเซลโคว่า) | Vany9999ZV | 3 (2) |

ไม่พบต้นแปะก๊วย/เซลโคว่าตัวจริง — ใช้ต้นไม้ใบกว้างที่ใกล้เคียงแทน

## Props (เก็บไว้ ยังไม่มีโค้ดเรียกใช้)
| ชื่อ | Asset ID | ชื่อต้นฉบับ | ผู้สร้าง | ชิ้น (MeshPart) |
|---|---|---|---|---|
| Prop_Torii | 131200625309501 | Torii Gate Japanese Cherry Blossom Gates Shrine | Thunfl1500 | 36 (0) |
| Prop_StreetLantern | 122375247270818 | Low Poly Street Lantern Lamp Light Post | Content Deleted - 158552482 | 8 (8) |
| Prop_VendingMachine | 10904552162 | Snack Vending Machine Mesh PBR | Ligij | 5 (3) |
| Prop_Forklift | 12635164828 | Forklift (Prop) | oreoPL2 | 1 (1 MeshPart + SurfaceAppearance) — Pivot ที่พื้น ส้อมชี้ -Z ยาว 10 studs; ใช้แทน BK.forklift ผ่าน `BK.importedProp` |

ไม่ได้นำเข้า: เสาไฟฟ้า (ตัวที่ลองมี 675 ชิ้น, ใหญ่ 64x83 studs), ตู้ไปรษณีย์/ศาลเจ้าเล็ก (ไม่ได้ค้นหา)

## งานปรับสไตล์ญี่ปุ่นสมจริง (step 3)
ไม่ได้นำเข้าโมเดลใหม่ — เฟอร์นิเจอร์ริมถนนทั้งหมด (ตู้กดน้ำ ถังรีไซเคิล ตู้ไปรษณีย์ จักรยาน ทางม้าลาย ศาลเล็ก โคมหิน จิโซ) ประกอบจากชิ้นส่วนใน `src/server/StreetProps.luau`
ต้นไม้ริมถนนสายหลักใช้ `Tree_Zelkova` / `Tree_GinkgoYellow` / `Tree_GoldGreen` ที่นำเข้าไว้แล้ว (เลือกผ่าน `BK.importedTree(..., names)`)

## ตรวจรถญี่ปุ่นเพิ่ม (ยังไม่ได้นำเข้า — ไม่ได้ดูรูปทรงด้วยตา เพราะ viewport Edit ขึ้นขาว)
ตรวจจำนวนชิ้น/สคริปต์หลังแทรกเข้า Studio (ก่อนลบ Seat/ชิ้นโปร่งใส): Honda Super Cub 18980811003 = 174 ชิ้น/34 สคริปต์ (เกิน), Crown taxi 5061252915 = 123, Crown 2018 11010241182 = 178, 2011 Toyota Cab 1683082373 = 68 ชิ้น แต่เป็นทรง Camry แท็กซี่อเมริกัน (ข้อความ "Ridgefeild Cab Service" + ป้ายโฆษณาหลังคา), Honda Rebel 4573621467 = 73 ชิ้น/17 สคริปต์ (ผ่านเกณฑ์จำนวนชิ้นหลังลบสคริปต์ แต่ยังไม่ได้ดูทรง/ทิศหน้า), "CB600R" 3106461058 ที่จริงคือ BMW R1200GS (ไม่ใช่ญี่ปุ่น). ผลที่ยังค้าง: Bike_CafeRacer / Bike_Peugeot103 ยังอยู่ในพูล, แท็กซี่ยังเป็นป้ายไฟบนเก๋ง


## รอบแทนรถไม่ใช่ญี่ปุ่น + แท็กซี่จริง
- เอา Bike_CafeRacer / Bike_Peugeot103 ออกจากพูลและลบจาก ServerStorage แล้ว; เพิ่ม Super Cub / Rebel (bike, มีคนขี่) และ Crown (Kind=taxi, 10% ของรถ)
- ผ่อนเกณฑ์ชิ้นส่วนเป็น ~180 สำหรับ 3 โมเดลนี้ (รถวิ่งจำกัด ~8 คัน) วัดใน Play: เฉลี่ย 17.0 ms/เฟรม (~59 fps) ขณะมีแท็กซี่ Crown 1 คันวิ่ง + 1 คันจอด และ Rebel วิ่ง
- ลบ Script/Sound/Decal/Texture/Gui/Seat/Constraint/Joint ออก, ชิ้นโปร่งใสถูกลบ (ล้อของ Cub อยู่ใต้ชิ้นโปร่งใสต้องย้ายออกมาก่อน ไม่งั้นล้อหาย), Anchored/ไม่ชน, หน้ารถ -Z, Pivot กึ่งกลางใต้ล้อ; Rebel และ Crown ต้นฉบับหันหน้า +Z จึงหมุน 180° ตอน import
- Crown ต้นฉบับสีขาวแถบน้ำเงิน/แดง: `AmbientLife` ทาตัวถังขาวเป็นเหลือง F2B705 และแถบสีฉูดฉาดชิ้นใหญ่เป็นดำตอน spawn (ไม่แก้ไฟท้าย/ไฟหน้า); ป้ายไฟหลังคามากับโมเดล ไม่ใช้ TaxiLamp แล้ว (ยังเก็บไว้เป็น fallback ถ้าไม่มีโมเดล Kind=taxi)
- Crown ที่ลองแล้วไม่ใช้: 11010241182 (178 ชิ้น) ล้อหาย/ไม่มีชิ้นล้อในโมเดล
- ตำแหน่งคนขี่: Super Cub RiderY 3.3 RiderZ 1.0 ท่า scooter, Rebel RiderY 3.2 RiderZ 0.9 ท่า bike (ตั้งจากภาพ Play ด้านข้าง)
- **ไม่ได้ตรวจ**: ชื่อผู้สร้างจริง, ว่ารุ่นตรงตามชื่อ (ดูจากภาพ), ตัวถัง Crown เป็นรุ่นไหน/ลายโลโก้บนเมช, ภาพ Play ตรวจผ่าน ViewportFrame ฝั่ง client เพราะ viewport 3D ปกติถ่ายออกมาขาว


## สเกล/สัดส่วนเมือง (รอบปรับ proportion)
มาตรฐาน 1 stud ~ 0.35 m; ตัวละคร R15 สเกล `CombatConfig.CharScale = 0.88` (5.2 -> ~4.6 studs สูงจริง bbox ~4.8 รวมหัว) ใช้กับผู้เล่น (ProgressService) และ NPC/คนขี่ (RigFactory)
- รถนอร์มอลไลซ์ตอน spawn ใน `AmbientLife.importedCar` (`model:ScaleTo`) ความยาวเป้าหมาย: kei 10, เก๋ง 13, รถตู้/กระบะ kei 10.5, แท็กซี่ 13, มอเตอร์ไซค์ 5.5 และกว้างไม่เกิน 6.4 (Hijet Truck ต้นฉบับกว้างเกินส่วน เลยยาวแค่ ~8.7) ตำแหน่งคนขี่คูณสเกลรถ; กล่องชนรถวิ่งคิดจากขนาดจริง (Attribute HalfX/HalfZ)
- ไม่มีรถบัส/รถบรรทุกใหญ่ที่ตรวจแล้ว จึงไม่ได้เพิ่ม
- ประตูบ้าน/ร้าน/บันได สูง 5.5-5.7 กว้าง 2.6-3.2, เสาไฟถนน BK.lamp สูง ~15.4, จักรยาน (ที่ตั้งพิง/ที่จอด) ยาว ~4.6, ทางเท้าถนนสายหลัก 3.5 -> 5 (LotGen/StreetFurniture/WorldBuilder ต้องตรงกัน)
- ความสูงชั้นอาคาร ~6.5 studs (มาตรฐาน 8.5) และหน้าร้านแคบ (6-10 studs) **ยังไม่ได้แก้** (ต้องแก้ LotGen/ผังหน้าต่างทั้งเมือง)

## รอบท่าเรือ (Docks) — หาโมเดลฟรีแทนของประกอบเอง
ลองแล้ว **ไม่ใช้** (หยาบ/เล็กกว่าของที่ประกอบเองอยู่แล้ว ดูจากภาพ Edit):
- เรือ "Cargo Ship Freighter Boat Vessel Container Harbor" 112864599921554 (174 ชิ้น, 103 studs, มี 8 สคริปต์/4 เสียง) — เป็นเรือบรรทุกทั่วไปทรงกล่อง ไม่มีตู้ ไม่ดีกว่าเรือ 140 studs ของ DockKit
- เครน "Mini gantry port crane" 576547111 (21 ชิ้น) — โครงเสาแท่งบางสีแดง ดูไม่สมจริงเมื่อขยาย 10 เท่า ไม่ดีกว่าเครนทรัสส์ของ DockKit
- ยังไม่ได้ลอง/ตรวจ: โกดัง (ผลค้นหาส่วนใหญ่เป็นโมเดลภายใน/ผู้สร้างไม่ระบุ ไม่ได้ดาวน์โหลดมาดู), ตู้คอนเทนเนอร์เดี่ยว, เรือประมง, ไฟท่าเรือ
- `BK.importedProp(parent, name, cframe, scale?, folder?)` ใน BuildKit โคลนโมเดลจาก ImportedAssets (ลบสคริปต์/เสียง, Anchored, ไม่ชน); `BK.forklift` ใช้ Prop_Forklift ก่อน ถ้าไม่มีค่อยใช้แบบประกอบเอง (ใช้ทั้งท่าเรือและโกดัง รวม 9 คัน)
- ไม่ได้วัดจำนวนสามเหลี่ยม/เวลา join ใหม่หลังเปลี่ยน
