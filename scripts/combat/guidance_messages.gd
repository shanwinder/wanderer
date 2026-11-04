extends RefCounted

# Presentation-only message keys. Policy never reads translated text.
const MESSAGES: Dictionary = {
	"NONE": ["ไม่มีคำชี้นำ", "No guidance"],
	"ATTACK": ["เน้นโจมตี", "Attack"],
	"DEFEND": ["เน้นตั้งรับ", "Defend"],
	"HELP": ["ช่วย Player", "Help Player"],
	"FOCUS_TARGET": ["เน้นเป้าหมาย", "Focus target"],
	"FOLLOWED": ["ทำตามคำชี้นำ", "Followed"],
	"MATCHED_INDEPENDENTLY": ["ตัดสินใจตรงกันอยู่แล้ว", "Matched independently"],
	"REFUSED": ["ไม่ทำตามคำชี้นำ", "Refused"],
	"NOT_APPLICABLE": ["คำชี้นำใช้ไม่ได้ในสถานการณ์นี้", "Not applicable"],
	"NO_GUIDANCE": ["ไม่มีคำชี้นำ", "No guidance"],
	"SELF_PRESERVATION_PRIORITY": ["ต้องป้องกันตนเองก่อน", "Self preservation first"],
	"URGENT_HELP_PRIORITY": ["ต้องช่วย Player ที่บาดเจ็บหนักก่อน", "Urgent Player help first"],
	"RESOURCE_UNAVAILABLE": ["ใช้ HELP ไปแล้ว", "HELP already used"],
	"HELP_UNAVAILABLE_BASELINE_PRIORITY": ["HELP หมด จึงโจมตีตามกฎเดิม", "HELP exhausted; baseline attack"],
	"BASELINE_ATTACK": ["เดิมก็เลือกโจมตี", "Baseline already attacks"],
	"PLAYER_ABOVE_HELP_THRESHOLD": ["ยังไม่เข้าเงื่อนไขช่วยเหลือ (HP มากกว่า 30%)", "Player above 30% HELP threshold"],
	"NO_VALID_THREAT": ["ไม่มีการโจมตีตนเองที่ใช้ได้", "No valid self threat"],
	"PROFILE_PREFERS_BASELINE": ["เลือกแนวทางของตนเอง", "Profile prefers baseline"],
	"TARGET_UNAVAILABLE": ["เป้าหมายไม่พร้อม", "Target unavailable"],
	"BASELINE_TARGET": ["เดิมก็เลือกเป้าหมายนี้", "Baseline already selects target"],
	"PROFILE_PERMITTED_COOPERATION": ["แนวคิดของ NPC ยอมรับคำชี้นำนี้", "Profile permits cooperation"],
	"PLAYER_COMMAND": ["Player เลือกเอง", "Player command"],
	"ENEMY_DECLARED_TARGET": ["โจมตีเป้าหมายที่ประกาศไว้", "Declared enemy target"],
	"ATTACK_AVAILABLE_ENEMY": ["โจมตีศัตรูตัวแรกที่พร้อม", "Attack first available enemy"],
	"PLAYER_LOW_HP_HELP": ["Player บาดเจ็บหนัก จึงช่วย", "Player low HP; HELP"],
	"SELF_LOW_HP_THREAT": ["HP ต่ำและถูกเล็ง จึงตั้งรับ", "Low HP and targeted"],
	"SELF_LETHAL_THREAT": ["การโจมตีนี้อาจทำให้ล้ม จึงตั้งรับ", "Lethal declared hit"],
	"HELP_UNAVAILABLE_ATTACK": ["HELP หมด จึงโจมตี", "HELP unavailable; attack"],
	"ACTOR_UNAVAILABLE": ["ผู้กระทำไม่พร้อม ข้าม slot", "Actor unavailable"],
	"NO_LIVING_ENEMY": ["ไม่มีศัตรูที่พร้อมเหลืออยู่", "No living enemy"],
	"PLAYER_DEFEATED": ["Player ไม่พร้อม", "Player defeated"],
	"TERMINAL": ["การต่อสู้จบแล้ว", "Battle terminal"],
	"GUIDANCE_DISCRETIONARY_DEFEND": ["เลือกตั้งรับตามคำชี้นำ", "Guided discretionary defend"],
	"GUIDANCE_FOCUS_TARGET": ["เลือกเป้าหมายตามคำชี้นำ", "Guided focus target"],
	"TARGET_DEAD_BEFORE_RESOLVE": ["เป้าหมายไม่พร้อมตอนเกิดผล", "Target died before impact"],
	"HELP_UNAVAILABLE": ["ช่วยไม่ได้ตอนเกิดผล", "HELP unavailable at impact"],
	"VICTORY": ["ชัยชนะ", "Victory"],
	"DEFEAT": ["พ่ายแพ้", "Defeat"]
}


static func message(key: String, language: String = "th") -> String:
	return MESSAGES[key][1 if language == "en" else 0] if MESSAGES.has(key) else key
