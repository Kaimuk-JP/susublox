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
| Bike_CafeRacer | bike | 121605474431308 | Old Motorcycle (Cafe Racer) | HeroELStreamg171238 | 23 | 7.8 |
| Bike_Peugeot103 | bike | 13791700343 | 1980 Peugeot 103 | "No. 05070336 BEIJING ICP" | 40 | 6.4 |
| Bike_Underbone | bike | 88489555740035 | Moto (ทรง underbone/Honda Wave) | bvrchaff_flare | 56 | 7.1 |

ถอดออกจากพูลเพราะไม่เข้ายุค/ไม่ใช่รถญี่ปุ่น: Car_SovietSedan (Volga), Car_PolyVan (Ford Transit), Car_GreenSedan (เก๋งเขียวยุคใหม่)
แท็กซี่: ไม่มีโมเดลแท็กซี่ที่จำนวนชิ้นผ่านเกณฑ์ (Crown Comfort ที่เจอมี 371 ชิ้น) จึงใช้ **ป้ายไฟหลังคา (TaxiLamp) บนรถเก๋ง** 10% ของรถที่สุ่ม — ยังไม่ได้ทาสีแท็กซี่
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

ไม่ได้นำเข้า: เสาไฟฟ้า (ตัวที่ลองมี 675 ชิ้น, ใหญ่ 64x83 studs), ตู้ไปรษณีย์/ศาลเจ้าเล็ก (ไม่ได้ค้นหา)

## งานปรับสไตล์ญี่ปุ่นสมจริง (step 3)
ไม่ได้นำเข้าโมเดลใหม่ — เฟอร์นิเจอร์ริมถนนทั้งหมด (ตู้กดน้ำ ถังรีไซเคิล ตู้ไปรษณีย์ จักรยาน ทางม้าลาย ศาลเล็ก โคมหิน จิโซ) ประกอบจากชิ้นส่วนใน `src/server/StreetProps.luau`
ต้นไม้ริมถนนสายหลักใช้ `Tree_Zelkova` / `Tree_GinkgoYellow` / `Tree_GoldGreen` ที่นำเข้าไว้แล้ว (เลือกผ่าน `BK.importedTree(..., names)`)
