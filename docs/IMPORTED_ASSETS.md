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

## Cars
| ชื่อใน ImportedAssets | Asset ID | ชื่อต้นฉบับ | ผู้สร้าง | ชิ้น (MeshPart) หลังล้าง |
|---|---|---|---|---|
| Car_SovietSedan | 107406088762513 | Ussr Car Russian Soviet Vehicle Sedan Cars Mesh | Content Deleted - 158552482 | 11 (11) |
| Car_PolyVan | 136255353573633 | Poly Van Low Vehicle Car Model Truck Delivery City | Content Deleted - 158552482 | 23 (23) |
| Car_MeshSedan | 9470295166 | Moving Sedan mesh car | PEPPAROMPE | 1 (1) |
| Car_GreenSedan | 14825994544 | Green Sedan Car | jams20202013 | 71 (45) |
| Car_HijetKeiVan | 88771625973855 | 1981 Daihatsu Hijet Tianjin TJ 110 Van | FerreroMexx2 | 15 (15) |
| Car_Moped | 1322080939 | Moped | WiliFIN | 39 (0) |

ได้ 6 คัน (เป้า 6-10) — ไม่มีรถบรรทุกเล็กและสกูตเตอร์ตัวที่ 2 ที่ผ่านเกณฑ์ (รุ่นอื่นที่ลองมี 75-984 ชิ้น + สคริปต์ 14-140 ตัว จึงตัดทิ้ง)
ทิศหน้าของ Car_Moped ดูจากภาพ preview ไม่ชัดเท่ารถอื่น

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
