# WANDERER — World Bible

**Current consolidated design · 10 Oct 2026**  
**SPOILERS: developer reference, NOT player-facing.** Status is [PROPOSED] unless marked [LOCKED INTENT] or [OPEN].  
Read alongside [GAME.md](GAME.md) and [WORKFLOW.md](WORKFLOW.md).

## 1. Setting and fantasy [LOCKED INTENT]

- Many thousands of years after the collapse of present-day civilization: **post-post-apocalypse**. For residents this is their ordinary world, with largely late-medieval/early-modern tools they can make and repair.
- New towns, languages, histories and political structures developed over generations of migration and exchange. Old buildings are usually buried, damaged, recycled or misinterpreted, not conveniently functional.
- **The Sundering Sky / คืนฟ้าแตก:** ancient meteorite-related event. Meteorites **may have contributed** to collapse; the actual combination of causes is **[OPEN]**.
- **Starstone / ดาราศิลา:** meteorite-derived rare material used inside properly crafted weapons, tools and ornaments. Its unusual power is **real and widely known about, but direct encounters are rare**.
- **Resonance / การพ้องพลัง:** item-gated activation, with risk to user (**Strain**) and item (**Stress / Integrity**). Skilled handling helps; craftsmen and counterfeiters exist. No generic bare-handed spellcasting, free magic economy or ordinary revival of Dead. Resurrection remains a separate [LATER/OPEN] mystery.
- NPCs use or decline these devices according to their own decisions. In a prototype, a Pulse Pendant might stabilize Alive/Down but cannot revive Dead. No magic feature needs implementing before its milestone.

## 1A. International-first identity & cultural synthesis [DESIGN DIRECTION]

**เป้าหมายที่ผู้สร้างกำหนด [LOCKED INTENT]:** ภูมิศาสตร์จริงใต้โลกยังอ้างอิงดินแดนไทยและเพื่อนบ้าน แต่ **อัตลักษณ์ที่ผู้เล่นรับรู้ในช่วงใหญ่ของเกมต้องเป็น original, international-facing fantasy world** ไม่ใช่ “เกมย้อนยุคไทยที่เปลี่ยนชื่อสถานที่”. ความหลากหลายและภาษา/ภาพที่เข้าถึงผู้เล่นต่างประเทศเป็นเป้าหมายด้านการออกแบบ **ไม่ใช่คำรับประกันยอดขาย**. รักษาเบาะแสไทยจาง ๆ เพื่อให้ผู้เล่นไทยค้นพบเองเมื่อเวลาผ่านไป ตาม §5.

**หลักการผสมวัฒนธรรม — ไม่ยกประเทศปัจจุบันไปวางทั้งประเทศในอนาคต:** หลังการล่มสลายหลายพันปี การย้ายถิ่น การแต่งงาน การค้าระยะไกล การรับช่างและตำราเก่าทำให้ประเพณีและภาษาผสม/เปลี่ยนไป. ใช้ *functional inspirations* จากเทคโนโลยี วัสดุ ภูมิอากาศ อาชีพ สถาบัน และคติชีวิต แล้วสร้างสังคมใหม่ที่มีประวัติของตัวเอง; **หนึ่ง region ≠ หนึ่งประเทศ/หนึ่งเชื้อสาย**.

| แหล่งแรงบันดาลใจ (ไม่ใช่ประเทศที่ยังดำรงอยู่ตรง ๆ) | สิ่งที่นำมาแปรรูปเป็นวัฒนธรรมใหม่ได้ | สิ่งที่ไม่ควรทำ |
|---|---|---|
| **เอเชียตะวันออกเฉียงใต้** — พื้นที่ไทยเดิมและชุมชนเกี่ยวเนื่องกับลาว กัมพูชา เมียนมา เวียดนาม มาเลย์ | อาคารรับฝน/น้ำท่วม, ตลาดท่า, เรือและงานไม้, ลายทอแบบนามธรรม, เครือญาติ/เส้นทางข้ามน้ำ, อาหารจากพืชท้องถิ่น | ยกวัด/ชุดประจำชาติ/พิธีศาสนาที่ระบุประเทศตรง ๆ มาเป็นการตกแต่งทุกเมือง |
| **จีนและญี่ปุ่น** | การฝึกงานช่างหลายรุ่น, งานเข้าไม้และการดูแลเครื่องมือ, ตรารับรองของสินค้า, สถานีพักทาง, รูปทรงอุปกรณ์/ชุดเดินทางที่ผ่านการดัดแปลง | ให้ทุกคนเป็นซามูไร/นินจา, ใช้สัญลักษณ์จักรพรรดิหรือชื่อเมืองจริงโดยไร้ประวัติ |
| **ตะวันออกกลางและเครือข่ายเอเชียกลาง** | กติกาคาราวาน, โรงพักทางในพื้นที่ร้อน/แห้งเมื่อเหมาะกับภูมิอากาศ, การค้า ความรู้ดาวและการแพทย์ที่เดินทางผ่านผู้คน | เหมารวมเป็น “ชาวทะเลทราย”, สลับศาสนาจริงเป็นตัวร้าย หรือใส่อาคารทะเลทรายกลางป่าฝน |
| **ยุโรปหลายยุค** | ธรรมนูญนครการค้า, สมาคมช่าง, สะพานหิน/กังหัน/เครื่องกลพื้นฐานที่ซ่อมได้, เครื่องแต่งกายสำหรับหนาว/เดินทางบางกลุ่ม | ทุกเมืองมีปราสาทโกธิก, ขุนนางสวมเกราะยุโรปเหมือนกัน หรือยึดความเป็นยุโรปเป็นมาตรฐาน “อารยะ” |

**ตัวอย่างการผสมที่มีเหตุผล:** Stonegate เป็นเมืองด่านฝนสลับแล้งหลังคาระบายน้ำได้ดีและอาคารไม้/ดิน/หินท้องถิ่น; มีสภาสัญญาแบบเมืองการค้า ระบบบันทึกพ่อค้าและการฝึกช่างหลายสาย บางครอบครัวใช้ผ้าทอหรือเครื่องรางที่คนต่างภูมิภาคนำมา — **ไม่ต้องติดป้ายว่าบ้านหลังไหนเป็น “ไทย/จีน/ญี่ปุ่น/ยุโรป”**. รูปแบบที่อยู่ได้เกิดจากทรัพยากร อุณหภูมิ ฝน ประวัติการค้า และคนจริงในเมือง

### ภาษา ชื่อผู้คน และการสื่อสารสากล

- **Presentation [PROPOSED]:** รองรับข้อความที่แปลเป็นภาษาอังกฤษและไทยได้โดยรักษาความหมายเดียวกัน; ใช้ชื่อ proper nouns ที่สั้น ออกเสียงได้ และจำได้ในหลายภาษา (เช่น **Stonegate**), ส่วนชื่อภาษาไทยในเอกสารบางรายการอาจเป็นเพียง **คำแปลทำงาน** ไม่ใช่ชื่อที่ชาวโลกใหม่ออกเสียงจริง
- **In-world languages [OPEN]:** ผู้คนอาจมีภาษาท้องถิ่นหลายสายและภาษากลางการค้า แต่ผู้เล่นไม่ต้องเรียนภาษาจริงก่อนเล่น; dialog/UI เป็นการแปลเพื่อการนำเสนอและควรอธิบายอาชีพ/ความสัมพันธ์ชัดกว่าสำเนียงเลียนแบบประเทศจริง
- ชื่อ NPC ทั้งหกและเมือง R1–R7 ยัง **[PROPOSED]**; ทบทวนการอ่านในอังกฤษ/ไทยเมื่อทำบทสนทนาและ localization จริง **ไม่บังคับเปลี่ยนทั้งหมดตอนนี้**
- อย่าสื่อว่าความเก่ง ความเมตตา เวทมนตร์ ความเชื่อฟัง หรือ Class ติดมากับเชื้อสาย/สำเนียง/หน้าตา

### สังคม เครื่องแต่งกาย และความรู้

- **การปกครอง:** นครรัฐ เครือเมืองแม่น้ำ สมาคมช่าง ผู้ดูแลเส้นทางและตลาดมีโครงสร้างผสม ขัดแย้งตามน้ำ เสบียง สัญญาและความปลอดภัย ไม่จำลองจักรวรรดิปัจจุบันตามชื่อเดิม
- **เครื่องแต่งกาย:** ตัดสินจากอาชีพ การเคลื่อนไหว ฝน/แดด/หนาว การหาวัสดุ และการซ่อมซ้ำก่อนการอ้างวัฒนธรรม; ใช้รูปเงาที่น่าจดจำหลายแบบแต่คง art direction pixel-art เดียวกัน และหลีกเลี่ยงชุดประจำชาติครบชุด
- **ความรู้:** ช่างตีเหล็ก ผู้รักษา ช่างเรือ นักแผนที่ นักบันทึก และนักศึกษาซากพึ่งความรู้ที่เรียน/สืบต่อ/พิสูจน์ ไม่ให้กลุ่มเดียวผูกขาดภูมิปัญญาโลก; ตำราบางบทอาจข้ามทวีปผ่านการค้าและมีการแปลผิด
- **ความเชื่อ:** ให้มีความหลากหลายภายในเมืองเดียว ใช้จริยธรรมของชุมชน การไว้ทุกข์ และพิธีท้องถิ่นที่เกิดจากประสบการณ์โลกใหม่; ไม่ใช้ศาสนาร่วมสมัยจริงเป็นสัญลักษณ์ฝ่ายดี/ฝ่ายชั่วแบบง่าย

### ร่องรอยไทยที่ค่อย ๆ ค้นพบ [REVEAL-GATED]

- **Early R0/R1:** รายละเอียดที่ไม่จำเพาะประเทศ เช่น การยกพื้นรับน้ำ เครื่องจักสาน/ผ้าทอรูปเรขาคณิต ภาชนะอาหารจากพืชท้องถิ่น วิถีเรือในเขตร้อน **ใช้เพียงบางฉาก** และผสมกับวัฒนธรรมอื่นจนไม่ใช่ชุดเบาะแสพร้อมเฉลย
- **R2:** เบาะแสด้านภูมิประเทศ ซากคมนาคม และเศษอักขระจากคนละที่เริ่มสอดคล้องกัน; เครื่องแต่งกายหรืออาหารอย่างเดียว **ไม่เป็นหลักฐานพอ**
- **R3/R4:** จึงค่อยมีวัตถุ/ป้ายเก่าที่ระบุพื้นที่ชัดเมื่อผู้เล่นสืบจนถึงจุดนั้น ผู้เล่นไทยที่รู้จักสถานที่อาจเชื่อมโยงเอง; ผู้เล่นประเทศอื่นยังเข้าใจคุณค่าของการค้นพบโลกเก่าได้โดยไม่ต้องรู้ภูมิศาสตร์ไทยมาก่อน
- **ห้ามก่อน reveal:** ธงไทยหรือธงประเทศปัจจุบัน, ชื่อจังหวัด/ประเทศ, ชุดประจำชาติชุดเดียวครบทุกองค์ประกอบ, วัด/แลนด์มาร์กจำเพาะแบบสมบูรณ์, แผนที่ silhouette ประเทศ, และข้อความการตลาดที่ประกาศว่าเป็นประเทศไทยอนาคต

**International accessibility:** ทำให้เหตุผลของ NPC, ผลลัพธ์เควส และอารมณ์เข้าใจง่ายสำหรับผู้เล่นทุกประเทศโดยไม่ต้องรู้ความหมายพิธี/สุภาษิตไทย; สำนวนท้องถิ่นใช้เท่าที่มีบริบทให้เข้าใจ การรองรับภาษาและการตลาดเป็นแผนระยะผลิต ไม่เพิ่มระบบ localization ใน M1.5B.

## 2. Grounded geography [DESIGNER ONLY]

The playable heart is land corresponding to **parts of present-day Thailand and nearby connected territory**, thousands of years transformed. Stonegate is a fictional pass settlement inspired in broad geographic terms by the **western edge of the Korat Plateau, near today's Pak Chong–Lam Takhong corridor**. This is a design reference, **not a claim of exact future town coordinates**. Mountains and basin relationships remain plausible; river courses, coastlines, vegetation and populations may change where given environmental reasons. Scenario B (“changed substantially but still geographically legible”) remains [PROPOSED]. Generated concept art is not a GIS base.

**Public repository warning:** this geographic crosswalk is readable by visitors to the public repo. Do not export it into the game, metadata, marketing, early dialogue, achievements or map labels. To conceal it from source readers as well, move such details to a separate *private* source; renaming Git files cannot erase old history.

## 3. Regional atlas [PROPOSED]

These are **seven ecological-cultural planning zones**, not seven modern-style countries or seven fixed national cultures. Peoples, fashions, languages, knowledge and institutions mix across corridors. IDs are for developers, not player UI. **The Thai terms below are provisional designer-facing/localized working names; player-facing English labels and pronunciation will be reviewed in localization, not locked here.**

| ID | Early player-facing name | Anchor settlement | Economic and social tension |
|---|---|---|---|
| R1 | **นครหุบเขาสายหมอก** | เวียงเมฆธาร | Valley towns, guides, records; keeping dangerous passes closed versus supplying neighbors |
| R2 | **แนวกำแพงป่าตะวันตก** | ด่านไพรคด | Independent forest/pass settlements and guides; safe stewardship versus route monopoly |
| R3 | **สมาพันธรัฐสี่สายน้ำ** | ท่ารวมธาร | River-towns’ agreements, grain and boats; upstream/downstream water disputes |
| R4 | **ทุ่งลมแดง** | **นครประตูหิน (Stonegate)** | Plateau approaches, caravan gates; opening abandoned roads versus taxation and safety |
| R5 | **ดินแดนสองลุ่ม** | ท่าหมอกคราม | River-crossing communities, witnesses and trade; disputed boats and missing persons |
| R6 | **นครอ่าวแก้ว** | ท่าเวฬา | Port-city merchants, shipwrights and counterfeit rare objects |
| R7 | **หมู่เมืองสายฝน** | ท่าลมคู่ | Peninsula ports, seasonal sea trade and disputed access across passes |

**Spoiler-sensitive naming:** older drafts used “โครา” for R4 and “ภูพาน” for R5. **Never use those as early player-facing names.** Avoid modern provinces, rivers, highways, state emblems and intact country outlines early.

**Eight macro corridors** are only a writing/planning graph, not routes to implement now: C1 R3–R4; C2 R4–R5; C3 R3–R1; C4 R3–R2; C5 R3–R6; C6 R6–R7 sea; C7 R2–R7 **long, multi-stage western/peninsula corridor**, not a direct shortcut; C8 R5–outside-region river trade. Food, water, salt, medicine, timber, metalwork, rope, maps and news matter more than the exceptional Starstone trade.

## 4. Stonegate — starting hub [PROPOSED]

A relatively small town at a trade pass between lowland routes west and higher caravan paths east, on ground safer than the nearby seasonal creek. Merchants arrive for food, protection, wheel repair, healers, jobs and news. An earlier caravan disappeared near an abandoned route, which has remained closed. **Why it disappeared is [OPEN] and need not involve Starstone.**

**Developer districts (not nine playable scenes):** D1 western gate; D2 two-seal market; D3 caravan yard; D4 smith/wheel repair; D5 well and grain store; D6 oath-hall/council; D7 adventurer exchange; D8 rest and healer; D9 upper watch post. Place water away from animal waste/smithing, and make the healer accessible to returning injured travelers. See [editable developer layout](maps/stonegate_map02b_layout_v0.1.svg), which is a **rough schematic, not scaled or scientifically geolocated**.

**Five council interests:** gate security/tolls; caravan trade; water/grain; outskirts households; craft/medical safety. Factions overlap: council, caravan guild, old-path guardians, grain keepers, craft house, missing-person relatives, scavenger dealers. No faction is inherently evil.

**Eight non-recruitable role concepts:** ธานิน (gate), วาริน (caravan), อัยยา (water), พรรณรา (healer), หาญช่าง (bridge/crafts), ศิลัน (old-path guardian), เนตรา (ledger of the lost), มลย์ (salvage merchant). **No individual NPC schedule system required.**

**Six recruitable NPC concepts (party cap still three NPCs):**
- **คีริน** — former gate guard; discipline, caution, regrets the closure.
- **เมียร่า** — trainee healer; compassion and reluctance to abandon the injured.
- **รอนโด** — caravaner; bravery and loyalty to promises.
- **อาริน** — mapmaker; curiosity, suspicion of authority, lost relative.
- **คอล** — craft apprentice; checks equipment safety, may refuse risky shortcuts.
- **ลาเวน** — wandering escort; self-preservation, financial obligations.

They are individual characters, **not fixed commands**: fear, trust, injuries, competing promises and risk may alter choices.

**Routes:**
- **A / early player label “ทางประตูบน”:** gate pass → remnants of bridge → resting settlement; staffed, cost/tolls, seasonal restrictions.
- **B / early player label “รอยทางเก่า”:** broken raised road → collapsed tunnel entrance → missing survey marker; uncertain shortcuts, cave-ins, possibility of retreat. Not confirmed magic.

**Three candidate quests for Vertical Slice:** Q1 send message across pass (choose route, report outcome); Q2 trace missing caravan and aid survivors or recover evidence; Q3 investigate reported lights near closed route (distinguish rumors from observations, **no guaranteed Starstone encounter**). Failure can produce information or partial reward, not just a softlock.

**Event pool** (pick only when journey exists): seasonal gate closure, injured traveler, conflicting maps, old pillars, medicine request, animal danger rumors, confiscated map, tunnel sound, alleged magic trinket, belonging from missing caravan. **Four proposed enemy archetypes:** startled boar, feral dog pack, fake gate bandits, guards/escorts in conflict. City implementation remains **one Town UI** grouped into quests/recruiting, supplies, repair, healing, gate business and route selection.

## 5. Delayed identity revelation [LOCKED INTENT for pacing]

**Desired player experience:** spend a substantial portion of the game exploring an **original, culturally blended, internationally accessible fantasy world**, then combine real geographic clues into an unsolicited “Wait, I recognize this place!” moment. Do not explain the location in title, trailer, opening city or NPC exposition.

| Gate | Player can learn | Still withheld |
|---|---|---|
| **R0 — Opening/first slice** | Stonegate, two local routes, generic deteriorated infrastructure, contradictory rumors | Full seven-region atlas, country silhouette, actual place names and road signs |
| **R1 — Familiarity** | Several geographically plausible ruins and incomplete inscriptions in different contexts | Clear modern identifying labels |
| **R2 — Convergence** | **At least three independent clue types**: geography + infrastructure + old writing/object, gathered through exploration | NPC proclamation of old country |
| **R3 — Recognition** | A geographically specific ancient clue after significant exploration; knowledgeable players can deduce themselves | Forced exposition or collapse/magic explanation |
| **R4 — Later confirmation** | Optional or late discovery of enough old records to confirm the relation | Unearned answer to all mysteries |

Reveal gates follow **progress and evidence, not a fixed hour count**. Thai UI is a translation convention, not evidence that inhabitants speak modern Thai. A player unfamiliar with local geography should still enjoy the ruin mystery and companion story.

**Early safe text examples:** “ทางประตูบนมีคนดูแล แต่รอยทางเก่าไม่มีใครรับรอง”; “คนที่ไม่กลับอาจทิ้งข่าวไว้มากกว่าที่เราคิด”; “ผู้ดูแลทางต้องการหลักฐาน ไม่ใช่คำทำนาย”. No early NPC may say “this is old Thailand”.

**Player map:** [local route SVG concept](maps/stonegate_player_route_R0_v0.1.svg). No R1–R7/D1–D9 codes or modern coordinates in actual player UI. Full map and secret layers belong to designers until later discoveries.

**Before release:** inspect dialog, localization, UI, achievements, filenames/metadata in exported resources, screenshots/trailers/store copy and Godot export preset; user-visible files must not reveal real-world references before gates. Check with Thai-geography-familiar and unfamiliar playtesters to locate when recognition happens. **This is a test plan, not QA already passed.**

## 6. Open decisions and scope boundaries

**[PROPOSED]:** local naming and bilingual presentation conventions, specific cultural combinations/visual motifs, place names, city factions, six recruitable cast, Stonegate district positions, quests, transformed-terrain scenario, council structure.  
**[OPEN]:** number of years, exact coast/river changes, boundaries, economy/prices, how the caravan vanished, impact cause and actual Starstone source, resurrection mechanism, which specific clue confirms geography.  
**[LATER]:** playable cities beyond Stonegate, full regional diplomacy/economy, deep crafting/mining, whole-world atlas, full invented languages.  
**[LOCKED INTENT]:** internationally legible and culturally diverse *new* civilizations above a grounded real-world geography, NPC autonomy, permadeath, rare item-gated power, slow discovery of the old geographic identity.

The worldbuilding supports the game; it **does not change the active combat milestone**.
