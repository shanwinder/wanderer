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

## 1A. International-first setting / วัฒนธรรมผสม [DESIGN DIRECTION]

**[LOCKED INTENT]** ภูมิศาสตร์ใต้โลกยังเป็นดินแดนที่เคยอยู่แถบไทยและเพื่อนบ้าน แต่โลกที่ผู้เล่นพบต้องดูเป็น **อารยธรรมแฟนตาซีใหม่ที่เข้าถึงได้ระดับสากล** ไม่ใช่ “ประเทศไทยเปลี่ยนชื่อ”. เป้าหมายคือช่วยให้ผู้เล่นหลากหลายตลาดเข้าถึงเรื่องเล่าได้ง่ายขึ้น **ไม่ใช่การรับประกันยอดขาย**. ร่องรอยไทยต้องเบาและค่อยบรรจบเป็นจุดเซอร์ไพรส์ภายหลัง (§5).

**หลักการ:** ผ่านมาหลายพันปี การย้ายถิ่น การค้า การแต่งงาน การแปลตำราและการดัดแปลงเทคโนโลยีทำให้วัฒนธรรมใหม่ผสมกันได้. หยิบ **หน้าที่/แนวคิด** จากอารยธรรมเก่า ไม่คัดลอกประเทศ ศาสนา ชุดประจำชาติหรือเชื้อสายเดิมทั้งชุด; **หนึ่งภูมิภาคไม่เท่ากับหนึ่งเชื้อชาติ/วัฒนธรรม**.

| แรงบันดาลใจ | สิ่งที่ผสมใหม่ได้ (ตามภูมิอากาศ/ประวัติการค้า) |
|---|---|
| **ไทยเดิมและเพื่อนบ้าน** เช่น ลาว กัมพูชา เมียนมา เวียดนาม มาเลย์ | บ้านรับน้ำฝน เรือ/ท่าค้า งานทอ อาหารเขตร้อน ชุมชนลุ่มน้ำ; ไม่ใช้แลนด์มาร์กหรือเครื่องหมายรัฐชาติที่จำได้ทันที |
| **จีน/ญี่ปุ่น** | งานไม้และช่างฝึกหัด ตราสัญญา การดูแลอุปกรณ์ สถานีพักทาง; ไม่เหมารวมให้ตัวละครเป็นซามูไรหรือนักรบแบบชาติเดียว |
| **ตะวันออกกลาง/เครือข่ายเอเชียกลาง** | การค้าคาราวาน โรงพักทางในพื้นที่ที่เหมาะ การเดินทางของความรู้แพทย์/ดาราศาสตร์; ไม่เหมารวมเป็นชาวทะเลทรายหรือใช้ศาสนาจริงเป็นศัตรู |
| **ยุโรปหลายยุค** | นครการค้า สมาคมช่าง กลไกและการก่อสร้างที่ซ่อมได้ กฎหมายสัญญา; ไม่ตั้งปราสาทโกธิกทุกเมืองหรือใช้ “ยุโรป” แทนความเจริญ |

**ออกแบบเป็นสังคมจริง ไม่ใช่งานรวมชุดคอสเพลย์:** Stonegate มีหลังคาที่รับฝนได้ ทางเกวียน/แหล่งน้ำ สภาต่อรองการค้า ช่างหลายสำนักและพ่อค้าต่างถิ่น. รูปทรงอาคาร/เสื้อผ้าเกิดจาก **สภาพอากาศ วัสดุ งานที่ทำ และความสามารถซ่อม** ก่อนแรงบันดาลใจทางชาติ; มีการผสมข้ามภูมิภาคภายในเมืองเดียว. ความรู้ช่าง แพทย์ แผนที่และบันทึกถูกถ่ายทอด/ตรวจสอบโดยผู้คนหลายที่ ไม่ผูกกับเชื้อสายหรือ Class. ศาสนา/พิธี/ความเชื่อในโลกใหม่หลากหลาย ไม่ใส่กรอบดีชั่วตามชาติหรือศาสนาปัจจุบัน.

**ภาษาและการเข้าถึงตลาด [PROPOSED]:** เขียนต้นแบบข้อความให้ **แปลอังกฤษ/ไทยได้ชัด**; ชื่อที่แสดงกับผู้เล่นควรสั้น จำง่าย อ่านออกเสียงได้หลายภาษา (เช่น **Stonegate**). ชื่อไทยของเมือง/ภูมิภาคที่อยู่ในตารางเป็น *working translations* ไม่ใช่หลักฐานว่าคนในโลกพูดไทยมาตรฐาน. NPC และชื่อเมืองเดิมยัง [PROPOSED] ไม่จำเป็นต้องเปลี่ยนทั้งหมดทันที. ผู้เล่นควรเข้าใจเป้าหมายเควส เหตุผล NPC และผลลัพธ์ได้ **โดยไม่ต้องรู้วัฒนธรรมไทยล่วงหน้า**; ระบบ localization เต็มรูปแบบไม่ใช่งาน M1.5B.

**ร่องรอยไทยแบบ Reveal-gated:** R0–R1 ใช้รายละเอียดกว้าง ๆ เพียงเป็นครั้งคราว เช่น เครื่องจักสาน อาคารยกพื้น/ระบายน้ำ ลายทอนามธรรม หรือวิถีลุ่มน้ำ **ไม่รวมเป็นชุดสัญลักษณ์ไทยครบในฉากเดียว**. R2 ให้หลักฐานอย่างน้อย 3 ชนิดจากคนละแหล่ง (ภูมิศาสตร์ + ซากคมนาคม + อักขระ/วัตถุ) เชื่อมกันได้. R3–R4 จึงค่อยเปิดสิ่งที่ชี้ตำแหน่งเดิมชัดเจนให้ผู้เล่นสังเกตเอง. ก่อนหน้านั้นห้ามชื่อจังหวัด/ประเทศจริง ธงชาติ แผนที่ประเทศเต็ม ป้ายทางหลวง หรือแลนด์มาร์กจำเพาะ. ความเป็นสากลต้อง **เสริม** การค้นพบ ไม่ทำลายภูมิศาสตร์จริงหรือความลึกของผู้คน.

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
